// TrustAnswer v0.3 server-side feature gate.
// Paid capability is derived from current database entitlement on every privileged operation.

export type Feature =
  | "EXPORT"
  | "HISTORICAL_SNAPSHOTS"
  | "FULL_VALIDATOR"
  | "TEAM_REVIEW"
  | "AI_SUGGESTIONS";

export type EntitlementRow = {
  status:"ACTIVE"|"BLOCKED"|"UNKNOWN";
  planCode:"FREE"|"SOLO"|"PRO";
  limits:Record<string,number>;
};

export interface EntitlementReader {
  getCurrentEntitlement(tenantId:string):Promise<EntitlementRow|null>;
}

const planFeatures:Record<"FREE"|"SOLO"|"PRO",ReadonlySet<Feature>>={
  FREE:new Set([]),
  SOLO:new Set(["EXPORT","HISTORICAL_SNAPSHOTS","FULL_VALIDATOR"]),
  PRO:new Set(["EXPORT","HISTORICAL_SNAPSHOTS","FULL_VALIDATOR","TEAM_REVIEW"]),
};

export async function requireFeature(args:{
  tenantId:string;
  feature:Feature;
  reader:EntitlementReader;
}):Promise<EntitlementRow>{
  const row=await args.reader.getCurrentEntitlement(args.tenantId);
  if(!row || row.status!=="ACTIVE") throw new Error("ENTITLEMENT_DENIED");
  if(!planFeatures[row.planCode].has(args.feature)) throw new Error("FEATURE_DENIED");
  return row;
}

// Quota enforcement is intentionally absent here.
// Server mutations must call the atomic database quota RPC. UI may display limits,
// but check-only application logic is never authorization authority.
export function quotaDisplay(args:{
  entitlement:EntitlementRow;
  metric:string;
  currentUsage:number;
}):{limit:number|null;remaining:number|null}{
  const limit=args.entitlement.limits[args.metric];
  if(!Number.isInteger(limit) || limit<0 || !Number.isInteger(args.currentUsage) || args.currentUsage<0)
    return {limit:null,remaining:null};
  return {limit,remaining:Math.max(0,limit-args.currentUsage)};
}
