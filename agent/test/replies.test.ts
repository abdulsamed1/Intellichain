import { describe, expect, it } from "vitest";
import {
  clarifyReply,
  outcomeReply,
  rejectionReply,
  submittedReply,
} from "../src/custom-plugins/replies.js";
import { wireClaimStack, getClaimClient, getMonitorDeps } from "../src/custom-plugins/registry.js";
import type { ClaimAttempt } from "../src/core/extraction.js";
import type { Env } from "../src/core/env.js";
import type { GetGiftClient } from "../src/core/claim.js";
import type { MonitorDeps } from "../src/core/monitor.js";

const INEXACT_WITH_ADDRESS: ClaimAttempt = {
  exact: false,
  candidates: { address: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed" },
  hint: "Gift code found, but no wallet address — ask the user to include the address.",
};
const INEXACT_BLANK: ClaimAttempt = {
  exact: false,
  candidates: {},
  hint: "No gift code and no wallet address found in the message.",
};

describe("reply builders (pure, offline)", () => {
  it("clarifyReply asks for the missing piece in user-facing wording", () => {
    const withAddress = clarifyReply(INEXACT_WITH_ADDRESS);
    expect(withAddress).toMatch(/just reply with your gift code/i);

    const blank = clarifyReply(INEXACT_BLANK);
    expect(blank).toMatch(/gift code and the wallet address/i);
    expect(blank).not.toMatch(/ask the user/i); // internal phrasing never leaks to tweets
  });

  it("submittedReply names the code, the follow-up promise and the tx", () => {
    const text = submittedReply("GIFTX24", "0xabc123" as `0x${string}`);
    expect(text).toContain("GIFTX24");
    expect(text.toLowerCase()).toContain("submitted");
    expect(text).toContain("0xabc123");
  });

  it("outcomeReply speaks truth for minted / released / timeout", () => {
    const minted = outcomeReply({ kind: "minted", tokenId: 7n, giftType: "100 discount" }, "GIFTX24");
    expect(minted).toContain("7");
    expect(minted.toLowerCase()).toContain("minted");
    expect(minted.toLowerCase()).toContain("100 discount".toLowerCase());

    const releasedEvent = outcomeReply({ kind: "released", proof: "event" }, "GIFTX24");
    expect(releasedEvent.toLowerCase()).toContain("released");
    expect(releasedEvent.toLowerCase()).toContain("retry");

    const releasedByPoll = outcomeReply({ kind: "released", proof: "poll" }, "GIFTX24");
    expect(releasedByPoll.toLowerCase()).toContain("retry");

    const timedOut = outcomeReply({ kind: "timeout" }, "GIFTX24");
    expect(timedOut.toLowerCase()).toContain("not finished");
    expect(timedOut.toLowerCase()).toContain("later");
  });

  it("rejectionReply wraps the contract's own text politely", () => {
    const text = rejectionReply("Code validation failed");
    expect(text).toContain("Code validation failed");
  });
});

const FAKE_ENV = {} as unknown as Env;
const fakeClient = {
  claim: async () => ({ kind: "rejected", text: "unused" }),
} as unknown as GetGiftClient;
const fakeMonitor: MonitorDeps = {
  subscribeGiftRedeemed: () => () => {},
  subscribeGiftCodeReleased: () => () => {},
  readGiftCodeRedeemed: async () => true,
  tickMs: 0,
  maxTicks: 1,
};

describe("claim-stack registry", () => {
  // ORDER MATTERS: this must run BEFORE the wiring test in this file.
  it("throws a boot error naming the wiring step when nothing is registered yet", () => {
    expect(() => getClaimClient()).toThrowError(/wireClaimStack/);
    expect(() => getMonitorDeps()).toThrowError(/wireClaimStack/);
  });

  it("wires and returns the registered stack", () => {
    wireClaimStack({ claimClient: fakeClient, monitor: fakeMonitor, env: FAKE_ENV });
    expect(getClaimClient()).toBe(fakeClient);
    expect(getMonitorDeps()).toBe(fakeMonitor);
  });
});
