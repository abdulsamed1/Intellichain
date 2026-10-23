import { describe, expect, it } from "vitest";
import { extractClaim, looksLikeEvmAddress } from "../src/core/extraction.js";

describe("extractClaim", () => {
  it("extracts an explicit wallet + code tweet deterministically", () => {
    const tweet = "Hey @GiftBot my wallet is 0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed and my code is Xyzzy_12-3 🎁";
    const claim = extractClaim(tweet);
    expect(claim).toEqual({
      exact: true,
      address: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
      code: "Xyzzy_12-3",
    });
  });

  it("keeps an all-uppercase code verbatim", () => {
    const tweet = "wallet 0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed code= " + "SUPERGIFT777";
    expect(extractClaim(tweet)).toEqual({
      exact: true,
      address: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
      code: "SUPERGIFT777",
    });
  });

  it("does NOT fake an address out of a longer hex blob (tx hash, key, etc.)", () => {
    // 0x + 64 hex: a tx hash, not an address — no candidate address exists
    const tweet =
      "my code is Xyzzy_12-3 and the proof was 0x3a5c7b9d1e2f4a6b8c9d0e1f2a3b4c5d6e7f8a9b1c2d3e4f5a6b7c8d9e0f1a2b";
    const claim = extractClaim(tweet);
    expect(claim.exact).toBe(false);
    if (!claim.exact) {
      expect(claim.candidates?.address).toBeUndefined();
      expect(claim.candidates?.code).toBe("Xyzzy_12-3");
    }
  });

  it("rejects invalid checksums into the inexact path", () => {
    // flip one casing letter from the EIP-55 vector => invalid checksum
    const tweet = "claim for 0x5aAeb6053F3E94C9B9A09f33669435E7Ef1BeAed with code GIFT_988";
    expect(extractClaim(tweet).exact).toBe(false);
  });

  it("reports ambiguous two-address/two-code tweets with candidates", () => {
    const tweet =
      "first wallet 0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed code ALPHA12 and second wallet 0x82e0764f3a3b3fd1d8d16b0455e2b73e27f6e051 code BETA34";
    const claim = extractClaim(tweet);
    expect(claim.exact).toBe(false);
    if (!claim.exact) {
      expect(claim.candidates?.addresses?.length).toBe(2);
      expect(claim.candidates?.codes?.length).toBe(2);
      expect(claim.hint).toBeTruthy();
    }
  });

  it("says no-code clearly when none exists", () => {
    const claim = extractClaim("I want my gift please!!!");
    expect(claim.exact).toBe(false);
    if (!claim.exact) {
      expect(claim.candidates.addresses).toBeUndefined();
      expect(claim.candidates.codes).toBeUndefined();
      expect(claim.hint).toContain("No gift");
    }
  });

  it("empty text is inexact, never a throw", () => {
    expect(extractClaim("").exact).toBe(false);
    expect(extractClaim("   \n\t").exact).toBe(false);
  });

  it("tie-breaks a single address + single code even without the 'code:' keyword", () => {
    const tweet = "redeem 0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed GIFTX24";
    expect(extractClaim(tweet)).toEqual({
      exact: true,
      address: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
      code: "GIFTX24",
    });
  });
});

describe("looksLikeEvmAddress", () => {
  it("accepts only 0x+40hex shapes", () => {
    expect(looksLikeEvmAddress("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")).toBe(true);
    expect(looksLikeEvmAddress("0x5AAEB6053F3E94C9B9A09F33669435E7EF1BEAED")).toBe(true);
    expect(looksLikeEvmAddress("0x1234")).toBe(false);
    expect(looksLikeEvmAddress("")).toBe(false);
  });
});
