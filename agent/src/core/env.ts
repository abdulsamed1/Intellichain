import { z } from "zod";
import { NETWORKS, isNetworkName, normalizeAddress, type NetworkPreset, type Address } from "./networks.js";

/**
 * Thrown at boot when any environment configuration is missing or invalid.
 * `variableName` is the CANONICAL .env key (what the operator must fix) —
 * the agent must never die mid-claim on config: every missing/invalid value
 * surfaces here, once, at startup.
 */
export class EnvError extends Error {
  public readonly variableName: string;

  constructor(variableName: string, message: string) {
    super(message);
    this.name = "EnvError";
    this.variableName = variableName;
  }
}

/** Injected test source — plain string map (usually a subset of process.env). */
export type EnvSource = Record<string, string | undefined>;

export interface Env {
  chain: {
    rpcUrl: string;
    network: NetworkPreset;
    chainId: bigint;
    rpcUrlMainnet?: string;
  };
  /** Wallet that signs sendRequest() — must be allowlisted (not a user key!). */
  relayer: { privateKey: `0x${string}` };
  contract: { address: `0x${string}` };
  functions: {
    subscriptionId: bigint;
    slotId: number;
    secretVersion: bigint;
    /** Fulfillment monitor cadence + ceiling (env override pair). */
    fulfillmentTickMs: number;
    fulfillmentMaxTicks: number;
  };
  supabase?: { apiKey: string };
  twitter?: {
    /** Login credentials — atomic: all three or none (see loadEnv). */
    username?: string;
    email?: string;
    password?: string;
    twoFactorSecret?: string;
    /** Watch filter; usable independently of the login group. */
    targetUsers: string[];
    searchEnable: boolean;
  };
  model: {
    cloud?: string;
    openai?: string;
    openrouter?: string;
  };
  serverPort: number;
}

const HEX_64_LOOSE = /^(0x)?[0-9a-fA-F]{64}$/;
const EVM_ADDRESS = /^0x[0-9a-fA-F]{40}$/;
const DECIMAL = /^\d+$/;

const schema = z
  .object({
    NETWORK: z.string().optional(),
    SEPOLIA_RPC_URL: z.string().min(1, "missing — the JSON-RPC endpoint for the selected network"),
    EVM_PRIVATE_KEY: z.string().regex(HEX_64_LOOSE, "must be 64 hex characters, optionally 0x-prefixed"),
    CONTRACT_ADDRESS: z.string().regex(EVM_ADDRESS, "must be an EVM address (0x + 40 hex characters)"),
    FUNCTIONS_SUBSCRIPTION_ID: z
      .string()
      .regex(DECIMAL, "must be a positive integer (the Functions billing id)")
      .refine((raw) => {
        // regex failures still reach the refine chain in zod: guard the cast
        if (!DECIMAL.test(raw)) return false;
        return BigInt(raw) > 0n;
      }, "must be greater than 0 — a zero subscription id can never bill"),
    MAINNET_RPC_URL: z.string().min(1).optional(),
    FUNCTIONS_SLOT_ID: z
      .string()
      .regex(DECIMAL, "must be a decimal integer 0..255")
      .refine((raw) => Number(raw) <= 255, "uint8 range: 0..255")
      .optional()
      .default("0"),
    FUNCTIONS_SECRET_VERSION: z
      .string()
      .regex(DECIMAL, "must be a decimal integer")
      .optional()
      .default("0"),
    FULFILLMENT_TICK_MS: z
      .string()
      .regex(DECIMAL, "must be a decimal number of milliseconds")
      .refine((v) => Number(v) > 0, "must be greater than 0 (0 would hot-poll the RPC)")
      .optional()
      .default("15000"),
    FULFILLMENT_MAX_TICKS: z
      .string()
      .regex(DECIMAL, "must be a decimal number of poll ticks")
      .refine((v) => Number(v) >= 1, "must be at least 1 (0 would never await anything)")
      .optional()
      .default("60"),
    SUPABASE_API_KEY: z.string().min(1).optional(),
    TWITTER_USERNAME: z.string().min(1).optional(),
    TWITTER_EMAIL: z.string().min(1).optional(),
    TWITTER_PASSWORD: z.string().min(1).optional(),
    TWITTER_2FA_SECRET: z.string().min(1).optional(),
    TWITTER_TARGET_USERS: z.string().optional().default(""),
    TWITTER_SEARCH_ENABLE: z.string().optional().default("false"),
    CLOUD: z.string().optional(),
    OPENAI_API_KEY: z.string().optional(),
    OPENROUTER_API_KEY: z.string().optional(),
    SERVER_PORT: z.string().regex(DECIMAL, "must be a decimal port number").optional().default("3000"),
  })
  // undocumented keys are ignorable junk, never an error
  .strip();

/**
 * Load and validate agent configuration. The default source is process.env;
 * tests inject a synthetic map. Every failure must be `EnvError` naming the
 * canonical variable so operators see exactly what to fix.
 */
