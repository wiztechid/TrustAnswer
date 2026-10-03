// Database adapter boundary for verified Paddle subscription events.
// Tenant identity and entitlements are resolved by the database.

import type { TrustedSubscriptionEvent } from "./paddle-webhook.js";

export interface BillingRpcClient {
  bindAndCommitProviderSubscription(args: {
    handle:string; eventId:string; eventType:string; occurredAt:string; payloadHash:string;
    customerId:string; subscriptionId:string; priceId:string|null; providerStatus:string;
    periodStart:string|null; periodEnd:string|null;
  }): Promise<"APPLIED"|"STALE"|"RECONCILE">;
  commitProviderBillingEvent(args: {
    eventId:string;
    eventType:string;
    occurredAt:string;
    payloadHash:string;
    customerId:string;
    subscriptionId:string;
    priceId:string|null;
    providerStatus:string;
    periodStart:string|null;
    periodEnd:string|null;
  }): Promise<"APPLIED"|"STALE"|"RECONCILE"|"IGNORED_DUPLICATE">;
}

export async function commitTrustedEvent(args:{
  event:TrustedSubscriptionEvent;
  payloadHash:string;
  rpc:BillingRpcClient;
}){
  const priceId=args.event.priceIds.length===1 ? args.event.priceIds[0] : null;
  return args.rpc.commitProviderBillingEvent({
    eventId:args.event.eventId,
    eventType:args.event.eventType,
    occurredAt:args.event.occurredAt,
    payloadHash:args.payloadHash,
    customerId:args.event.customerId,
    subscriptionId:args.event.subscriptionId,
    priceId,
    providerStatus:args.event.status,
    periodStart:args.event.currentBillingPeriod?.startsAt ?? null,
    periodEnd:args.event.currentBillingPeriod?.endsAt ?? null
  });
}


export async function bindAndCommitInitialTrustedEvent(args:{
  handle:string;
  event:TrustedSubscriptionEvent;
  payloadHash:string;
  rpc:BillingRpcClient;
}){
  if(args.event.eventType!=="subscription.created") throw new Error("INITIAL_BIND_EVENT_TYPE_INVALID");
  const priceId=args.event.priceIds.length===1 ? args.event.priceIds[0] : null;
  return args.rpc.bindAndCommitProviderSubscription({
    handle:args.handle,
    eventId:args.event.eventId,
    eventType:args.event.eventType,
    occurredAt:args.event.occurredAt,
    payloadHash:args.payloadHash,
    customerId:args.event.customerId,
    subscriptionId:args.event.subscriptionId,
    priceId,
    providerStatus:args.event.status,
    periodStart:args.event.currentBillingPeriod?.startsAt ?? null,
    periodEnd:args.event.currentBillingPeriod?.endsAt ?? null,
  });
}
