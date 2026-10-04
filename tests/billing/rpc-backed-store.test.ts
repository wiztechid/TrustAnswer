import { RpcBackedBillingStore } from "../../src/server/billing/rpc-backed-store.js";
import type { BillingRpcClient } from "../../src/server/billing/database-adapter.js";
import type { TrustedSubscriptionEvent } from "../../src/server/billing/paddle-webhook.js";

const event:TrustedSubscriptionEvent={
 eventId:"evt",eventType:"subscription.updated",occurredAt:"2026-10-04T00:00:00Z",
 subscriptionId:"sub",customerId:"ctm",status:"active",priceIds:["pri"],
 currentBillingPeriod:{startsAt:"2026-10-01T00:00:00Z",endsAt:"2026-11-01T00:00:00Z"},
 scheduledChange:null,checkoutBindingHandle:null
};
async function run(){
 let resolved:any=null,normal:any=null,initial:any=null;
 const identity={async resolveBillingTenant(a:any){resolved=a;return "tenant";}};
 const rpc:BillingRpcClient={
  async commitProviderBillingEvent(a){normal=a;return "STALE";},
  async bindAndCommitProviderSubscription(a){initial=a;return "APPLIED";}
 };
 const s=new RpcBackedBillingStore(identity,rpc);
 if(await s.resolveTenant("ctm","sub")!=="tenant"||resolved.provider!=="PADDLE")throw new Error("STORE-I01");
 if(await s.commitVerifiedEvent({event,payloadHash:"hash"})!=="STALE")throw new Error("STORE-I02");
 if(!normal||normal.customerId!=="ctm"||normal.subscriptionId!=="sub"||normal.priceId!=="pri"||"tenantId" in normal||"planCode" in normal)throw new Error("STORE-I03");
 const created={...event,eventType:"subscription.created",checkoutBindingHandle:"a".repeat(64)};
 if(await s.bindAndCommitInitialSubscription({handle:created.checkoutBindingHandle!,event:created,payloadHash:"hash2"})!=="APPLIED")throw new Error("STORE-I04");
 if(!initial||initial.handle!==created.checkoutBindingHandle||initial.eventType!=="subscription.created"||"tenantId" in initial||"planCode" in initial)throw new Error("STORE-I05");
}
run();
