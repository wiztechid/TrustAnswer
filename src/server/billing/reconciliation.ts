// TrustAnswer v0.3 reconciliation contract.
// ProviderClient is implemented server-side using a secret Paddle API key.

export type ProviderSubscriptionSnapshot = {
  subscriptionId: string;
  customerId: string;
  status: string;
  priceIds: string[];
  updatedAt: string;
};

export interface ProviderClient {
  getSubscription(subscriptionId: string): Promise<ProviderSubscriptionSnapshot>;
}

export interface ReconciliationStore {
  listTenantsNeedingReconciliation(limit: number): Promise<Array<{
    tenantId: string;
    subscriptionId: string;
    customerId: string;
  }>>;
  reconcileFromProvider(args: {
    tenantId: string;
    snapshot: ProviderSubscriptionSnapshot;
  }): Promise<void>;
  failClosed(tenantId: string, reason: string): Promise<void>;
}

export async function reconcileBillingBatch(args: {
  provider: ProviderClient;
  store: ReconciliationStore;
  limit?: number;
}): Promise<{checked:number;reconciled:number;failedClosed:number}> {
  const rows=await args.store.listTenantsNeedingReconciliation(args.limit ?? 100);
  let reconciled=0, failedClosed=0;
  for(const row of rows){
    try{
      const snapshot=await args.provider.getSubscription(row.subscriptionId);
      if(snapshot.subscriptionId!==row.subscriptionId || snapshot.customerId!==row.customerId){
        await args.store.failClosed(row.tenantId,"PROVIDER_IDENTITY_MISMATCH");
        failedClosed++;
        continue;
      }
      await args.store.reconcileFromProvider({tenantId:row.tenantId,snapshot});
      reconciled++;
    }catch{
      await args.store.failClosed(row.tenantId,"PROVIDER_RECONCILIATION_FAILED");
      failedClosed++;
    }
  }
  return {checked:rows.length,reconciled,failedClosed};
}
