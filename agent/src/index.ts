import { DirectClient } from "@elizaos/client-direct";
import {
  AgentRuntime,
  elizaLogger,
  settings,
  stringToUuid,
  type Character,
} from "@elizaos/core";
import { bootstrapPlugin } from "@elizaos/plugin-bootstrap";
import { createNodePlugin } from "@elizaos/plugin-node";
import fs from "fs";
import net from "net";
import path from "path";
import { fileURLToPath } from "url";
import { initializeDbCache } from "./cache/index.ts";
import { buildCharacter, selectModelProvider } from "./character.ts";
import { loadEnv, type Env } from "./core/env.js";
import { GetGiftClient, makeClients } from "./core/claim.js";
import { privateKeyToAccount } from "viem/accounts";
import { makeMonitorDeps } from "./monitor-wiring.ts";
import { startChat } from "./chat/index.ts";
import { initializeClients } from "./clients/index.ts";
import {
  getTokenForProvider,
  loadCharacters,
  parseArguments,
} from "./config/index.ts";
import { initializeDatabase } from "./database/index.ts";
import { wireClaimStack } from "./custom-plugins/registry.ts";

/*
 * Boot adapted from the elizaOS starter v0.1.1 (MIT) — src/index.ts. Delta:
 * - config is loaded and validated FIRST (loadEnv; fail-fast), then threaded
 *   into the character and the chain clients;
 * - the claim stack (relayer wallet + live fulfill-inflight MonitorDeps) is
 *   built once per agent and published through wireClaimStack BEFORE any
 *   client can surface a claim;
 * - no evmPlugin: the agent talks to GetGift via its own core module.
 */

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let nodePlugin: any | undefined;

export function createAgent(
  character: Character,
  db: any,
  cache: any,
  token: string
) {
  elizaLogger.success(
    elizaLogger.successesTitle,
    "Creating runtime for character",
    character.name,
  );

  nodePlugin ??= createNodePlugin();

  return new AgentRuntime({
    databaseAdapter: db,
    token,
    modelProvider: character.modelProvider,
    evaluators: [],
    character,
    plugins: [bootstrapPlugin, nodePlugin],
    providers: [],
    actions: [],
    services: [],
    managers: [],
    cacheManager: cache,
  });
}

async function startAgent(
  character: Character,
  env: Env,
  directClient: DirectClient
) {
  try {
    character.id ??= stringToUuid(character.name);
    character.username ??= character.name;

    const token = getTokenForProvider(character.modelProvider, character);
    console.log(`Token provider is ${character.modelProvider}`);
    if (!token) {
      throw new Error("Token not found for provider");
    }
    const dataDir = path.join(__dirname, "../data");

    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }

    const db = initializeDatabase(dataDir);

    await db.init();

    const cache = initializeDbCache(character, db);
    const runtime = createAgent(character, db, cache, token);

    await runtime.initialize();

    // Publish the claim stack BEFORE any client can surface a claim. The
    // relayer wallet signs sendRequest; monitor deps watch + poll GetGift.
    const { walletClient, publicClient } = makeClients(env);
    wireClaimStack({
      claimClient: new GetGiftClient({ env, walletClient, publicClient }),
      monitor: makeMonitorDeps(env, publicClient),
      env,
    });

    runtime.clients = await initializeClients(character, runtime);

    directClient.registerAgent(runtime);

    // report to console
    elizaLogger.debug(`Started ${character.name} as ${runtime.agentId}`);

    return runtime;
  } catch (error) {
    elizaLogger.error(
      `Error starting agent for character ${character.name}:`,
      error,
    );
    console.error(error);
    throw error;
  }
}

const checkPortAvailable = (port: number): Promise<boolean> => {
  return new Promise((resolve) => {
    const server = net.createServer();

    server.once("error", (err: NodeJS.ErrnoException) => {
      if (err.code === "EADDRINUSE") {
        resolve(false);
      }
    });

    server.once("listening", () => {
      server.close();
      resolve(true);
    });

    server.listen(port);
  });
};

const startAgents = async () => {
  const directClient = new DirectClient();
  const env = loadEnv();
  console.log(
    `Config loaded for ${env.chain.network.name} (relayer ${privateKeyToAccount(env.relayer.privateKey).address})`,
  );

  const selection = selectModelProvider(env);
  if (selection.cloudOnOpenAI) {
    console.log(
      "CLOUD rides the OpenAI-compatible provider; set OPENAI_API_URL in agent/.env for a custom endpoint",
    );
  }

  let serverPort = parseInt(settings.SERVER_PORT || "3000");
  const args = parseArguments();

  let charactersArg = args.characters || args.character;
  let characters = [buildCharacter(env)];

  console.log("charactersArg", charactersArg);
  if (charactersArg) {
    characters = await loadCharacters(charactersArg);
  }
  console.log("characters", characters);
  try {
    for (const character of characters) {
      await startAgent(character, env, directClient as DirectClient);
    }
  } catch (error) {
    elizaLogger.error("Error starting agents:", error);
  }

  while (!(await checkPortAvailable(serverPort))) {
    elizaLogger.warn(`Port ${serverPort} is in use, trying ${serverPort + 1}`);
    serverPort++;
  }

  // upload some agent functionality into directClient
  directClient.startAgent = async (character: Character) => {
    // wrap it so we don't have to inject directClient later
    return startAgent(character, env, directClient);
  };

  directClient.start(serverPort);

  if (serverPort !== parseInt(settings.SERVER_PORT || "3000")) {
    elizaLogger.log(`Server started on alternate port ${serverPort}`);
  }

  const isDaemonProcess = process.env.DAEMON_PROCESS === "true";
  if (!isDaemonProcess) {
    elizaLogger.log("Chat started. Type 'exit' to quit.");
    const chat = startChat(characters);
    chat();
  }
};

startAgents().catch((error) => {
  elizaLogger.error("Unhandled error in startAgents:", error);
  process.exit(1);
});
