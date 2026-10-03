import { PostgrestBillingClient } from "../../src/server/billing/postgrest-client.js";
async function run(){
 const calls:any[]=[];
 const fetcher=async(input:string,init?:RequestInit)=>{calls.push({input,init});return {ok:true,status:200,async text(){return '"APPLIED"';}}};
 const c=new PostgrestBillingClient("https://db.example/","secret",fetcher);
 const base={eventId:"e",eventType:"subscription.updated",occurredAt:"2026-10-04T00:00:00Z",payloadHash:"h",customerId:"c",subscriptionId:"s",priceId:"p",providerStatus:"active",periodStart:"2026-10-01T00:00:00Z",periodEnd:"2026-11-01T00:00:00Z"};
 if(await c.commitProviderBillingEvent(base)!=="APPLIED")throw new Error("PG-I01");
 if(!calls[0].input.endsWith("/rest/v1/rpc/ta_commit_provider_billing_event"))throw new Error("PG-I02");
 const b=JSON.parse(calls[0].init.body);if("tenantId" in b||"planCode" in b||b.p_customer_id!=="c")throw new Error("PG-I03");
 if(calls[0].init.headers.authorization!=="Bearer secret"||calls[0].init.headers.apikey!=="secret")throw new Error("PG-I04");
 await c.bindAndCommitProviderSubscription({...base,handle:"a".repeat(64),eventType:"subscription.created"});
 const ib=JSON.parse(calls[1].init.body);if(ib.p_token_hash!=="a".repeat(64)||"tenantId" in ib||"planCode" in ib)throw new Error("PG-I05");
 const identityCalls:any[]=[];
 const idFetch=async(input:string,init?:RequestInit)=>{identityCalls.push({input,init});return {ok:true,status:200,async text(){return '"tenant-uuid"';}}};
 const idc=new PostgrestBillingClient("https://db.example","secret",idFetch);
 if(await idc.resolveBillingTenant({provider:"PADDLE",customerId:"c",subscriptionId:"s"})!=="tenant-uuid")throw new Error("PG-I06");
 const bad=new PostgrestBillingClient("https://db.example","secret",async()=>({ok:true,status:200,async text(){return '"FREE"';}}));
 let failed=false;try{await bad.commitProviderBillingEvent(base);}catch{failed=true;}if(!failed)throw new Error("PG-I07");
}
run();
