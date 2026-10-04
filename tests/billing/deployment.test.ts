import { createPaddleWebhookHandler } from "../../src/server/billing/deployment.js";
async function run(){
 let failed=false;
 try{createPaddleWebhookHandler({PADDLE_API_KEY:"",PADDLE_WEBHOOK_SECRET:"whsec",SUPABASE_URL:"https://db",SUPABASE_SERVICE_ROLE_KEY:"service"});}
 catch(e){failed=String(e).includes("SERVER_CONFIG_MISSING_PADDLE_API_KEY");}
 if(!failed)throw new Error("DEPLOY-I01");

 const secret="service-super-secret";
 const handler=createPaddleWebhookHandler({
  PADDLE_API_KEY:"api-secret",PADDLE_WEBHOOK_SECRET:"webhook-secret",
  SUPABASE_URL:"https://db",SUPABASE_SERVICE_ROLE_KEY:secret,
 },async()=>({ok:false,status:500,text:async()=>secret}) as any);

 // Missing signature must terminate before Paddle verification or DB transport.
 const r=await handler({rawBody:'{"x":1}',paddleSignature:null});
 if(r.status!==400||r.body.includes(secret)||r.body.includes("api-secret")||r.body.includes("webhook-secret"))throw new Error("DEPLOY-I02");

 // Factory surface is a function only; privileged transport/store is not exposed.
 if(typeof handler!=="function"||Object.keys(handler).length!==0)throw new Error("DEPLOY-I03");
}
run();
