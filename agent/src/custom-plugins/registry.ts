import type { Env } from "../core/env.js";
import type { GetGiftClient } from "../core/claim.js";
import type { MonitorDeps } from "../core/monitor.js";
import { elizaLogger } from "@elizaos/core";

interface ClaimStack {
  claimClient: GetGiftClient;
  monitor: MonitorDeps;
  env: Env;
}

/**
 * Boot-time wiring registry. elizaOS 0.1.7 actions have no service DI: the
 * runtime constructs the chain clients ONCE (in src/index.ts) and publishes
 * them here; the plugin action reads them per invocation. Unwired accessors
 * throw a message that names the boot step — a wrong boot order should be
 * loud, not a null dereference.
 */
let stack: ClaimStack | undefined;

export function wireClaimStack(parts: ClaimStack): void {
  if (stack) {
    // Re-wiring REPLACES the previous stack: the runtime add-agent API can
    // legitimately start another agent in-process. One stack per process is
    // the supported shape (multi-character deployments are out of Phase A
    // scope) — an accidental re-wire stays loud via this log.
    elizaLogger.error("wireClaimStack called again — replacing the previous claim stack");
  }
  stack = parts;
}

export function getClaimClient(): GetGiftClient {
  if (!stack) {
    throw new Error(
      "Claim stack not wired — call wireClaimStack() in src/index.ts BEFORE the plugin action runs.",
    );
  }
  return stack.claimClient;
}

export function getMonitorDeps(): MonitorDeps {
  if (!stack) {
    throw new Error(
      "Claim stack not wired — call wireClaimStack() in src/index.ts BEFORE the plugin action runs.",
    );
  }
  return stack.monitor;
}
