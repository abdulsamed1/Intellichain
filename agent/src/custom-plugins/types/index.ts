import type { Claim } from "../../core/extraction.js";

/**
 * The action's parameters are a deterministic extraction result — no LLM
 * object generation anywhere in the claim path.
 */
export type ClaimParams = Claim;
