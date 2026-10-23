import type { Address } from "./networks.js";

/**
 * Fulfillment tracking (Review Focus: a released code must never present as
 * "minted", and a mint settles the answer permanently).
 *
 * Contract reality, post-shield: `giftCodeRedeemed` is re-asserted TRUE on
 * the mint path, so the poll reading false reliably means "released" even
 * when no event is observable. Events carry richer outcomes fast; the poll
 * is the safety net against missed/unindexed events.
 *
 * All chain surface is INJECTED and offline-mockable; the viem wiring lives
 * with the runtime task.
 */

/** Shape of a contract GiftRedeemed event once decoded by the runtime. */
export interface GiftRedeemedEvent {
  requestId: string;
  recipient: string;
  giftCode: string;
  giftName: string;
  tokenId: bigint;
}

/** Shape of a contract GiftCodeReleased event once decoded by the runtime. */
export interface GiftCodeReleasedEvent {
  giftCode: string;
}

export interface MonitorDeps {
  /** Returns an unsubscribe handle (wired at runtime to viem log watcher). */
  subscribeGiftRedeemed(fn: (ev: GiftRedeemedEvent) => void): () => void;
  subscribeGiftCodeReleased(fn: (ev: GiftCodeReleasedEvent) => void): () => void;
  /** true = the code is still claimed (keep waiting); false = released. */
  readGiftCodeRedeemed(code: string): Promise<boolean>;
  /** poll cadence, milliseconds; 0 in tests. */
  tickMs: number;
  /** poll ceiling before the outcome degrades to timeout. */
  maxTicks: number;
}

export type TrackResult =
  | { kind: "minted"; tokenId: bigint; giftType: string }
  | { kind: "released"; proof: "event" | "poll" }
  | { kind: "timeout" };

const sleep = (ms: number): Promise<void> =>
  ms <= 0 ? Promise.resolve() : new Promise((resolve) => setTimeout(resolve, ms));

export async function trackFulfillment(
  deps: MonitorDeps,
  args: { code: string; recipient: Address }
): Promise<TrackResult> {
  return new Promise<TrackResult>((resolve) => {
    let settled = false;
    const unsubs: Array<() => void> = [];

    const done = (result: TrackResult): void => {
      if (settled) return;
      settled = true;
      for (const unsub of unsubs) unsub();
      resolve(result);
    };

    const want = {
      code: args.code,
      recipient: args.recipient.toLowerCase() as `0x${string}`,
    };

    unsubs.push(
      deps.subscribeGiftRedeemed((ev) => {
        if (ev.giftCode === want.code && ev.recipient.toLowerCase() === want.recipient) {
          done({ kind: "minted", tokenId: ev.tokenId, giftType: ev.giftName });
        }
      }),
    );
    unsubs.push(
      deps.subscribeGiftCodeReleased((ev) => {
        if (ev.giftCode === want.code) done({ kind: "released", proof: "event" });
      }),
    );

    void (async () => {
      for (let tick = 0; tick < deps.maxTicks; tick++) {
        await sleep(deps.tickMs);
        if (settled) return;
        try {
          if ((await deps.readGiftCodeRedeemed(want.code)) === false) {
            done({ kind: "released", proof: "poll" });
            return;
          }
        } catch {
          // an RPC hiccup must not end tracking mid-flight; keep ticking
        }
      }
      if (!settled) done({ kind: "timeout" });
    })();
  });
}
