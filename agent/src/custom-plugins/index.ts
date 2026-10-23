import type { Plugin } from "@elizaos/core";
import { getGiftAction } from "./actions/getGift.ts";

/**
 * The claim plugin. No providers: the wallet/monitor stack is constructed
 * once at boot (core/claim.ts makeClients + monitor-wiring.ts) and published
 * through custom-plugins/registry.ts — see src/index.ts.
 */
export const getGiftPlugin: Plugin = {
  name: "intellichain-get-gift",
  description:
    "Redeems gift codes against the hardened GetGift Chainlink Functions contract.",
  providers: [],
  evaluators: [],
  services: [],
  actions: [getGiftAction],
};

export default getGiftPlugin;
