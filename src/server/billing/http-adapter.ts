import type { WebhookResponse } from "./paddle-webhook-handler.js";

export type PaddleWebhookAppHandler=(input:{
 rawBody:string;
 paddleSignature:string|null;
})=>Promise<WebhookResponse>;

/**
 * Web-standard HTTP adapter for Cloudflare Workers/Pages and compatible runtimes.
 * Reads the request body exactly once and never parses JSON before signature verification.
 */
export async function handlePaddleWebhookRequest(
 request:Request,
 handler:PaddleWebhookAppHandler,
):Promise<Response>{
 if(request.method!=="POST")return new Response("method not allowed",{status:405,headers:{allow:"POST"}});
 const signature=request.headers.get("Paddle-Signature");
 if(!signature)return new Response("invalid webhook",{status:400});
 let rawBody:string;
 try{rawBody=await request.text();}catch{return new Response("invalid webhook",{status:400});}
 if(!rawBody)return new Response("invalid webhook",{status:400});
 const result=await handler({rawBody,paddleSignature:signature});
 return new Response(result.body,{status:result.status,headers:{"content-type":"text/plain; charset=utf-8"}});
}
