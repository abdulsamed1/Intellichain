/**
 * DON-hosted secrets uploader — modernized from the template's
 * scripts/uploadToDON.js (MIT, elizaOS starter).
 *
 * Improvements over the template:
 *  - network constants come from src/core/networks (sepolia only — the DON
 *    gateways do not exist for anvil);
 *  - the slot id is operator-configurable via FUNCTIONS_SLOT_ID (default 0);
 *  - on success it UPDATES agent/.env: FUNCTIONS_SLOT_ID + FUNCTIONS_SECRET_VERSION
 *    (so the runtime never drifts from the uploaded secret) and writes the
 *    belt-and-suspenders donSecretsInfo.txt (gitignored, like the template);
 *  - it NEVER prints the secret itself.
 *
 * Run via: make don-secrets (from agent/)
 *
 * DON-hosted secrets EXPIRE after ~24h — re-run this script periodically.
 */
import { ethers } from "ethers";
import { SecretsManager } from "@chainlink/functions-toolkit";
import dotenv from "dotenv";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import Path from "node:path";
import { EnvError } from "../src/core/env.js";
import { NETWORKS } from "../src/core/networks.js";

dotenv.config();

const REQUIRED = ["SEPOLIA_RPC_URL", "EVM_PRIVATE_KEY", "SUPABASE_API_KEY"] as const;

for (const name of REQUIRED) {
  const value = process.env[name];
  if (value === undefined || value.trim().length === 0) {
    throw new EnvError(name, `${name}: required for the DON-secrets upload (set it in agent/.env)`);
  }
}

const rpcUrl = process.env.SEPOLIA_RPC_URL!;
const privateKey = process.env.EVM_PRIVATE_KEY!;
const supabaseApiKey = process.env.SUPABASE_API_KEY!;

const slotIdNumber = Number(process.env.FUNCTIONS_SLOT_ID ?? "0");
if (!Number.isInteger(slotIdNumber) || slotIdNumber < 0 || slotIdNumber > 255) {
  throw new EnvError("FUNCTIONS_SLOT_ID", "FUNCTIONS_SLOT_ID: must be an integer 0..255");
}
const expirationTimeMinutes = 1440; // DON-hosted secrets live ~24h

// testnet gateway endpoints for Sepolia (from Chainlink Functions docs)
const gatewayUrls = [
  "https://01.functions-gateway.testnet.chain.link/",
  "https://02.functions-gateway.testnet.chain.link/",
];

async function main(): Promise<void> {
  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
  const signer = new ethers.Wallet(privateKey).connect(provider);

  const secretsManager = new SecretsManager({
    signer,
    functionsRouterAddress: NETWORKS.sepolia.router,
    donId: NETWORKS.sepolia.donId,
  });
  await secretsManager.initialize();

  console.log("Encrypting secrets (key material never printed)...");
  const encryptedSecretsObj = await secretsManager.encryptSecrets({ apikey: supabaseApiKey });

  console.log(
    `Uploading encrypted secrets to ${gatewayUrls.length} gateways (slot ${slotIdNumber}, expiry ${expirationTimeMinutes} min)...`,
  );
  const uploadResult = await secretsManager.uploadEncryptedSecretsToDON({
    encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
    gatewayUrls,
    slotId: slotIdNumber,
    minutesUntilExpiration: expirationTimeMinutes,
  });

  if (!uploadResult.success) {
    throw new Error(`Encrypted secrets were not uploaded to the gateways: ${gatewayUrls.join(", ")}`);
  }

  const version = parseInt(String(uploadResult.version));

  // belt-and-suspenders info file (gitignored) + the .env upgrade
  writeFileSync(
    "donSecretsInfo.txt",
    JSON.stringify(
      {
        donHostedSecretsVersion: version.toString(),
        slotId: slotIdNumber.toString(),
        expirationTimeMinutes: expirationTimeMinutes.toString(),
        uploadedAt: new Date().toISOString(),
      },
      null,
      2,
    ),
  );

  updateDotEnv({
    FUNCTIONS_SLOT_ID: slotIdNumber.toString(),
    FUNCTIONS_SECRET_VERSION: version.toString(),
  });

  console.log(
    `\n✅ Uploaded: slot ${slotIdNumber}, version ${version}. Wrote FUNCTIONS_SLOT_ID / FUNCTIONS_SECRET_VERSION into .env.`,
  );
  console.log(`⏰ DON-hosted secrets expire in ~${expirationTimeMinutes} minutes — re-run make don-secrets before then.`);
}

/** Replaces existing `KEY=...` lines or appends at the end (idempotent). */
function updateDotEnv(updates: Record<string, string>): void {
  const envPath = Path.resolve(import.meta.dirname ?? ".", "..", ".env");
  const existing = existsSync(envPath) ? readFileSync(envPath, "utf8") : "";
  let lines = existing.split("\n").filter((line) => line.length > 0);
  for (const [key, value] of Object.entries(updates)) {
    const lineRegex = new RegExp(`^${key}=.*$`, "m");
    if (lineRegex.test(existing)) {
      lines = lines.map((line) => (line.startsWith(`${key}=`) ? `${key}=${value}` : line));
    } else {
      lines.push(`${key}=${value}`);
    }
  }
  writeFileSync(envPath, `${lines.join("\n")}\n`);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
