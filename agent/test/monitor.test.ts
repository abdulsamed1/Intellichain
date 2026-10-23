import { describe, expect, it } from "vitest";
import { trackFulfillment, type MonitorDeps } from "../src/core/monitor.js";

const RECIPIENT = "0x82E0764F3a3B3FD1d8d16b0455E2B73e27F6E051";
const CODE = "GIFTX24";

/** Builds a controllable offline watcher: tests fire events manually. */
class FakeWatcher {
  giftRedeemedHandlers: ((ev: unknown) => void)[] = [];
  giftReleasedHandlers: ((ev: unknown) => void)[] = [];
  /** claim-state proxy: starts "claimed" (matches post-send reality) */
  redeemed = true;

  deps(): MonitorDeps {
    return {
      subscribeGiftRedeemed: (fn) => {
        this.giftRedeemedHandlers.push(fn as (ev: unknown) => void);
        return () => {
          this.giftRedeemedHandlers = this.giftRedeemedHandlers.filter((f) => f !== fn);
        };
      },
      subscribeGiftCodeReleased: (fn) => {
        this.giftReleasedHandlers.push(fn as (ev: unknown) => void);
        return () => {
          this.giftReleasedHandlers = this.giftReleasedHandlers.filter((f) => f !== fn);
        };
      },
      readGiftCodeRedeemed: async () => this.redeemed,
      tickMs: 0,
      maxTicks: 8,
    };
  }

  emitRedeemed(tokenId: bigint, recipient: string = RECIPIENT, code: string = CODE): void {
    const ev = { requestId: "0x" + "11".repeat(32), recipient, giftCode: code, giftName: "100 discount", tokenId };
    for (const fn of this.giftRedeemedHandlers.slice()) fn(ev);
  }

  emitReleased(code: string = CODE): void {
    const ev = { giftCode: code };
    for (const fn of this.giftReleasedHandlers.slice()) fn(ev);
  }
}

describe("trackFulfillment", () => {
  it("reports minted with token id and gift type on the GiftRedeemed event", async () => {
    const fake = new FakeWatcher();
    const pending = trackFulfillment(fake.deps(), { code: CODE, recipient: RECIPIENT });
    fake.emitRedeemed(7n);
    await expect(pending).resolves.toEqual({ kind: "minted", tokenId: 7n, giftType: "100 discount" });
  });

  it("reports released on the GiftCodeReleased event (proof: event)", async () => {
    const fake = new FakeWatcher();
    const pending = trackFulfillment(fake.deps(), { code: CODE, recipient: RECIPIENT });
    fake.emitReleased();
    await expect(pending).resolves.toEqual({ kind: "released", proof: "event" });
  });

  it("poll sees the released state even without an event (proof: poll)", async () => {
    const fake = new FakeWatcher();
    fake.redeemed = false; // the claim flag was cleared (release paths reset it)
    const pending = trackFulfillment(fake.deps(), { code: CODE, recipient: RECIPIENT });
    // no manual event emission; the first poll tick settles it
    await expect(pending).resolves.toEqual({ kind: "released", proof: "poll" });
  });

  it("times out when nothing completes within maxTicks", async () => {
    const fake = new FakeWatcher();
    const deps = { ...fake.deps(), maxTicks: 3 };
    const pending = trackFulfillment(deps, { code: CODE, recipient: RECIPIENT });
    await expect(pending).resolves.toEqual({ kind: "timeout" });
  });

  it("first-wins: a release after the mint already settled cannot flip the answer", async () => {
    const fake = new FakeWatcher();
    const pending = trackFulfillment(fake.deps(), { code: CODE, recipient: RECIPIENT });
    fake.emitRedeemed(9n); // mint settles the answer FIRST
    fake.emitReleased(); // release arrives later — provably irrelevant
    fake.redeemed = false;
    await expect(pending).resolves.toEqual({ kind: "minted", tokenId: 9n, giftType: "100 discount" });
  });

  it("ignores events for other recipients or codes (then times out)", async () => {
    const fake = new FakeWatcher();
    const deps = { ...fake.deps(), maxTicks: 3 };
    const pending = trackFulfillment(deps, { code: CODE, recipient: RECIPIENT });
    fake.emitRedeemed(1n, "0x0000000000000000000000000000000000000042"); // other recipient
    fake.emitReleased("OTHERCODE1"); // other code
    fake.emitRedeemed(2n, RECIPIENT, "OTHERCODE2"); // matching recipient, other code
    // nothing matches + polls stay "claimed": the loop runs out => timeout
    await expect(pending).resolves.toEqual({ kind: "timeout" });
  });

  it("unsubscribes handlers once settled", async () => {
    const fake = new FakeWatcher();
    const pending = trackFulfillment(fake.deps(), { code: CODE, recipient: RECIPIENT });
    fake.emitRedeemed(5n);
    await pending;
    expect(fake.giftRedeemedHandlers).toHaveLength(0);
    expect(fake.giftReleasedHandlers).toHaveLength(0);
  });
});
