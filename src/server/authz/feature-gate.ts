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

export function requireQuota(args:{
  entitlement:EntitlementRow;
  metric:string;
  currentUsage:number;
  increment:number;
}):void{
  if(!Number.isInteger(args.currentUsage) || !Number.isInteger(args.increment) || args.increment<=0)
    throw new Error("INVALID_USAGE");
  const limit=args.entitlement.limits[args.metric];
  if(!Number.isInteger(limit) || limit<0) throw new Error("QUOTA_UNKNOWN");
  if(args.currentUsage+args.increment>limit) throw new Error("QUOTA_EXCEEDED");
}
