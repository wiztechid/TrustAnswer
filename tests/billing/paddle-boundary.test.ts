import {
  deriveEntitlement,
  processTrustedSubscriptionEvent,
  type BillingStore,
  type TrustedSubscriptionEvent,
} from "../../src/server/billing/paddle-webhook";

function ev(overrides: Partial<TrustedSubscriptionEvent> = {}): TrustedSubscriptionEvent {
  return {
    eventId: "evt_new",
    eventType: "subscription.updated",
    occurredAt: "2026-10-02T10:00:00Z",
    subscriptionId: "sub_test",
    customerId: "ctm_test",
    status: "active",
    priceIds: ["pri_pro"],
    scheduledChange: null,
    ...overrides,
  };
}

class FakeStore implements BillingStore {
  seen = new Set<string>();
  previous: { occurredAt: string; eventId: string } | null = null;
  tenant: string | null = "tenant-a";
  reconcile = false;
  applied = 0;
  async hasEvent(id:string){ return this.seen.has(id); }
  async recordVerifiedEvent(e:any){ this.seen.add(e.eventId); }
  async resolveTenant(){ return this.tenant; }
  async getLastAcceptedEvent(){ return this.previous; }
  async applySubscriptionEvent(){ this.applied++; return "APPLIED" as const; }
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
  if(await processTrustedSubscriptionEvent({event:ev(),payloadHash:"h",store:s4})!=="RECONCILE") throw new Error("B04");

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
