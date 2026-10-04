import { handlePaddleWebhook, type WebhookResponse } from "./paddle-webhook-handler.js";
import { PostgrestBillingClient } from "./postgrest-client.js";
import { RpcBackedBillingStore } from "./rpc-backed-store.js";

export type PaddleBillingEnv={
 PADDLE_API_KEY:string;
 PADDLE_WEBHOOK_SECRET:string;
 SUPABASE_URL:string;
 SUPABASE_SERVICE_ROLE_KEY:string;
};

export function createPaddleWebhookHandler(env:PaddleBillingEnv,fetchImpl:typeof fetch=fetch){
 for(const [k,v] of Object.entries(env)){
  if(typeof v!=="string"||!v.trim())throw new Error(`SERVER_CONFIG_MISSING_${k}`);
 }
 const db=new PostgrestBillingClient(env.SUPABASE_URL,env.SUPABASE_SERVICE_ROLE_KEY,fetchImpl);
 const store=new RpcBackedBillingStore(db,db);
 return async(input:{rawBody:string;paddleSignature:string|null}):Promise<WebhookResponse>=>{
  return handlePaddleWebhook({
   rawBody:input.rawBody,
   paddleSignature:input.paddleSignature,
   webhookSecret:env.PADDLE_WEBHOOK_SECRET,
   apiKey:env.PADDLE_API_KEY,
   store,
  });
 };
}
