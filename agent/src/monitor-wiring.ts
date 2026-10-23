import type { PublicClient } from "viem";
import type { Env } from "./core/env.js";
import { GetGiftAbi } from "./core/claim.js";
import {
  type GiftCodeReleasedEvent,
  type GiftRedeemedEvent,
  type MonitorDeps,
} from "./core/monitor.js";

/**
 * viem wiring for the fulfillment monitor. `MonitorDeps` (core/monitor.ts)
 * stays injected and offline-testable; nothing in this module runs unless
 * boot constructs real clients via makeClients() and passes them in.
 */

type RawArgs = Record<string, unknown>;

function decodeArgs(args: unknown): RawArgs {
  if (args && typeof args === "object") return args as RawArgs;
  throw new Error("event log without decodable args");
}

export function makeMonitorDeps(
  env: Env,
  publicClient: PublicClient,
): MonitorDeps {
  const address = env.contract.address;

  const subscribe = <E>(
    eventName: string,
    decode: (args: unknown) => E,
    fn: (ev: E) => void,
  ): (() => void) =>
    publicClient.watchContractEvent({
      address,
      abi: GetGiftAbi,
      eventName,
      onLogs: (logs) => {
        for (const log of logs) {
          try {
            fn(decode((log as unknown as { args: unknown }).args));
          } catch (error) {
            console.error(`Failed to decode ${eventName} log:`, error);
          }
        }
      },
      onError: (error) => {
        console.error(`${eventName} watcher error:`, error);
      },
    });

  return {
    subscribeGiftRedeemed(fn) {
      return subscribe("GiftRedeemed", (raw) => {
        const args = decodeArgs(raw);
        const decoded: GiftRedeemedEvent = {
          requestId: String(args.requestId),
          recipient: String(args.recipient),
          giftCode: String(args.giftCode),
          giftName: String(args.giftName),
          tokenId: BigInt(args.tokenId as bigint),
        };
        return decoded;
      }, fn);
    },
    subscribeGiftCodeReleased(fn) {
      return subscribe("GiftCodeReleased", (raw) => {
        const args = decodeArgs(raw);
        const decoded: GiftCodeReleasedEvent = {
          giftCode: String(args.giftCode),
        };
        return decoded;
      }, fn);
    },
    async readGiftCodeRedeemed(code) {
      const stillClaimed = (await publicClient.readContract({
        address,
        abi: GetGiftAbi,
        functionName: "giftCodeRedeemed",
        args: [code],
      })) as boolean;
      return stillClaimed;
    },
    tickMs: env.functions.fulfillmentTickMs,
    maxTicks: env.functions.fulfillmentMaxTicks,
  };
}
