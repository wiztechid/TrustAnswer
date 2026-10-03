import type { BillingRpcClient } from "./database-adapter.js";
import type { BillingIdentityResolver } from "./rpc-backed-store.js";

type FetchLike=(input:string,init?:RequestInit)=>Promise<{ok:boolean;status:number;text():Promise<string>}>;
type BillingResult="APPLIED"|"STALE"|"RECONCILE"|"IGNORED_DUPLICATE";
const allowed=new Set<BillingResult>(["APPLIED","STALE","RECONCILE","IGNORED_DUPLICATE"]);

export class PostgrestBillingClient implements BillingRpcClient,BillingIdentityResolver{
 constructor(
  private readonly baseUrl:string,
  private readonly serviceRoleKey:string,
  private readonly fetchImpl:FetchLike=fetch,
 ){
  if(!baseUrl||!serviceRoleKey)throw new Error("BILLING_TRANSPORT_CONFIG_MISSING");
 }
 private async rpc(name:string,body:Record<string,unknown>):Promise<unknown>{
  const r=await this.fetchImpl(this.baseUrl.replace(/\/$/,"")+"/rest/v1/rpc/"+name,{
   method:"POST",
   headers:{
    "content-type":"application/json",
    "apikey":this.serviceRoleKey,
    "authorization":`Bearer ${this.serviceRoleKey}`,
   },
   body:JSON.stringify(body),
  });
  const text=await r.text();
  if(!r.ok)throw new Error(`BILLING_RPC_FAILED_${r.status}`);
  try{return JSON.parse(text);}catch{throw new Error("BILLING_RPC_RESPONSE_INVALID");}
 }
 private result(v:unknown):BillingResult{
  if(typeof v!=="string"||!allowed.has(v as BillingResult))throw new Error("BILLING_RPC_RESULT_INVALID");
  return v as BillingResult;
 }
 async resolveBillingTenant(a:{provider:"PADDLE";customerId:string;subscriptionId:string}){
  const v=await this.rpc("ta_resolve_billing_tenant",{p_provider:a.provider,p_customer_id:a.customerId,p_subscription_id:a.subscriptionId});
  if(v===null)return null;
  if(typeof v!=="string"||!v)throw new Error("BILLING_IDENTITY_RESPONSE_INVALID");
  return v;
 }
 async commitProviderBillingEvent(a:Parameters<BillingRpcClient["commitProviderBillingEvent"]>[0]){
  return this.result(await this.rpc("ta_commit_provider_billing_event",{
   p_event_id:a.eventId,p_event_type:a.eventType,p_occurred_at:a.occurredAt,p_payload_hash:a.payloadHash,
   p_customer_id:a.customerId,p_subscription_id:a.subscriptionId,p_price_id:a.priceId,
   p_provider_status:a.providerStatus,p_period_start:a.periodStart,p_period_end:a.periodEnd,
  }));
 }
 async bindAndCommitProviderSubscription(a:Parameters<BillingRpcClient["bindAndCommitProviderSubscription"]>[0]){
  return this.result(await this.rpc("ta_bind_and_commit_provider_subscription",{
   p_token_hash:a.handle,p_event_id:a.eventId,p_event_type:a.eventType,p_occurred_at:a.occurredAt,
   p_payload_hash:a.payloadHash,p_customer_id:a.customerId,p_subscription_id:a.subscriptionId,
   p_price_id:a.priceId,p_provider_status:a.providerStatus,p_period_start:a.periodStart,p_period_end:a.periodEnd,
  }));
 }
}
