import {
  type Action,
  type HandlerCallback,
  type IAgentRuntime,
  type Memory,
  type State,
  elizaLogger,
} from "@elizaos/core";
import { extractClaim } from "../../core/extraction.js";
import type { ClaimOutcome } from "../../core/claim.js";
import { trackFulfillment } from "../../core/monitor.js";
import { getClaimClient, getMonitorDeps } from "../registry.js";
import {
  clarifyReply,
  outcomeReply,
  rejectionReply,
  submittedReply,
} from "../replies.js";

/**
 * GET_GIFT — the claim flow. Data decisions are DETERMINISTIC
 * (core/extraction): the address is EIP-55-checked, the code is mask-matched.
 * elizaOS still decides WHEN to invoke the action through its standard
 * message pipeline; nothing here generates objects with an LLM.
 */

/** Channels that may trigger an onchain claim. */
const CLAIM_SOURCES = new Set(["twitter", "direct"]);

export const getGiftAction: Action = {
  name: "GET_GIFT",
  similes: ["REDEEM_GIFT", "CLAIM_GIFT"],
  description:
    "Redeem a gift code: extract the code and recipient wallet from the message, " +
    "submit the Chainlink Functions request on the GetGift contract, then track " +
    "the request and report the outcome in the same thread.",
  validate: async (_runtime: IAgentRuntime, message: Memory): Promise<boolean> => {
    const source = message.content.source;
    return typeof source === "string" && CLAIM_SOURCES.has(source);
  },
  handler: async (
    _runtime: IAgentRuntime,
    message: Memory,
    _state?: State,
    _options?: any,
    callback?: HandlerCallback,
  ): Promise<boolean> => {
    const source = message.content.source ?? "direct";
    const inReplyTo = message.id;
    const reply = (
      text: string,
      action: string,
    ): Promise<Memory[]> | undefined =>
      callback?.({ text, inReplyTo, source, action });

    const attempt = extractClaim(message.content.text ?? "");

    if (!attempt.exact) {
      // Internal diagnostic hints (extraction) never leak into replies; the
      // user-facing wording lives in clarifyReply.
      await reply(clarifyReply(attempt), "GET_GIFT");
      return true;
    }

    let outcome: ClaimOutcome;
    try {
      outcome = await getClaimClient().claim({
        address: attempt.address,
        code: attempt.code,
      });
    } catch (error) {
      // GetGiftClient maps CONTRACT errors itself; whatever escapes here is a
      // transport failure (RPC/network). Report it verbatim — no sugarcoating.
      const text = error instanceof Error ? error.message : String(error);
      elizaLogger.error("GET_GIFT claim submission failed:", error);
      await reply(rejectionReply(text), "GET_GIFT");
      return false;
    }

    if (outcome.kind === "rejected") {
      await reply(rejectionReply(outcome.text), "GET_GIFT");
      return true;
    }

    await reply(submittedReply(attempt.code, outcome.txHash), "GET_GIFT");

    // Fulfillment takes minutes; the interaction loop must NOT block on it.
    // The captured callback stays valid (it is the same reply bridge the
    // vendored twitter/direct clients expose) so the outcome lands in-thread.
    const { code, address } = attempt;
    void trackFulfillment(getMonitorDeps(), { code, recipient: address })
      .then(async (result) => {
        elizaLogger.log(`GET_GIFT fulfillment for ${code}: ${result.kind}`);
        await reply(outcomeReply(result, code), "CONTINUE");
      })
      .catch((error: unknown) => {
        elizaLogger.error(`GET_GIFT tracking failed for ${code}:`, error);
      });

    return true;
  },
  examples: [
    [
      {
        user: "user",
        content: {
          text: "Redeem my gift code GIFTX24 for 0x82E0764F3a3B3FD1d8d16b0455E2B73e27F6E051 please!",
          action: "GET_GIFT",
        },
      },
      {
        user: "assistant",
        content: {
          text: "Submitting your claim now — I'll follow up here when the oracle settles.",
          action: "GET_GIFT",
        },
      },
    ],
    [
      {
        user: "user",
        content: {
          text: "I want to claim GIFTX24, the wallet is 0x388C818CA8B9251b393131C08a736A67CcB19297",
          action: "GET_GIFT",
        },
      },
      {
        user: "assistant",
        content: {
          text: "Claiming now; watch this thread for the fulfillment update.",
          action: "GET_GIFT",
        },
      },
    ],
  ],
};

export default getGiftAction;
