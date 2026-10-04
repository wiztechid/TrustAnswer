import worker from "../../src/worker.js";

const env={
 PADDLE_API_KEY:"api-secret",
 PADDLE_WEBHOOK_SECRET:"webhook-secret",
 SUPABASE_URL:"https://db.invalid",
 SUPABASE_SERVICE_ROLE_KEY:"service-secret",
};

async function run(){
 const missing=await worker.fetch(new Request("https://trustanswer.invalid/nope"),env);
 if(missing.status!==404)throw new Error("WORKER-I01");

 const get=await worker.fetch(new Request("https://trustanswer.invalid/api/webhooks/paddle",{method:"GET"}),env);
 if(get.status!==405||get.headers.get("allow")!=="POST")throw new Error("WORKER-I02");

 const post=await worker.fetch(new Request("https://trustanswer.invalid/api/webhooks/paddle",{method:"POST",body:'{"x":1}'}),env);
 if(post.status!==400)throw new Error("WORKER-I03");
 const body=await post.text();
 if(body.includes("service-secret")||body.includes("api-secret")||body.includes("webhook-secret"))throw new Error("WORKER-I04");
}
run();
