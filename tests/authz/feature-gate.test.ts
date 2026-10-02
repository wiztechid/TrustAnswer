import {requireFeature,requireQuota} from "../../src/server/authz/feature-gate";

async function run(){
  const activePro={status:"ACTIVE" as const,planCode:"PRO" as const,limits:{questions:2500}};
  await requireFeature({tenantId:"t",feature:"TEAM_REVIEW",reader:{getCurrentEntitlement:async()=>activePro}});

  for(const row of [null,{status:"UNKNOWN" as const,planCode:"PRO" as const,limits:{}},{status:"BLOCKED" as const,planCode:"PRO" as const,limits:{}}]){
    let denied=false;
    try{await requireFeature({tenantId:"t",feature:"EXPORT",reader:{getCurrentEntitlement:async()=>row}});}catch{denied=true;}
    if(!denied) throw new Error("FG01");
  }

  let aiDenied=false;
  try{await requireFeature({tenantId:"t",feature:"AI_SUGGESTIONS",reader:{getCurrentEntitlement:async()=>activePro}});}catch{aiDenied=true;}
  if(!aiDenied) throw new Error("FG02");

  requireQuota({entitlement:activePro,metric:"questions",currentUsage:2499,increment:1});
  let quotaDenied=false;
  try{requireQuota({entitlement:activePro,metric:"questions",currentUsage:2500,increment:1});}catch{quotaDenied=true;}
  if(!quotaDenied) throw new Error("FG03");
}
run();
