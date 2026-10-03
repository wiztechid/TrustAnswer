import type { BillingStore, TrustedSubscriptionEvent } from "./paddle-webhook.js";
import {
  bindAndCommitInitialTrustedEvent,
  commitTrustedEvent,
  type BillingRpcClient,
} from "./database-adapter.js";

export interface BillingIdentityResolver {
  resolveBillingTenant(args:{provider:"PADDLE";customerId:string;subscriptionId:string}):Promise<string|null>;
}

/**
 * Thin composition only. The database owns replay, ordering, reconciliation,
 * plan mapping, entitlement derivation, and atomic state transitions.
 */
export class RpcBackedBillingStore implements BillingStore {
  constructor(
    private readonly identity:BillingIdentityResolver,
    private readonly rpc:BillingRpcClient,
  ){}

  resolveTenant(customerId:string,subscriptionId:string){
    return this.identity.resolveBillingTenant({provider:"PADDLE",customerId,subscriptionId});
  }

  bindAndCommitInitialSubscription(args:{
    handle:string;event:TrustedSubscriptionEvent;payloadHash:string;
  }){
    return bindAndCommitInitialTrustedEvent({
      handle:args.handle,event:args.event,payloadHash:args.payloadHash,rpc:this.rpc,
    });
  }

  commitVerifiedEvent(args:{event:TrustedSubscriptionEvent;payloadHash:string}){
    return commitTrustedEvent({event:args.event,payloadHash:args.payloadHash,rpc:this.rpc});
  }
}
