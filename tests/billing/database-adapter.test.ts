import { bindAndCommitInitialTrustedEvent, type BillingRpcClient } from "../../src/server/billing/database-adapter.js";
import type { TrustedSubscriptionEvent } from "../../src/server/billing/paddle-webhook.js";

async function run(){
 let captured:any=null;
 const rpc:BillingRpcClient={
  async bindAndCommitProviderSubscription(a){captured=a;return "APPLIED";},
  async commitProviderBillingEvent(){return "APPLIED";}
 };
 const event:TrustedSubscriptionEvent={
  eventId:"evt_created",eventType:"subscription.created",occurredAt:"2026-10-03T00:00:00Z",
  subscriptionId:"sub_1",customerId:"ctm_1",status:"active",priceIds:["pri_1"],
  currentBillingPeriod:{startsAt:"2026-10-03T00:00:00Z",endsAt:"2026-11-03T00:00:00Z"},
  scheduledChange:null,checkoutBindingHandle:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
 };
 const r=await bindAndCommitInitialTrustedEvent({handle:event.checkoutBindingHandle!,event,payloadHash:"payload",rpc});
 if(r!=="APPLIED"||!captured) throw new Error("ADP-I01");
 if(captured.handle!==event.checkoutBindingHandle||captured.customerId!=="ctm_1"||captured.subscriptionId!=="sub_1"||captured.priceId!=="pri_1") throw new Error("ADP-I02");
 if("tenantId" in captured||"planCode" in captured||"entitlement" in captured||"limits" in captured) throw new Error("ADP-I03");
 let rejected=false;
 try{await bindAndCommitInitialTrustedEvent({handle:"x",event:{...event,eventType:"subscription.updated"},payloadHash:"p",rpc});}catch{rejected=true;}
 if(!rejected) throw new Error("ADP-I04");
}
run();