export function loadEnv(source: EnvSource = process.env): Env {
  const parsed = schema.safeParse(source);
  if (!parsed.success) {
    // first issue wins: report it against its canonical variable name
    const issue = parsed.error.issues[0]!;
    const variableName = String(issue.path[0] ?? "AGENT_ENV");
    throw new EnvError(variableName, `${variableName}: ${issue.message}`);
  }
  const raw = parsed.data;

  // network selection (defaults to sepolia; per NetworkConfigLibrary mirror)
  const networkName = raw.NETWORK;
  if (networkName !== undefined && !isNetworkName(networkName)) {
    throw new EnvError("NETWORK", `NETWORK: unknown network "${networkName}" (supported: sepolia, anvil)`);
  }
  const network = NETWORKS[networkName ?? "sepolia"];

  // contract address: checksum validation beyond the shape regex
  let contractAddress: `0x${string}`;
  try {
    contractAddress = normalizeAddress(raw.CONTRACT_ADDRESS);
  } catch (err) {
    throw new EnvError("CONTRACT_ADDRESS", (err as Error).message);
  }

  // A zero secret version on a LIVE network silently burns LINK: the DON
  // runs the claim check WITHOUT the Supabase key, fails every lookup, and
  // the contract releases every code. Refuse; `make don-secrets` in agent/
  // uploads the secrets and writes the real slot/version. Local networks
  // (anvil) skip DON secrets by design, so 0 stays legal there.
  if (
    network.name !== "anvil" &&
    BigInt(raw.FUNCTIONS_SUBSCRIPTION_ID) > 0n &&
    BigInt(raw.FUNCTIONS_SECRET_VERSION) === 0n
  ) {
    throw new EnvError(
      "FUNCTIONS_SECRET_VERSION",
      "FUNCTIONS_SECRET_VERSION: 0 on a live network burns LINK on unusable requests - run `make don-secrets` in agent/ first",
    );
  }

  const privateKey = `0x${raw.EVM_PRIVATE_KEY.replace(/^0x/, "")}` as `0x${string}`;

  // twitter login credentials are atomic: partial groups are operator typos
  const twitterParts = [raw.TWITTER_USERNAME, raw.TWITTER_EMAIL, raw.TWITTER_PASSWORD];
  const present = twitterParts.filter((part): part is string => part !== undefined);
  if (present.length > 0 && present.length !== twitterParts.length) {
    throw new EnvError(
      "TWITTER_GROUP",
      "TWITTER_USERNAME / TWITTER_EMAIL / TWITTER_PASSWORD must be set together " +
        `(got ${present.length} of 3; the agent needs full login credentials)`,
    );
  }

  const searchEnableRaw = raw.TWITTER_SEARCH_ENABLE;
  if (searchEnableRaw !== "true" && searchEnableRaw !== "false") {
    throw new EnvError("TWITTER_SEARCH_ENABLE", "TWITTER_SEARCH_ENABLE: must be 'true' or 'false'");
  }

  // twitter handles are CASE-INSENSITIVE; dedupe first-seen so a repeated
  // mention doubled nothing (e.g. "vipuser, vipUser" one watch only)
  const targetUsers = Array.from(
    new Map(
      raw.TWITTER_TARGET_USERS.split(",")
        .map((name) => name.trim())
        .filter((name) => name.length > 0)
        .map((name) => [name.toLowerCase(), name] as const),
    ).values(),
  );

  return {
    chain: {
      rpcUrl: raw.SEPOLIA_RPC_URL,
      network,
      chainId: network.chainId,
      rpcUrlMainnet: raw.MAINNET_RPC_URL,
    },
    relayer: { privateKey },
    contract: { address: contractAddress },
    functions: {
      subscriptionId: BigInt(raw.FUNCTIONS_SUBSCRIPTION_ID),
      slotId: Number(raw.FUNCTIONS_SLOT_ID),
      secretVersion: BigInt(raw.FUNCTIONS_SECRET_VERSION),
      fulfillmentTickMs: Number(raw.FULFILLMENT_TICK_MS),
      fulfillmentMaxTicks: Number(raw.FULFILLMENT_MAX_TICKS),
    },
    supabase: raw.SUPABASE_API_KEY ? { apiKey: raw.SUPABASE_API_KEY } : undefined,
    // the twitter block exists whenever ANY twitter config is present; the
    // login fields themselves are optional and always issued atomically
    twitter:
      present.length > 0 || targetUsers.length > 0 || raw.TWITTER_SEARCH_ENABLE === "true"
        ? {
            username: raw.TWITTER_USERNAME,
            email: raw.TWITTER_EMAIL,
            password: raw.TWITTER_PASSWORD,
            twoFactorSecret: raw.TWITTER_2FA_SECRET,
            targetUsers,
            searchEnable: searchEnableRaw === "true",
          }
        : undefined,
    model: {
      cloud: raw.CLOUD,
      openai: raw.OPENAI_API_KEY,
      openrouter: raw.OPENROUTER_API_KEY,
    },
    serverPort: Number(raw.SERVER_PORT),
  };
}
