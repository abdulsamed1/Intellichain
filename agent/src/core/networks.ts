import { getAddress, keccak256, stringToBytes, type Address } from "viem";

/**
 * Network runtime constants for the agent — mirrors
 * contract/script/utility/NetworkConfigLibrary.sol `getNetworkConfig()`.
 *
 * Deliberate duplication (documented in the agent design spec): the contract
 * repo is the source of truth for DEPLOYMENT values; the agent repo publishes
 * standalone runtime constants so its tooling (functions-toolkit needs the
 * router + donId for DON-secrets uploads) has no cross-package dependency.
 * If the library drifts, the `test/env.test.ts` preset pinning breaks first.
 */
export interface NetworkPreset {
  name: string;
  chainId: bigint;
  router: Address;
  /** Functions DON identifier as the toolkit expects it (utf8 label). */
  donId: string;
  linkToken: Address;
}

export const NETWORKS = {
  sepolia: {
    name: "sepolia",
    chainId: 11155111n,
    router: "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0",
    donId: "fun-ethereum-sepolia-1",
    linkToken: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
  },
  anvil: {
    name: "anvil",
    chainId: 31337n,
    router: "0xd5E230Caa7352F357E1dd3A34c5033F4a3e35f3D",
    donId: "dev-anvil-don-id",
    linkToken: "0x94d3c68a91c5D02D28E9215eA12736eb5E8e432F",
  },
} as const satisfies Record<string, NetworkPreset>;

export type NetworkName = keyof typeof NETWORKS;

export const isNetworkName = (raw: string): raw is NetworkName =>
  raw === "sepolia" || raw === "anvil";

/**
 * True when the lowercase keccak-derived EIP-55 checksum of a MIXED-case
 * address matches the casing of every hex letter (EIP-55 §checksum).
 */
function isValidEip55(mixedCase0x: string): boolean {
  const body = mixedCase0x.slice(2);
  const hash = keccak256(stringToBytes(body.toLowerCase())).slice(2);
  for (let i = 0; i < 40; i++) {
    const ch = body[i]!;
    if (ch >= "0" && ch <= "9") continue; // digits carry no encoding
    const mustBeUpper = parseInt(hash[i]!, 16) >= 8;
    const isUpper = ch >= "A" && ch <= "F";
    const isLower = ch >= "a" && ch <= "f";
    if (mustBeUpper ? !isUpper : !isLower) return false;
  }
  return true;
}

/**
 * EIP-55 checksum-validate and normalize an EVM address. Accepts
 * all-lowercase and all-uppercase input (common in envs/wallet exports);
 * a MIXED-case input must carry a valid EIP-55 checksum. viem's getAddress
 * alone normalizes everything — strictness is supplied here.
 */
export function normalizeAddress(raw: string): Address {
  const trimmed = raw.trim();
  if (!/^0x[0-9a-fA-F]{40}$/.test(trimmed)) {
    throw new Error(
      `invalid EVM address "${trimmed}" (expected exactly 0x + 40 hex characters)`,
    );
  }
  const lowercased = trimmed.toLowerCase();
  if (trimmed !== lowercased && trimmed !== lowercased.toUpperCase() && !isValidEip55(trimmed)) {
    throw new Error(
      `invalid EVM address "${trimmed}" (mixed-case input must carry a valid EIP-55 checksum)`,
    );
  }
  return getAddress(lowercased);
}
