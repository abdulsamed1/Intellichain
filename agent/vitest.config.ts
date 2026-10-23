import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // strict offline rule: agent unit tests never touch Twitter, RPC, or
    // model providers — all network surfaces are injected/mocked
    include: ["test/**/*.test.ts"],
    passWithNoTests: true,
    environment: "node",
  },
});
