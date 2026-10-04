import { createPaddleWebhookHandler, type PaddleBillingEnv } from "./server/billing/deployment.js";
import { handlePaddleWebhookRequest } from "./server/billing/http-adapter.js";

export interface Env extends PaddleBillingEnv {}

export default {
 async fetch(request:Request,env:Env):Promise<Response>{
  const url=new URL(request.url);
  if(url.pathname!=="/api/webhooks/paddle")return new Response("not found",{status:404});
  const handler=createPaddleWebhookHandler(env);
  return handlePaddleWebhookRequest(request,handler);
 }
};
