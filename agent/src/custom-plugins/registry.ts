import type { Env } from "../core/env.js";
import type { GetGiftClient } from "../core/claim.js";
import type { MonitorDeps } from "../core/monitor.js";

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
    throw new Error("wireClaimStack called twice — the claim stack is constructed once at boot");
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
