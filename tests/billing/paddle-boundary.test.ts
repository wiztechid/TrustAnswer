import {
  deriveEntitlement,
  processTrustedSubscriptionEvent,
  type BillingStore,
  type TrustedSubscriptionEvent,
} from "../../src/server/billing/paddle-webhook.js";

function ev(overrides: Partial<TrustedSubscriptionEvent> = {}): TrustedSubscriptionEvent {
  return {
    eventId: "evt_new",
    eventType: "subscription.updated",
    occurredAt: "2026-10-02T10:00:00Z",
    subscriptionId: "sub_test",
    customerId: "ctm_test",
    status: "active",
    priceIds: ["pri_pro"],
    currentBillingPeriod: {startsAt:"2026-10-01T00:00:00Z",endsAt:"2026-11-01T00:00:00Z"},
    scheduledChange: null,
    checkoutBindingHandle: null,
    ...overrides,
  };
}

class FakeStore implements BillingStore {
  seen = new Set<string>();
  previous: { occurredAt: string; eventId: string } | null = null;
  tenant: string | null = "tenant-a";
  reconcile = false;
  applied = 0;
  consumed = 0;
  async hasCompletedEvent(id:string){ return this.seen.has(id); }
  async resolveTenant(){ return this.tenant; }
  async consumeCheckoutBinding(){ this.consumed++; this.tenant="tenant-bound"; return "tenant-bound"; }
  async getLastAcceptedEvent(){ return this.previous; }
  async commitVerifiedEvent(){ this.applied++; return "APPLIED" as const; }
  async markReconcileRequired(){ this.reconcile=true; }
}

async function run(){
  const s1=new FakeStore();
  s1.seen.add("evt_new");
  if(await processTrustedSubscriptionEvent({event:ev(),payloadHash:"h",store:s1})!=="IGNORED_DUPLICATE") throw new Error("B01");

  const s2=new FakeStore();
  s2.previous={occurredAt:"2026-10-02T11:00:00Z",eventId:"evt_later"};
  if(await processTrustedSubscriptionEvent({event:ev(),payloadHash:"h",store:s2})!=="STALE" || s2.applied!==0) throw new Error("B02");

  const s3=new FakeStore();
  s3.previous={occurredAt:"2026-10-02T10:00:00Z",eventId:"evt_other"};
  if(await processTrustedSubscriptionEvent({event:ev(),payloadHash:"h",store:s3})!=="RECONCILE" || !s3.reconcile) throw new Error("B03");

  const s4=new FakeStore(); s4.tenant=null;
  if(await processTrustedSubscriptionEvent({event:ev(),payloadHash:"h",store:s4})!=="RECONCILE" || s4.consumed!==0) throw new Error("B04");

  const s4b=new FakeStore(); s4b.tenant=null;
  if(await processTrustedSubscriptionEvent({event:ev({eventType:"subscription.created",checkoutBindingHandle:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}),payloadHash:"h",store:s4b})!=="APPLIED" || s4b.consumed!==1 || s4b.applied!==1) throw new Error("B04b");

  const s4c=new FakeStore(); s4c.tenant=null;
  if(await processTrustedSubscriptionEvent({event:ev({eventType:"subscription.updated",checkoutBindingHandle:"opaque-token"}),payloadHash:"h",store:s4c})!=="RECONCILE" || s4c.consumed!==0) throw new Error("B04c");

  const s4d=new FakeStore(); s4d.tenant=null; s4d.seen.add("evt_new");
  if(await processTrustedSubscriptionEvent({event:ev({eventType:"subscription.created",checkoutBindingHandle:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}),payloadHash:"h",store:s4d})!=="IGNORED_DUPLICATE" || s4d.consumed!==0) throw new Error("B04d");

  const s4e=new FakeStore(); s4e.tenant="tenant-bound";
  if(await processTrustedSubscriptionEvent({event:ev({eventId:"evt_redelivery",eventType:"subscription.created",checkoutBindingHandle:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}),payloadHash:"h2",store:s4e})!=="APPLIED" || s4e.consumed!==0 || s4e.applied!==1) throw new Error("B04e");

  for(const status of ["past_due","paused","canceled"]){
    const d=deriveEntitlement({status,mappedPlan:"PRO",mappingActive:true,reconciliationRequired:false});
    if(d.state!=="BLOCKED" || d.plan!=="FREE") throw new Error("B05-"+status);
  }

  const unknown=deriveEntitlement({status:"active",mappedPlan:null,mappingActive:false,reconciliationRequired:false});
  if(unknown.state!=="UNKNOWN" || unknown.plan!=="FREE") throw new Error("B06");

  const uncertain=deriveEntitlement({status:"active",mappedPlan:"PRO",mappingActive:true,reconciliationRequired:true});
  if(uncertain.state!=="UNKNOWN" || uncertain.plan!=="FREE") throw new Error("B07");
}
run();
