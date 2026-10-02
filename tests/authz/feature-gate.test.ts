import {requireFeature,quotaDisplay} from "../../src/server/authz/feature-gate.js";

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

  const display=quotaDisplay({entitlement:activePro,metric:"questions",currentUsage:2499});
  if(display.limit!==2500 || display.remaining!==1) throw new Error("FG03");
  const unknownDisplay=quotaDisplay({entitlement:activePro,metric:"missing",currentUsage:0});
  if(unknownDisplay.limit!==null || unknownDisplay.remaining!==null) throw new Error("FG04");
}
run();
