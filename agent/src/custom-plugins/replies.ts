import type { ClaimAttempt } from "../core/extraction.js";
import type { TrackResult } from "../core/monitor.js";

/**
 * Pure, user-facing reply text for the claim flow. Kept apart from the
 * runtime so the wording is offline-testable and the runtime stays wiring
 * only. Extraction's `hint` is an OPERATOR diagnostic (third-person by
 * design); bot replies never leak it.
 */

/**
 * Asks for exactly the piece that is missing from the message.
 * Candidate-aware: if we already have the address we only ask for the code,
 * and vice versa.
 */
export function clarifyReply(attempt: Extract<ClaimAttempt, { exact: false }>): string {
  if (attempt.candidates.address !== undefined) {
    return "I found your claim — please just reply with your gift code (the code and nothing else works best).";
  }
  if (attempt.candidates.code !== undefined) {
    return "I found a gift code — please reply with the wallet address that should receive the gift NFT.";
  }
  return "I'd love to redeem your gift! Reply with your gift code and the wallet address (say \"gifting to 0x…\", or paste the code and the 0x address together in one message).";
}

/** Confirms submission and promises the follow-up (the monitor fulfills it). */
export function submittedReply(code: string, txHash: `0x${string}`): string {
  return (
    `Your claim for code "${code}" is submitted onchain (tx ${txHash}). ` +
    "I'm watching the fulfillment now and will reply here as soon as it settles — usually within a minute."
  );
}

/** Reports the settled fulfillment honestly, including the degraded paths. */
export function outcomeReply(result: TrackResult, code: string): string {
  switch (result.kind) {
    case "minted":
      return (
        `🎉 Minted! Your gift ("${result.giftType}", token #${result.tokenId}) is in your wallet. ` +
        `Thanks for claiming "${code}"!`
      );
    case "released":
      return (
        `Your claim for "${code}" was not minted — the contract released the code ` +
        `(oracle did not complete it). No balance was spent, and you can retry with the same code at any time.`
      );
    case "timeout":
      return (
        `Your claim for "${code}" has not finished yet — fulfillment is slower than usual (not failed). ` +
        "I'll check again later; you can also follow along in the Functions dashboard in the meantime."
      );
  }
}

/** Wraps a contract rejection so the reason the user sees stays conversational. */
export function rejectionReply(text: string): string {
  return `I couldn't submit your claim: ${text}`;
}
