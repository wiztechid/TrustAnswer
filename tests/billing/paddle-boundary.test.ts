import {
  deriveEntitlement, processTrustedSubscriptionEvent,
  type BillingStore, type TrustedSubscriptionEvent,
} from "../../src/server/billing/paddle-webhook.js";

function ev(o:Partial<TrustedSubscriptionEvent>={}):TrustedSubscriptionEvent{return {
 eventId:"evt",eventType:"subscription.updated",occurredAt:"2026-10-02T10:00:00Z",
 subscriptionId:"sub",customerId:"ctm",status:"active",priceIds:["pri"],
 currentBillingPeriod:{startsAt:"2026-10-01T00:00:00Z",endsAt:"2026-11-01T00:00:00Z"},
 scheduledChange:null,checkoutBindingHandle:null,...o};}

class Store implements BillingStore{
 tenant:string|null="tenant"; committed=0; initial=0;
 result:"APPLIED"|"STALE"|"RECONCILE"|"IGNORED_DUPLICATE"="APPLIED";
 async resolveTenant(){return this.tenant;}
 async bindAndCommitInitialSubscription(){this.initial++;return this.result;}
 async commitVerifiedEvent(){this.committed++;return this.result;}
}
async function run(){
 // B01 existing identity is always delegated to DB authority, including duplicate.
 const s1=new Store();s1.result="IGNORED_DUPLICATE";
 if(await processTrustedSubscriptionEvent({event:ev(),payloadHash:"h",store:s1})!=="IGNORED_DUPLICATE"||s1.committed!==1)throw new Error("B01");

 // B02 stale decision is returned from DB, never precomputed in TypeScript.
 const s2=new Store();s2.result="STALE";
 if(await processTrustedSubscriptionEvent({event:ev({occurredAt:"2000-01-01T00:00:00Z"}),payloadHash:"h",store:s2})!=="STALE"||s2.committed!==1)throw new Error("B02");

 // B03 same-time/reconcile decision is likewise DB-owned.
 const s3=new Store();s3.result="RECONCILE";
 if(await processTrustedSubscriptionEvent({event:ev(),payloadHash:"h",store:s3})!=="RECONCILE"||s3.committed!==1)throw new Error("B03");

 // B04 unknown identity cannot mutate through normal event path.
 const s4=new Store();s4.tenant=null;
 if(await processTrustedSubscriptionEvent({event:ev(),payloadHash:"h",store:s4})!=="RECONCILE"||s4.committed||s4.initial)throw new Error("B04");

 // B05 only first subscription.created + trusted handle may enter atomic bootstrap path.
 const s5=new Store();s5.tenant=null;
 if(await processTrustedSubscriptionEvent({event:ev({eventType:"subscription.created",checkoutBindingHandle:"a".repeat(64)}),payloadHash:"h",store:s5})!=="APPLIED"||s5.initial!==1||s5.committed)throw new Error("B05");

 const s6=new Store();s6.tenant=null;
 if(await processTrustedSubscriptionEvent({event:ev({eventType:"subscription.updated",checkoutBindingHandle:"a".repeat(64)}),payloadHash:"h",store:s6})!=="RECONCILE"||s6.initial)throw new Error("B06");

 for(const status of ["past_due","paused","canceled"]){
  const d=deriveEntitlement({status,mappedPlan:"PRO",mappingActive:true,reconciliationRequired:false});
  if(d.state!=="BLOCKED"||d.plan!=="FREE")throw new Error("B07-"+status);
 }
 const u=deriveEntitlement({status:"active",mappedPlan:null,mappingActive:false,reconciliationRequired:false});
 if(u.state!=="UNKNOWN"||u.plan!=="FREE")throw new Error("B08");
}
run();
