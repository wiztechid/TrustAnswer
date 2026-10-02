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
  scheduledChange: null | { action: string; effectiveAt: string };
};

export interface BillingStore {
  hasEvent(eventId: string): Promise<boolean>;
  recordVerifiedEvent(input: TrustedSubscriptionEvent & { payloadHash: string }): Promise<void>;
  resolveTenant(customerId: string, subscriptionId: string): Promise<string | null>;
  getLastAcceptedEvent(tenantId: string): Promise<{ occurredAt: string; eventId: string } | null>;
  applySubscriptionEvent(tenantId: string, event: TrustedSubscriptionEvent): Promise<"APPLIED"|"STALE"|"RECONCILE">;
  markReconcileRequired(tenantId: string, reason: string): Promise<void>;
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
    scheduledChange: data.scheduledChange
      ? {
          action: String(data.scheduledChange.action),
          effectiveAt: String(data.scheduledChange.effectiveAt),
        }
      : null,
  };
}

export async function processTrustedSubscriptionEvent(args: {
  event: TrustedSubscriptionEvent;
  payloadHash: string;
  store: BillingStore;
}): Promise<"IGNORED_DUPLICATE"|"APPLIED"|"STALE"|"RECONCILE"> {
  const { event, store } = args;

  if (await store.hasEvent(event.eventId)) return "IGNORED_DUPLICATE";

  // Persist verified event identity before side effects; DB implementation must make
  // event insertion + state transition transactional/idempotent.
  await store.recordVerifiedEvent({ ...event, payloadHash: args.payloadHash });

  const tenantId = await store.resolveTenant(event.customerId, event.subscriptionId);
  if (!tenantId) return "RECONCILE";

  const previous = await store.getLastAcceptedEvent(tenantId);
  if (previous) {
    const incoming = Date.parse(event.occurredAt);
    const accepted = Date.parse(previous.occurredAt);
    if (!Number.isFinite(incoming) || !Number.isFinite(accepted)) {
      await store.markReconcileRequired(tenantId, "INVALID_EVENT_TIME");
      return "RECONCILE";
    }
    if (incoming < accepted) return "STALE";
    if (incoming === accepted && event.eventId !== previous.eventId) {
      await store.markReconcileRequired(tenantId, "AMBIGUOUS_SAME_TIME_EVENTS");
      return "RECONCILE";
    }
  }

  return store.applySubscriptionEvent(tenantId, event);
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
