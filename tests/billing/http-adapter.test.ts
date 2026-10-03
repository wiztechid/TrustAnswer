import { handlePaddleWebhookRequest } from "../../src/server/billing/http-adapter.js";
async function run(){
 let calls=0,seen:any=null; const callCount=()=>calls;
 const app=async(a:any)=>{calls++;seen=a;return {status:200,body:"applied"};};

 let r=await handlePaddleWebhookRequest(new Request("https://x/webhook",{method:"GET"}),app);
 if(r.status!==405||callCount()!==0||r.headers.get("allow")!=="POST")throw new Error("HTTPA-I01");

 r=await handlePaddleWebhookRequest(new Request("https://x/webhook",{method:"POST",body:"raw"}),app);
 if(r.status!==400||callCount()!==0)throw new Error("HTTPA-I02");

 const raw=' { "exact" : "body\\n" } ';
 r=await handlePaddleWebhookRequest(new Request("https://x/webhook",{method:"POST",headers:{"Paddle-Signature":"sig"},body:raw}),app);
 if(r.status!==200||await r.text()!=="applied"||callCount()!==1||seen.rawBody!==raw||seen.paddleSignature!=="sig")throw new Error("HTTPA-I03");

 r=await handlePaddleWebhookRequest(new Request("https://x/webhook",{method:"POST",headers:{"Paddle-Signature":"sig"},body:""}),app);
 if(r.status!==400||callCount()!==1)throw new Error("HTTPA-I04");

 // A consumed Request cannot be silently reconstructed; body-read failure is fail-closed.
 const consumed=new Request("https://x/webhook",{method:"POST",headers:{"Paddle-Signature":"sig"},body:"raw"});
 await consumed.text();
 r=await handlePaddleWebhookRequest(consumed,app);
 if(r.status!==400||callCount()!==1)throw new Error("HTTPA-I05");
}
run();
