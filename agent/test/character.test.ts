import { describe, expect, it } from "vitest";
import { Clients } from "@elizaos/core";
import { buildCharacter } from "../src/character.js";
import { loadEnv } from "../src/core/env.js";

// canonical minimal env (mirrors test/env.test.ts; secrets are dummies)
const MINIMAL: Record<string, string> = {
  SEPOLIA_RPC_URL: "https://eth-sepolia.gateway.invalid",
  EVM_PRIVATE_KEY: "0x" + "ab".repeat(32),
  CONTRACT_ADDRESS: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed",
  FUNCTIONS_SUBSCRIPTION_ID: "17",
  FUNCTIONS_SECRET_VERSION: "1",
  OPENAI_API_KEY: "sk-test-not-real",
};

describe("buildCharacter", () => {
  it("chains the twitter watcher only when a login trio is configured", () => {
    const withTwitter = buildCharacter(
      loadEnv({
        ...MINIMAL,
        TWITTER_USERNAME: "appaccount",
        TWITTER_EMAIL: "ops@host.invalid",
        TWITTER_PASSWORD: "hunter2",
      }),
    );
    expect(withTwitter.clients).toEqual([Clients.DIRECT, Clients.TWITTER]);

    // chain-only provisioning stays honest: no login trio, no twitter client
    const chainOnly = buildCharacter(loadEnv(MINIMAL));
    expect(chainOnly.clients).toEqual([Clients.DIRECT]);
  });

  it("mounts the model secrets on the runtime clone, not anywhere durable", () => {
    const character = buildCharacter(loadEnv(MINIMAL));
    expect(character.name).toBe("GiftPilot");
    expect(character.settings?.secrets?.OPENAI_API_KEY).toBe("sk-test-not-real");
  });
});
