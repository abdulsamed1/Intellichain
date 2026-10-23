import { beforeEach, describe, expect, it, vi } from "vitest";
import { getFunctionSelector, type WalletClient } from "viem";
import { GetGiftClient, mapContractError } from "../src/core/claim.js";
import type { Env } from "../src/core/env.js";

const MINIMAL_ENV: Env = {
  chain: {
    rpcUrl: "https://eth-sepolia.gateway.invalid",
    network: {
      name: "sepolia",
      chainId: 11155111n,
      router: "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0",
      donId: "fun-ethereum-sepolia-1",
      linkToken: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
    },
    chainId: 11155111n,
  },
  relayer: { privateKey: ("0x" + "ab".repeat(32)) as `0x${string}` },
  contract: { address: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed" },
  functions: {
    subscriptionId: 17n,
    slotId: 0,
    secretVersion: 1n,
    fulfillmentTickMs: 15000,
    fulfillmentMaxTicks: 60,
  },
  model: {},
  serverPort: 3000,
};

const CLAIM = { address: "0x82E0764F3a3B3FD1d8d16b0455E2B73e27F6E051" as const, code: "GIFTX24" };
const TX_HASH = "0x34d7a80000000000000000000000000000000000deadbeef001" as `0x${string}`;

// revert fixtures: raw data with a known GetGift custom-error selector
const revertData = (name: string): `0x${string}` => getFunctionSelector(`${name}()`);
const errorWith = (data: string | undefined): Error =>
  Object.assign(new Error("execution reverted"), { data });

describe("mapContractError", () => {
  it("speaks for CodeAlreadyRedeemed", () => {
    const text = mapContractError(errorWith(revertData("CodeAlreadyRedeemed")));
    expect(text.toLowerCase()).toContain("already redeemed");
  });

  it("speaks for RequestAlreadyInFlight", () => {
    const text = mapContractError(errorWith(revertData("RequestAlreadyInFlight")));
    expect(text.toLowerCase()).toContain("in flight");
  });

  it("speaks for CallerNotAllowlisted", () => {
    expect(mapContractError(errorWith(revertData("CallerNotAllowlisted"))).toLowerCase()).toContain(
      "allowlist",
    );
  });

  it("speaks for InvalidGiftCode and InvalidRecipient", () => {
    expect(mapContractError(errorWith(revertData("InvalidGiftCode"))).toLowerCase()).toContain("code");
    expect(mapContractError(errorWith(revertData("InvalidRecipient"))).toLowerCase()).toContain("address");
  });

  it("prefers a nested cause revert blob (viem error shape)", () => {
    const nested = Object.assign(new Error("outer"), {
      cause: errorWith(revertData("RequestNotStuck")),
    });
    expect(mapContractError(nested).toLowerCase()).toContain("stuck");
  });

  it("falls back to safe generic text for unknown selectors", () => {
    const text = mapContractError(errorWith("0xdeadbeef"));
    expect(text.toLowerCase()).toContain("unexpected");
  });

  it("falls back to safe generic text for plain string reverts", () => {
    expect(mapContractError(new Error("some require message")).toLowerCase()).toContain("unexpected");
  });
});

describe("GetGiftClient.claim", () => {
  let writeContract: ReturnType<typeof vi.fn>;
  let client: GetGiftClient;

  beforeEach(() => {
    writeContract = vi.fn();
    client = new GetGiftClient({
      env: MINIMAL_ENV,
      walletClient: { writeContract } as unknown as WalletClient,
      publicClient: undefined,
    });
  });

  it("submit path: writeContract sees the exact contract argument order", async () => {
    writeContract.mockResolvedValue(TX_HASH);
    const outcome = await client.claim(CLAIM);
    expect(outcome).toEqual({ kind: "submitted", txHash: TX_HASH });
    const request = writeContract.mock.calls[0]![0]! as unknown as {
      address: string;
      functionName: string;
      args: unknown[];
    };
    expect(request.address).toBe(MINIMAL_ENV.contract.address);
    expect(request.functionName).toBe("sendRequest");
    // sendRequest(uint8 slot, uint64 version, string[] args, uint64 subId, address recipient)
    expect(request.args[0]).toBe(MINIMAL_ENV.functions.slotId);
    expect(request.args[1]).toBe(MINIMAL_ENV.functions.secretVersion);
    expect(request.args[2]).toEqual([CLAIM.code]);
    expect(request.args[3]).toBe(MINIMAL_ENV.functions.subscriptionId);
    expect(request.args[4]).toBe(CLAIM.address);
  });

  it("revert path: rejection is mapped, never an exception", async () => {
    writeContract.mockRejectedValue(errorWith(revertData("CodeAlreadyRedeemed")));
    const outcome = await client.claim(CLAIM);
    expect(outcome).toEqual({ kind: "rejected", text: expect.stringMatching(/already redeemed/i) });
  });

  it("zero recipient is rejected client-side without any RPC call", async () => {
    const outcome = await client.claim({ ...CLAIM, address: "0x0000000000000000000000000000000000000000" });
    expect(outcome).toEqual({ kind: "rejected", text: expect.stringMatching(/address/i) });
    expect(writeContract).not.toHaveBeenCalled();
  });

  it("blank code is rejected client-side without any RPC call", async () => {
    const outcome = await client.claim({ ...CLAIM, code: "   " });
    expect(outcome).toEqual({ kind: "rejected", text: expect.stringMatching(/code/i) });
    expect(writeContract).not.toHaveBeenCalled();
  });
});
