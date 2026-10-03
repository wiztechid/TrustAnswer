import { createHash } from "node:crypto";
import { handlePaddleWebhook } from "../../src/server/billing/paddle-webhook-handler.js";
import type { BillingStore,TrustedSubscriptionEvent } from "../../src/server/billing/paddle-webhook.js";

const event:TrustedSubscriptionEvent={
 eventId:"evt_http",eventType:"subscription.updated",occurredAt:"2026-10-03T00:00:00Z",
 subscriptionId:"sub_http",customerId:"ctm_http",status:"active",priceIds:["pri_http"],
 currentBillingPeriod:{startsAt:"2026-10-03T00:00:00Z",endsAt:"2026-11-03T00:00:00Z"},
 scheduledChange:null,checkoutBindingHandle:null
};
class Store implements BillingStore{
 calls=0; hash="";
 async hasCompletedEvent(){this.calls++;return false;}
 async resolveTenant(){this.calls++;return "tenant";}
 async bindAndCommitInitialSubscription(){this.calls++;return "APPLIED" as const;}
 async getLastAcceptedEvent(){this.calls++;return null;}
 async markReconcileRequired(){this.calls++;}
 async commitVerifiedEvent(a:any){this.calls++;this.hash=a.payloadHash;return "APPLIED" as const;}
}
async function run(){
 // HTTP-I01 missing signature: zero verifier/store side effect.
 let verified=0; const s1=new Store();
 let r=await handlePaddleWebhook({rawBody:'{"x":1}',paddleSignature:null,webhookSecret:"s",apiKey:"k",store:s1,verify:async()=>{verified++;return event;}});
 if(r.status!==400||verified!==0||s1.calls!==0) throw new Error("HTTP-I01");

 // HTTP-I02 failed verification: zero store side effect.
 const s2=new Store();
 r=await handlePaddleWebhook({rawBody:'{"x":1}',paddleSignature:"bad",webhookSecret:"s",apiKey:"k",store:s2,verify:async()=>{throw new Error("bad signature");}});
 if(r.status!==400||s2.calls!==0) throw new Error("HTTP-I02");

 // HTTP-I03 raw body passed byte-for-byte and its exact SHA-256 becomes commit hash.
 const raw=' { "exact" : "body\\n" } '; const s3=new Store(); let seen="";
 r=await handlePaddleWebhook({rawBody:raw,paddleSignature:"sig",webhookSecret:"s",apiKey:"k",store:s3,verify:async a=>{seen=a.rawBody;return event;}});
 const expected=createHash("sha256").update(raw,"utf8").digest("hex");
 if(r.status!==200||seen!==raw||s3.hash!==expected) throw new Error("HTTP-I03");

 // HTTP-I04 unsupported verified event: acknowledged ignored, no store work.
 const s4=new Store();
 r=await handlePaddleWebhook({rawBody:"raw",paddleSignature:"sig",webhookSecret:"s",apiKey:"k",store:s4,verify:async()=>null});
 if(r.status!==200||r.body!=="ignored"||s4.calls!==0) throw new Error("HTTP-I04");

 // HTTP-I05 storage/processor failure is retryable 500, never false-acknowledged.
 const s5=new Store(); s5.commitVerifiedEvent=async()=>{throw new Error("db down");};
 r=await handlePaddleWebhook({rawBody:"raw",paddleSignature:"sig",webhookSecret:"s",apiKey:"k",store:s5,verify:async()=>event});
 if(r.status!==500||r.body!=="retry") throw new Error("HTTP-I05");

 // HTTP-I06 reconcile is explicit 202 rather than successful state transition.
 const s6=new Store(); s6.resolveTenant=async()=>null;
 r=await handlePaddleWebhook({rawBody:"raw",paddleSignature:"sig",webhookSecret:"s",apiKey:"k",store:s6,verify:async()=>event});
 if(r.status!==202||r.body!=="reconcile") throw new Error("HTTP-I06");
}
run();
