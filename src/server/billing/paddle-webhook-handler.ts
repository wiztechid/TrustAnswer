import { createHash } from "node:crypto";
import {
  processTrustedSubscriptionEvent,
  verifyAndNormalizePaddleWebhook,
  type BillingStore,
  type TrustedSubscriptionEvent,
} from "./paddle-webhook.js";

export type WebhookResponse={status:number;body:string};
type Verify=(a:{rawBody:string;paddleSignature:string;webhookSecret:string;apiKey:string})=>Promise<TrustedSubscriptionEvent|null>;

export async function handlePaddleWebhook(args:{
 rawBody:string;
 paddleSignature:string|null;
 webhookSecret:string;
 apiKey:string;
 store:BillingStore;
 verify?:Verify;
}):Promise<WebhookResponse>{
 if(!args.rawBody||!args.paddleSignature) return {status:400,body:"invalid webhook"};
 const verify=args.verify ?? verifyAndNormalizePaddleWebhook;
 let event:TrustedSubscriptionEvent|null;
 try{
   event=await verify({
     rawBody:args.rawBody,
     paddleSignature:args.paddleSignature,
     webhookSecret:args.webhookSecret,
     apiKey:args.apiKey,
   });
 }catch{
   return {status:400,body:"invalid webhook"};
 }
 if(!event) return {status:200,body:"ignored"};

 // Hash exactly the same raw body that passed verification. Caller cannot supply this hash.
 const payloadHash=createHash("sha256").update(args.rawBody,"utf8").digest("hex");
 try{
   const result=await processTrustedSubscriptionEvent({event,payloadHash,store:args.store});
   if(result==="RECONCILE") return {status:500,body:"retry"};
   return {status:200,body:result.toLowerCase()};
 }catch{
   // Retryable server/storage failure: never acknowledge as successfully processed.
   return {status:500,body:"retry"};
 }
}
