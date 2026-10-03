// TrustAnswer Paddle webhook boundary v0.3
// Public-safe transport contract. Requires @paddle/paddle-node-sdk and a server-only DB adapter.

import { Paddle } from "@paddle/paddle-node-sdk";

export type TrustedSubscriptionEvent = {
  eventId: string;
  eventType: string;
  occurredAt: string;
  subscriptionId: string;
  customerId: string;
  status: "active" | "trialing" | "past_due" | "paused" | "canceled";
  priceIds: string[];
  currentBillingPeriod: null | { startsAt: string; endsAt: string };
  scheduledChange: null | { action: string; effectiveAt: string };
  checkoutBindingHandle: string | null;
};

export interface BillingStore {
  resolveTenant(customerId: string, subscriptionId: string): Promise<string | null>;
  bindAndCommitInitialSubscription(args: { handle:string; event:TrustedSubscriptionEvent; payloadHash:string }): Promise<"APPLIED"|"STALE"|"RECONCILE"|"IGNORED_DUPLICATE">;
  commitVerifiedEvent(args: {
    event: TrustedSubscriptionEvent;
    payloadHash: string;
  }): Promise<"APPLIED"|"STALE"|"RECONCILE"|"IGNORED_DUPLICATE">;
}

const allowedStatuses = new Set(["active","trialing","past_due","paused","canceled"]);

export async function verifyAndNormalizePaddleWebhook(args: {
  rawBody: string;
  paddleSignature: string;
  webhookSecret: string;
  apiKey: string;
}): Promise<TrustedSubscriptionEvent | null> {
  if (!args.rawBody || !args.paddleSignature || !args.webhookSecret || !args.apiKey) {
    throw new Error("WEBHOOK_INPUT_MISSING");
  }

  const paddle = new Paddle(args.apiKey);
  // Official SDK verification consumes the unmodified raw body.
  const event = await paddle.webhooks.unmarshal(
    args.rawBody,
    args.webhookSecret,
    args.paddleSignature,
  );

  if (!event.eventType.startsWith("subscription.")) return null;

  const data = event.data as any;
  if (!data?.id || !data?.customerId || !allowedStatuses.has(data.status)) {
    throw new Error("UNSUPPORTED_SUBSCRIPTION_EVENT");
  }

  const priceIds = Array.isArray(data.items)
    ? data.items.map((item: any) => item?.price?.id).filter(Boolean)
    : [];

  return {
    eventId: event.eventId,
    eventType: event.eventType,
    occurredAt: event.occurredAt,
    subscriptionId: data.id,
    customerId: data.customerId,
    status: data.status,
    priceIds,
    currentBillingPeriod: data.currentBillingPeriod
      ? {
          startsAt: String(data.currentBillingPeriod.startsAt),
          endsAt: String(data.currentBillingPeriod.endsAt),
        }
      : null,
    scheduledChange: data.scheduledChange
      ? {
          action: String(data.scheduledChange.action),
          effectiveAt: String(data.scheduledChange.effectiveAt),
        }
      : null,
    checkoutBindingHandle:
      typeof data.customData?.trustanswer_binding_handle === "string" &&
      /^[a-f0-9]{64}$/i.test(data.customData.trustanswer_binding_handle)
        ? data.customData.trustanswer_binding_handle.toLowerCase()
        : null,
  };
}

export async function processTrustedSubscriptionEvent(args: {
  event: TrustedSubscriptionEvent;
  payloadHash: string;
  store: BillingStore;
}): Promise<"IGNORED_DUPLICATE"|"APPLIED"|"STALE"|"RECONCILE"> {
  const { event, store } = args;

  // Identity lookup is routing only. Replay/order/transition authority remains in
  // the database transaction; TypeScript performs no authoritative preflight.
  const tenantId = await store.resolveTenant(event.customerId, event.subscriptionId);
  if (!tenantId) {
    if (event.eventType !== "subscription.created" || !event.checkoutBindingHandle) return "RECONCILE";
    return store.bindAndCommitInitialSubscription({
      handle: event.checkoutBindingHandle,
      event,
      payloadHash: args.payloadHash,
    });
  }

  return store.commitVerifiedEvent({ event, payloadHash: args.payloadHash });
}

export function deriveEntitlement(input: {
  status: string;
  mappedPlan: "FREE"|"SOLO"|"PRO"|null;
  mappingActive: boolean;
  reconciliationRequired: boolean;
}): { state: "ACTIVE"|"BLOCKED"|"UNKNOWN"; plan: "FREE"|"SOLO"|"PRO" } {
  if (input.reconciliationRequired) return { state: "UNKNOWN", plan: "FREE" };
  if (!input.mappedPlan || !input.mappingActive) return { state: "UNKNOWN", plan: "FREE" };

  if (input.status === "active" || input.status === "trialing") {
    return { state: "ACTIVE", plan: input.mappedPlan };
  }

  if (input.status === "past_due" || input.status === "paused" || input.status === "canceled") {
    return { state: "BLOCKED", plan: "FREE" };
  }

  return { state: "UNKNOWN", plan: "FREE" };
}
