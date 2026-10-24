import { Character, Clients, defaultCharacter, ModelProviderName } from "@elizaos/core";
import getGiftPlugin from "./custom-plugins/index.js";
import type { Env } from "./core/env.js";

/**
 * GiftPilot — the agent character. Model provider follows the .env keys with
 * an explicit precedence (see selectModelProvider); DELEGATED secrets ride
 * the injected character clone, never committed files.
 */
export interface ModelSelection {
  provider: ModelProviderName;
  /** true when a CLOUD key is riding the OpenAI-compatible surface. */
  cloudOnOpenAI: boolean;
}

/**
 * Key precedence: OPENAI -> OPENROUTER -> CLOUD (as an OpenAI-compatible
 * catch-all). elizaOS 0.1.7 has no CLOUD provider; its OPENAI surface reads
 * OPENAI_API_URL straight from process.env, so operators pointing CLOUD at a
 * custom endpoint set that variable in agent/.env and it just works.
 */
export function selectModelProvider(env: Env): ModelSelection {
  if (env.model.openai) {
    return { provider: ModelProviderName.OPENAI, cloudOnOpenAI: false };
  }
  if (env.model.openrouter) {
    return { provider: ModelProviderName.OPENROUTER, cloudOnOpenAI: false };
  }
  if (env.model.cloud) {
    return { provider: ModelProviderName.OPENAI, cloudOnOpenAI: true };
  }
  throw new Error(
    "No model key configured — set OPENAI_API_KEY, OPENROUTER_API_KEY or CLOUD in agent/.env",
  );
}

export function buildCharacter(env: Env): Character {
  const selection = selectModelProvider(env);

  const secrets: Record<string, string> = {};
  if (env.model.openai) {
    secrets.OPENAI_API_KEY = env.model.openai;
  }
  if (env.model.openrouter) {
    // Upstream getTokenForProvider prefers the bare OPENROUTER secret.
    secrets.OPENROUTER_API_KEY = env.model.openrouter;
    secrets.OPENROUTER = env.model.openrouter;
  }
  if (env.model.cloud) {
    // CLOUD rides the OPENAI provider; tuned endpoints via OPENAI_API_URL.
    if (!env.model.openai) {
      secrets.OPENAI_API_KEY = env.model.cloud;
    }
    secrets.CLOUD = env.model.cloud;
  }

  return {
    ...defaultCharacter,
    name: "GiftPilot",
    bio: [
      "GiftPilot redeems onchain gift codes sent as tweets.",
      "Users reply with a gift code plus the wallet address that should receive the gift; GiftPilot submits the claim, tracks fulfillment and reports the outcome in the same thread.",
    ],
    lore: [],
    system:
      "You are GiftPilot, an agent that redeems gift codes onchain via the GET_GIFT action. " +
      "Never invent gift codes or wallet addresses; only act when the user provides a 0x wallet address and a gift code. " +
      "Claim replies are deterministic outcomes of the claim flow, not creative writing.",
    plugins: [getGiftPlugin],
    // The twitter watcher REQUIRES a login trio (the vendored client's zod
    // schema hard-requires it); a chain-only provisioning boots without it
    // instead of dying at client start with a generic validation error.
    clients: env.twitter?.username !== undefined ? [Clients.DIRECT, Clients.TWITTER] : [Clients.DIRECT],
    modelProvider: selection.provider,
    settings: {
      secrets,
    },
  };
}
