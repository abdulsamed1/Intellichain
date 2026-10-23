import { createPublicClient, createWalletClient, decodeErrorResult, getAddress, http, isHex, defineChain } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { sepolia as sepoliaChain } from "viem/chains";
import type { Abi, Address, Chain, PublicClient, WalletClient } from "viem";
import getGiftAbiJson from "./artifacts/GetGift.json";
import type { Env } from "./env.js";
import type { Claim } from "./extraction.js";

/**
 * ABI of the hardened contract — abi-only slice of
 * `contract/out/GetGift.sol/GetGift.json`; the file IS the array (vite
 * resolves array-root JSON as the array itself).
 */
export const GetGiftAbi = getGiftAbiJson as unknown as Abi;

/**
 * Human mapping for every GetGift custom error. The agent surfaces these as
 * conversational truth, never raw revert blobs. Keep in lockstep with
 * `contract/src/GetGift.sol` — the artifact makes undecodable selectors
 * fall to the generic message rather than lie.
 */
const ERROR_TEXT: Record<string, string> = {
  CodeAlreadyRedeemed:
    "This gift code was already redeemed — the gift may have been minted to someone else. Please ask the sender for a fresh code.",
  RequestAlreadyInFlight:
    "A claim is already in flight — this contract processes one claim at a time. Try again in a few minutes.",
  CallerNotAllowlisted:
    "The claim wallet is not on the contract allowlist. An admin must add it first.",
  InvalidGiftCode:
    "That gift code does not pass validation — please double-check it and try again.",
  InvalidRecipient:
    "The recipient address is invalid, so no claim could be submitted. Please reply with the wallet that should receive the gift.",
  CannotRemoveLastAllowlisted:
    "Refusing an admin removal that would leave the contract without any admins.",
  AddressNotAllowlisted: "That address is not on the allowlist.",
  InvalidGiftDefinition:
    "The oracle returned a gift type this contract has no metadata for — the code was released for retry.",
  FulfillmentNotInProcess:
    "Internal fulfillment guard tripped — no claim attempt matched an active fulfillment.",
  RequestNotStuck: "There is no stuck claim to reset right now.",
};

const GENERIC_REVERT_TEXT =
  "The claim could not be submitted — the transaction reverted for an unexpected reason. Please try again shortly.";

/**
 * Pulls raw revert data out of a viem-style error. Search order:
 * `.data` → `.cause.data` → `.cause.cause.data` (viem nests originals).
 */
function extractRevertData(err: unknown): `0x${string}` | undefined {
  if (isHex(err)) return err;
  let cursor = err as { data?: unknown; cause?: unknown } | undefined;
  for (let depth = 0; depth < 3 && cursor !== undefined && cursor !== null; depth++) {
    if (isHex(cursor.data)) return cursor.data;
    cursor = cursor.cause as typeof cursor;
  }
  return undefined;
}

/**
 * Maps any thrown value from a contract interaction into text a tweet user
 * can act on. Decodes custom errors via the contract ABI; unknown/string
 * reverts map to the safe generic text.
 */
export function mapContractError(err: unknown): string {
  const data = extractRevertData(err);
  if (data) {
    try {
      const decoded = decodeErrorResult({ abi: GetGiftAbi, data });
      const friendly = ERROR_TEXT[decoded.errorName];
      if (friendly) return friendly;
    } catch {
      // undecodable revert blob: fall through to the generic text
    }
  }
  return GENERIC_REVERT_TEXT;
}

export type ClaimOutcome =
  | { kind: "submitted"; txHash: `0x${string}` }
  | { kind: "rejected"; text: string };

/** The wallet surface the claim path needs — a real WalletClient satisfies it. */
export interface ClaimWallet {
  writeContract: (...args: Parameters<WalletClient["writeContract"]>) => Promise<`0x${string}`>;
}

export interface GetGiftClientParams {
  env: Env;
  walletClient: ClaimWallet;
  /** reserved for fulfillment reads (monitor wiring, Task 5) */
  publicClient?: PublicClient;
}

/**
 * Drives the hardened GetGift contract. Mirrors the contract's own cheap
 * validation client-side (so obviously-wrong claims never burn Functions
 * LINK), then submits sendRequest to the real audience — the contract — and
 * lets ITS custom errors speak through mapContractError.
 */
export class GetGiftClient {
  private readonly env: Env;
  private readonly walletClient: ClaimWallet;
  private readonly publicClient?: PublicClient;

  constructor(params: GetGiftClientParams) {
    this.env = params.env;
    this.walletClient = params.walletClient;
    this.publicClient = params.publicClient;
  }

  /** Exposed for monitor wiring once fulfillment tracking joins. */
  get public(): PublicClient | undefined {
    return this.publicClient;
  }

  /** Exposed read-only for callers composing their own flows. */
  get config(): { env: Env } {
    return { env: this.env };
  }

  /** Client-side mirror of the contract's cheap checks — no RPC needed. */
  private validate(c: Claim): string | undefined {
    if (c.code.trim().length === 0) {
      return "That gift code looks empty — please include the code exactly as you received it.";
    }
    if (c.address === "0x0000000000000000000000000000000000000000") {
      return "The recipient address is the zero address — please reply with a real wallet address.";
    }
    try {
      getAddress(c.address); // EIP-55 sanity (mixed-case must checksum)
    } catch {
      return "That wallet address is not a valid Ethereum address — please double-check it.";
    }
    return undefined;
  }

  async claim(c: Claim): Promise<ClaimOutcome> {
    const rejection = this.validate(c);
    if (rejection !== undefined) return { kind: "rejected", text: rejection };

    try {
      const txHash = (await this.walletClient.writeContract({
        address: this.env.contract.address,
        abi: GetGiftAbi,
        functionName: "sendRequest",
        args: [
          this.env.functions.slotId,
          this.env.functions.secretVersion,
          [c.code],
          this.env.functions.subscriptionId,
          c.address,
        ],
      } as never)) as `0x${string}`;
      return { kind: "submitted", txHash };
    } catch (err) {
      return { kind: "rejected", text: mapContractError(err) };
    }
  }
}

/** Builds real viem clients from env (network-bound; typechecked, not unit-tested). */
export function makeClients(env: Env): { walletClient: WalletClient; publicClient: PublicClient } {
  let chain: Chain;
  if (env.chain.network.name === "sepolia") {
    chain = sepoliaChain;
  } else {
    chain = defineChain({
      id: Number(env.chain.network.chainId),
      name: env.chain.network.name,
      nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
      rpcUrls: { default: { http: [env.chain.rpcUrl] } },
      testnet: true,
    });
  }

  const account = privateKeyToAccount(env.relayer.privateKey);
  const transport = http(env.chain.rpcUrl);
  return {
    publicClient: createPublicClient({ chain, transport }),
    walletClient: createWalletClient({ chain, account, transport }),
  };
}
