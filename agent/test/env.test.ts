import { describe, expect, it } from "vitest";
import { EnvError, loadEnv } from "../src/core/env.js";
import { NETWORKS, normalizeAddress } from "../src/core/networks.js";

// canonical minimal env: the loader must boot with ONLY the required vars
// (contract address is the EIP-55 spec example vector so expectations are
// verifiable against the standard, not invented)
const MINIMAL: Record<string, string> = {
  SEPOLIA_RPC_URL: "https://eth-sepolia.gateway.invalid",
  // exactly 64 hex chars (ab × 32)
  EVM_PRIVATE_KEY: "0x" + "ab".repeat(32),
  CONTRACT_ADDRESS: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed",
  FUNCTIONS_SUBSCRIPTION_ID: "17",
};
const CHECKSUMMED_CONTRACT = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed";

describe("NETWORKS presets mirror contract/script/utility/NetworkConfigLibrary.sol", () => {
  it("sepolia matches the library exactly", () => {
    expect(NETWORKS.sepolia).toEqual({
      name: "sepolia",
      chainId: 11155111n,
      router: "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0",
      donId: "fun-ethereum-sepolia-1",
      linkToken: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
    });
  });

  it("anvil (contract's other supported network) matches too", () => {
    expect(NETWORKS.anvil).toEqual({
      name: "anvil",
      chainId: 31337n,
      router: "0xd5E230Caa7352F357E1dd3A34c5033F4a3e35f3D",
      donId: "dev-anvil-don-id",
      linkToken: "0x94d3c68a91c5D02D28E9215eA12736eb5E8e432F",
    });
  });

  it("normalizeAddress accepts lowercase and returns EIP-55 (EIP-55 doc vector)", () => {
    expect(normalizeAddress("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")).toBe(CHECKSUMMED_CONTRACT);
  });

  it("normalizeAddress rejects wrong lengths and bad checksums", () => {
    expect(() => normalizeAddress("0x1234")).toThrow();
    // one flipped letter case from the valid EIP-55 vector checksums INVALID
    expect(() => normalizeAddress("0x5aAeb6053F3E94C9B9A09f33669435E7Ef1BeAed")).toThrow();
  });
});

describe("loadEnv", () => {
  it("boots from only the required variables, applying defaults", () => {
    const env = loadEnv(MINIMAL);
    expect(env.relayer.privateKey).toBe(MINIMAL.EVM_PRIVATE_KEY);
    expect(env.contract.address).toBe(CHECKSUMMED_CONTRACT);
    expect(env.chain.rpcUrl).toBe(MINIMAL.SEPOLIA_RPC_URL);
    expect(env.chain.chainId).toBe(11155111n);
    expect(env.chain.network.donId).toBe("fun-ethereum-sepolia-1");
    expect(env.functions.subscriptionId).toBe(17n);
    expect(env.functions.slotId).toBe(0);
    expect(env.functions.secretVersion).toBe(0n);
    expect(env.serverPort).toBe(3000);
  });

  it("names the missing variable in EnvError at boot", () => {
    const broken = { ...MINIMAL };
    delete broken.SEPOLIA_RPC_URL;
    try {
      loadEnv(broken);
      expect.unreachable("must have thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(EnvError);
      const envError = err as EnvError;
      expect(envError.variableName).toBe("SEPOLIA_RPC_URL");
      expect(envError.message).toContain("SEPOLIA_RPC_URL");
    }
  });

  it("accepts a private key without the 0x prefix and normalizes it", () => {
    const env = loadEnv({ ...MINIMAL, EVM_PRIVATE_KEY: MINIMAL.EVM_PRIVATE_KEY!.slice(2) });
    expect(env.relayer.privateKey).toBe(MINIMAL.EVM_PRIVATE_KEY);
  });
  it("rejects a malformed private key naming EVM_PRIVATE_KEY", () => {
    expect(() => loadEnv({ ...MINIMAL, EVM_PRIVATE_KEY: "0x1234" })).toThrowError(/EVM_PRIVATE_KEY/);
  });

  it("rejects a malformed contract address naming CONTRACT_ADDRESS", () => {
    expect(() => loadEnv({ ...MINIMAL, CONTRACT_ADDRESS: "0xnotanaddress" })).toThrowError(
      /CONTRACT_ADDRESS/,
    );
  });

  it("rejects a non-numeric subscription id naming FUNCTIONS_SUBSCRIPTION_ID", () => {
    expect(() => loadEnv({ ...MINIMAL, FUNCTIONS_SUBSCRIPTION_ID: "abc" })).toThrowError(
      /FUNCTIONS_SUBSCRIPTION_ID/,
    );
  });

  it("rejects a zero subscription id (billing never works)", () => {
    expect(() => loadEnv({ ...MINIMAL, FUNCTIONS_SUBSCRIPTION_ID: "0" })).toThrowError(
      /FUNCTIONS_SUBSCRIPTION_ID/,
    );
  });

  it("coerces TWITTER_TARGET_USERS into a trimmed deduped list", () => {
    const env = loadEnv({ ...MINIMAL, TWITTER_TARGET_USERS: "vipuser, secondUser ,vipUser,,thirdUser" });
    expect(env.twitter?.targetUsers).toEqual(["vipuser", "secondUser", "vipUser", "thirdUser"]);
  });

  it("keeps twitter group atomic: username without credentials fails", () => {
    try {
      loadEnv({ ...MINIMAL, TWITTER_USERNAME: "someuser" });
      expect.unreachable("must have thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(EnvError);
      expect((err as EnvError).message).toContain("TWITTER_PASSWORD");
    }
  });

  it("accepts a full twitter group with search disabled by default", () => {
    const env = loadEnv({
      ...MINIMAL,
      TWITTER_USERNAME: "someuser",
      TWITTER_EMAIL: "user@host.invalid",
      TWITTER_PASSWORD: "hunter2",
      TWITTER_TARGET_USERS: "vipuser",
    });
    expect(env.twitter?.username).toBe("someuser");
    expect(env.twitter?.searchEnable).toBe(false);
  });

  it("treats an undocumented variable as ignorable junk, not an error", () => {
    expect(() => loadEnv({ ...MINIMAL, BOGUS_JUNK: "1" })).not.toThrow();
  });
});
