/**
 * Barrel for the chain-side core. DOM of agent modules imports here:
 * loadEnv (validated .env pipeline), network presets, deterministic claim
 * extraction, the GetGift client and the offline-injectable monitor.
 */
export { loadEnv, EnvError, type Env } from "./env.js";
export * from "./networks.js";
export * from "./extraction.js";
export * from "./claim.js";
export * from "./monitor.js";
