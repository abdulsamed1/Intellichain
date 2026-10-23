import { normalizeAddress, type Address } from "./networks.js";

/**
 * Deterministic claim extraction (Review Focus: never mint the wrong pair).
 * Strategy:
 *  1. find EVM-address SHAPES with strict boundaries (a 0x + 64-hex blob such
 *     as a tx hash must never yield a "0x + first 40" pseudo-address);
 *  2. EIP-55 validate them (mixed-case must checksum; lowercase/uppercase ok);
 *  3. mask every 0x+≥40hex span so its innards never masquerade as a code;
 *  4. scan the remaining text for one code token.
 *
 * A gift code, in this phase, is a single token of 5..32 characters from
 * [A-Za-z0-9_-] containing at least one digit ("Xyzzy_12-3", "GIFTX24",
 * "SUPERGIFT777"). Phrase codes with spaces ("100 discount") are a Phase-B
 * configurable pattern — they cannot be extracted reliably without one.
 */

export interface Claim {
  address: Address;
  code: string;
}

export interface ClaimCandidates extends Partial<Claim> {
  addresses?: Address[];
  codes?: string[];
}

export type ClaimAttempt =
  | { exact: true; address: Address; code: string }
  | { exact: false; candidates: ClaimCandidates; hint: string };

/** whole-token address shape with strict boundaries (no run-on hex/words) */
const ADDRESSED_TOKEN = /(?<![0-9a-fA-F])0x([0-9a-fA-F]{40})(?![0-9a-fA-F])/g;
/** any 0x + long hex run (address, tx hash, key material) */
const HEX_RUN = /0x[0-9a-fA-F]{40,}/g;
const CODE_TOKEN = /[A-Za-z0-9_-]+/g;

/** Shape-only test: 0x followed by exactly 40 hex characters. */
export function looksLikeEvmAddress(candidate: string): boolean {
  return /^0x[0-9a-fA-F]{40}$/.test(candidate);
}

/** EIP-55-validated address candidates; broken-checksum shapes are ignored. */
function findAddressCandidates(text: string): Address[] {
  const valid: Address[] = [];
  for (const match of text.matchAll(ADDRESSED_TOKEN)) {
    try {
      valid.push(normalizeAddress(`0x${match[1]}`));
    } catch {
      // e.g. mixed-case input with a broken checksum — never mint to it
    }
  }
  return valid;
}

/** Code tokens: 5..32 chars of [A-Za-z0-9_-] carrying at least one digit. */
function findCodeCandidates(maskedText: string): string[] {
  const candidates = new Set<string>();
  for (const match of maskedText.matchAll(CODE_TOKEN)) {
    const token = match[0];
    if (token.length < 5 || token.length > 32) continue;
    if (!/\d/.test(token)) continue;
    candidates.add(token);
  }
  return [...candidates];
}

/** Masks every 0x + ≥40 hex span so its innards can never become a code. */
function maskHexRuns(text: string): string {
  return text.replace(HEX_RUN, (span) => " ".repeat(span.length));
}

export function extractClaim(text: string): ClaimAttempt {
  const trimmed = text.trim();
  if (trimmed.length === 0) {
    return {
      exact: false,
      candidates: {},
      hint: "Empty message: no gift code and no wallet address found.",
    };
  }

  const addresses = findAddressCandidates(trimmed);
  const masked = maskHexRuns(trimmed);
  const codes = findCodeCandidates(masked);

  const soleAddress = addresses.length === 1 ? addresses[0] : undefined;
  const soleCode = codes.length === 1 ? codes[0] : undefined;

  if (soleAddress !== undefined && soleCode !== undefined) {
    return { exact: true, address: soleAddress, code: soleCode };
  }

  return {
    exact: false,
    candidates: {
      address: soleAddress,
      addresses: addresses.length > 1 ? addresses : undefined,
      code: soleCode,
      codes: codes.length > 1 ? codes : undefined,
    },
    hint: buildHint(addresses, codes),
  };
}

function buildHint(addresses: Address[], codes: string[]): string {
  if (addresses.length === 0 && codes.length === 0) {
    return "No gift code and no wallet address found in the message.";
  }
  if (codes.length === 0) {
    return "Wallet address found, but no gift code token — ask the user to include their gift code.";
  }
  if (addresses.length === 0) {
    return "Gift code found, but no wallet address — ask the user to include the address that should receive the gift NFT.";
  }
  return (
    `Ambiguous message: found ${addresses.length} wallet address(es) and ${codes.length} gift code candidate(s)` +
    " — ask the user to state exactly one address and one code."
  );
}
