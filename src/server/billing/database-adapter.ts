// Database adapter boundary for Paddle subscription events.
// The database resolves tenant identity; application code never supplies tenant_id.

import type { TrustedSubscriptionEvent } from "./paddle-webhook.js";

export interface BillingRpcClient {
  commitResolvedBillingEventV2(args: {
    eventId:string;
    eventType:string;
    occurredAt:string;
    payloadHash:string;
    customerId:string;
    subscriptionId:string;
    priceId:string|null;
    providerStatus:string;
    entitlementState:"ACTIVE"|"BLOCKED"|"UNKNOWN";
    planCode:"FREE"|"SOLO"|"PRO";
    limits:Record<string,unknown>;
    periodStart:string|null;
    periodEnd:string|null;
  }): Promise<"APPLIED"|"STALE"|"RECONCILE"|"IGNORED_DUPLICATE">;
}

export async function commitTrustedEvent(args:{
  event:TrustedSubscriptionEvent;
  payloadHash:string;
  rpc:BillingRpcClient;
  entitlement:{state:"ACTIVE"|"BLOCKED"|"UNKNOWN";plan:"FREE"|"SOLO"|"PRO";limits:Record<string,unknown>};
}){
  const priceId=args.event.priceIds.length===1 ? args.event.priceIds[0] : null;
  if(args.event.priceIds.length!==1) {
    return args.rpc.commitResolvedBillingEventV2({
      eventId:args.event.eventId,eventType:args.event.eventType,
      occurredAt:args.event.occurredAt,payloadHash:args.payloadHash,
      customerId:args.event.customerId,subscriptionId:args.event.subscriptionId,
      priceId:null,providerStatus:args.event.status,
      entitlementState:"UNKNOWN",planCode:"FREE",limits:{},
      periodStart:args.event.currentBillingPeriod?.startsAt ?? null,
      periodEnd:args.event.currentBillingPeriod?.endsAt ?? null
    });
  }
  return args.rpc.commitResolvedBillingEventV2({
    eventId:args.event.eventId,eventType:args.event.eventType,
    occurredAt:args.event.occurredAt,payloadHash:args.payloadHash,
    customerId:args.event.customerId,subscriptionId:args.event.subscriptionId,
    priceId,providerStatus:args.event.status,
    entitlementState:args.entitlement.state,planCode:args.entitlement.plan,
    limits:args.entitlement.limits,
    periodStart:args.event.currentBillingPeriod?.startsAt ?? null,
    periodEnd:args.event.currentBillingPeriod?.endsAt ?? null
  });
}
