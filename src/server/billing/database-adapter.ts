// Database adapter boundary for Paddle subscription events.
// The database resolves tenant identity; application code never supplies tenant_id.

import type { TrustedSubscriptionEvent } from "./paddle-webhook";

export interface BillingRpcClient {
  commitResolvedBillingEvent(args: {
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
    return args.rpc.commitResolvedBillingEvent({
      eventId:args.event.eventId,eventType:args.event.eventType,
      occurredAt:args.event.occurredAt,payloadHash:args.payloadHash,
      customerId:args.event.customerId,subscriptionId:args.event.subscriptionId,
      priceId:null,providerStatus:args.event.status,
      entitlementState:"UNKNOWN",planCode:"FREE",limits:{}
    });
  }
  return args.rpc.commitResolvedBillingEvent({
    eventId:args.event.eventId,eventType:args.event.eventType,
    occurredAt:args.event.occurredAt,payloadHash:args.payloadHash,
    customerId:args.event.customerId,subscriptionId:args.event.subscriptionId,
    priceId,providerStatus:args.event.status,
    entitlementState:args.entitlement.state,planCode:args.entitlement.plan,
    limits:args.entitlement.limits
  });
}
