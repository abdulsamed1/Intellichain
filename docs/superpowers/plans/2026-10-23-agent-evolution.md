# Intellichain Agent Evolution — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the AI-agent stage as `agent/` inside Intellichain with env-driven config, deterministic claim extraction, contract-aware error mapping, fulfillment monitoring, DON-secrets ops, tests, and CI.

**Architecture:** elizaOS v0.1.7 template layout retained (character.json-driven runtime, custom plugin, twitter client boundary). All business logic lives in pure modules (`env`, `extraction`, `claim`, `monitor`, `networks`) under `agent/src/core/` that the plugin glue calls — the future v1 port replaces only glue.

**Tech Stack:** TypeScript (strict, ESM), pnpm, Node ≥ 22, zod, viem (app-side), ethers v5 (`@chainlink/functions-toolkit` scripts only), vitest.

**Spec:** `docs/superpowers/specs/2026-10-23-agent-evolution-design.md`

## Global Constraints

- Private values ONLY via `.env` (gitignored); `.env.example` placeholders; CI touches neither Twitter nor model keys.
- Tests offline; `pnpm clean && pnpm typecheck && pnpm test` green before each commit.
- Sepolia defaults; contract custom-error strings (e.g. "CodeAlreadyRedeemed()") required decoded, not raw.
- Vendored `src/twitter/*` keeps template provenance header; unmodified except imports.

## Review Focus

- A tweet containing TWO addresses / TWO codes must never mint the wrong pair — pinned by `extraction` tests (Task 3).
- Missing/invalid env must fail at BOOT with the variable named, never mid-claim — pinned by `env` tests (Task 2).
- A reverted sendRequest (e.g. `CodeAlreadyRedeemed()`) must surface as human text — pinned by claim error-mapping tests (Task 4).
- Monitor must not report "minted" from a released code: `GiftCodeReleased` outcome wins over timeout ambiguity — pinned by monitor state tests (Task 5).
- Secrets script must never print or write the raw key — pinned by review + structure (Task 6).

---

### Task 1: Scaffold `agent/` package

**Files:** Create `agent/package.json`, `agent/tsconfig.json`, `agent/vitest.config.ts`, `agent/.env.example`, `agent/.gitignore`, `agent/README.md`; root `.gitignore` additions.

- [ ] **Step 1:** package.json: name `@intellichain/agent`, engines node >=22, scripts: `start`, `typecheck` (`tsc --noEmit`), `test` (`vitest run`), `lint-unused` optional; deps per template (minus bogus `fs`/`net`/`path`/`url`/`readline`/gen); devDeps: typescript 5.6, vitest, ts-node? (no — vitest only), tsx? (start via ts-node/esm per template).
- [ ] **Step 2:** tsconfig strict + NodeNext; vitest config default paths.
- [ ] **Step 3:** agent/.gitignore: `node_modules/ data/ dist/ .env donSecretsInfo.txt`.
- [ ] **Step 4:** `agent/.env.example` — full private-value surface with placeholders + comments (SEPOLIA_RPC_URL, MAINNET_RPC_URL, EVM_PRIVATE_KEY, CONTRACT_ADDRESS, FUNCTIONS_SUBSCRIPTION_ID, FUNCTIONS_SLOT_ID, FUNCTIONS_SECRET_VERSION, SUPABASE_API_KEY upload-only, TWITTER_USERNAME/EMAIL/PASSWORD, TWITTER_TARGET_USERS, TWITTER_SEARCH_ENABLE, model keys CLOUD/OPENAI_API_KEY/OPENROUTER_API_KEY + MODEL_PROVIDER overrides, SERVER_PORT, POST/INTERVAL knobs).
- [ ] **Step 5:** verify toolchain: `corepack enable pnpm || npm i -g pnpm`; `pnpm -v`. If node 22 missing → install via apt/nodesource. Record any environment ruling.
- [ ] **Step 6:** `pnpm typecheck && pnpm test` on empty tree → green (0 tests).
- [ ] **Step 7:** Commit `feat(agent): scaffold agent package (env-first, offline tests)`.

### Task 2: Env validation + networks module

**Files:** Create `agent/src/core/env.ts`, `agent/src/core/networks.ts`; Test `agent/test/env.test.ts`.

**Interfaces:**
- Produces: `loadEnv(): Env` (zod-validated, throws `EnvError(variableName-mentioning)`), `NETWORKS: Record<'sepolia', NetworkPreset>` where `NetworkPreset { chainId, router, donId, callbackGasLimit; name }` mirroring NetworkConfigLibrary sepolia + fuji entries.

- [ ] **Step 1:** Write failing tests: sepolia preset matches contract values (router 0xb83E…38D0, donId 'fun-ethereum-sepolia-1', gas 250_000 per network config lib... — oh wait, contract constant uses 300_000; the LIBRARY says 250_000 for sepolia. Ruling: duplicate the make-up? Check contract final: CALLBACK_GAS_LIMIT constant = 300_000. NetworkConfigLibrary sepolia 250_000. MISMATCH in the contract repo itself (pre-existing, Script branch). Ledger ruling: agent validates nothing about callback gas; the CONTRACT enforces its own 300_000; agent's preset keeps 250_000 field but it's unused for sendRequest — actually simplest: agent preset doesn't carry callbackGasLimit at all (contract owns it). Networks: { chainId 11155111, router, donId, linkToken } — remove gasLimit from agent.); env missing CONTRACT_ADDRESS → EnvError naming it; FUNCTIONS_SUBSCRIPTION_ID numeric coercion; TWITTER_TARGET_USERS string[] coercion.
- [ ] **Step 2:** Run → RED (missing modules).
- [ ] **Step 3:** Implement env.ts (zod schemas: `commonEnv`, optional twitterEnv, env-driven `loadEnv({ source: import.meta.env ?? process.env })` — injectable source for tests) + networks.ts.
- [ ] **Step 4:** Run → GREEN; commit `feat(agent): zod env loader + sepolia/fuji network presets`.

### Task 3: Deterministic claim extraction

**Files:** Create `agent/src/core/extraction.ts`; Test `agent/test/extraction.test.ts`.

**Interfaces:**
- Produces: `extractClaim(text: string): ClaimAttempt` where `ClaimAttempt = { exact: true, address, code } | { exact: false, candidates?: Partial<Claim>, hint: string }`; helpers `looksLikeEvmAddress(s)`, `normalizeAddress(s): Result` (viem getAddress checksum; lowercase fallback when all-lowercase input). Regex: address `0x[a-fA-F0-9]{40}`; code: configurable charset (default `[A-Za-z0-9_-]{5,32}`), NOT matching a portion of an address (guard: candidate boundaries).

- [ ] **Step 1:** RED tests: normal tweet ("my wallet is 0x…d4e5 and code Xyzzy12"), address-embedded-in-longer-hex exclusion (0x + 64 hex → NOT an address), lowercase address normalization, all-uppercase code kept verbatim, two-address-two-code confusing tweet → `{exact:false}` + candidates, no code found, empty text.
- [ ] **Step 2:** Run RED; **Step 3:** implement; **Step 4:** GREEN; **Step 5:** commit `feat(agent): deterministic claim extraction with checksum validation`.

### Task 4: Claim module (contract client + error mapping)

**Files:** Create `agent/src/core/claim.ts`, `agent/src/core/contract-errors.ts` *(implemented ruling: `contract-errors` merged into `claim.ts` — one cohesive module beat an extra indirection; the error text table lives at the top of `claim.ts`)*; artifact copied `agent/src/core/artifacts/GetGift.json` (fresh from `contract/out/GetGift.sol/GetGift.json` build — source of truth now the real contract); Test `agent/test/claim.test.ts`.

**Interfaces:**
- Consumes Task 2 env/networks, Task 3 Claim.
- Produces: `class GetGiftClient { constructor(params: { env: Env, walletClient, publicClient }) ; claim(c: Claim): Promise<ClaimOutcome> }`; `ClaimOutcome = { kind: 'submitted', txHash } | { kind: 'rejected', text }`; `mapContractError(err): string` — knows every GetGift custom error (decode via viem `onRevertReason`/`decodedError` from ABI); `makeClients(env)` builds viem clients from env (no test needed beyond typecheck? test via mocked env — skip network in tests: expose clients as params).

- [ ] **Step 1:** RED tests (mock viem write): success → submitted+hash; each custom error → mapped text CODE_ALREADY_REDEEMED etc.; unknown revert → safe generic text; pre-claim Client-side guard: claim({address:"0x0…0"}) → rejected w/o RPC call (InvalidRecipient parity — agent-side mirror of contract checks).
- [ ] **Step 2:** RED; **Step 3:** implement (viem `getContract`, `write.sendRequest`, try/catch decodeCustomError via ABI); **Step 4:** GREEN suite GREEN; **Step 5:** commit `feat(agent): contract client with custom-error mapping (contract-aware agent)`.

### Task 5: Fulfillment monitor

**Files:** Create `agent/src/core/monitor.ts`; Test `agent/test/monitor.test.ts`.

**Interfaces:**
- Consumes publicClient + logs of contract.
- Produces: `trackFulfillment(args: { txHash?: `0x…`, code, recipient, fromBlock, timeoutMs, poll: WatchDeps }): Promise<TrackResult>`; `TrackResult = { kind:'minted', tokenId, giftType } | { kind:'released', reason:'error'|'unknown'|'wrong-type' } | { kind:'timeout' }`; watchContractEvent GiftRedeemed (filters recipient + code by args — nonindexed strings arrive in data) & GiftCodeReleased (args.code compare) events; prefer event receipt, fallback poll `giftCodeRedeemed(code)` + `Transfer` logs to recipient after claimed flag.

- [ ] **Step 1:** RED: emitted mint event → minted-with-tokenId; released event while waiting → released; no events + timeout → 'timeout'; released AFTER mint event arrived already → result stays minted (first-wins).
- [ ] **Step 2:** RED; **Step 3:** implement single Promise.race loop with injected `onEvent` (deps: `watchEvents` injected via object w/ `subscribe(method, fn): unsubscribe`, `readGiftCodeRedeemed(code)`, `sleep`), *deterministic and mock-friendly*; **Step 4:** GREEN; **Step 5:** commit `feat(agent): fulfillment tracker with minted/released/timeout outcomes`.

### Task 6: DON secrets ops + Makefile

**Files:** Create `agent/scripts/upload-don-secrets.ts` (ethers v5 needed by functions-toolkit; template `uploadToDON.js` modernized: env-driven router/donId/chains from Task 2 networks + slot arg write to .env); Create `agent/Makefile`; no tests (Script exception — config file class), ran once manually later by user.
- [ ] **Step 1:** Implement script: loads env (Task 2 loader re-used via tsx/ts-node), validates SEPOLIA_RPC_URL + EVM_PRIVATE_KEY + SUPABASE_API_KEY present; encodes via SecretsManager; uploads to default gateway URLs; on success APPEND/UPDATE `.env` lines `FUNCTIONS_SECRET_VERSION=<n>`, `FUNCTIONS_SLOT_ID=<0>` (never value of key); prints expiry minutes reminder.
- [ ] **Step 2:** agent/Makefile: `don-secrets`, `typecheck`, `test`, `start` (tsx src/index.ts w/ character arg), `build`.
- [ ] **Step 3:** dry-run validation locally: `make typecheck`; smoke-test the upload path mocked? (needs gateway + RPC — out of offline scope; mark manual). Commit `feat(agent): DON secrets upload writes .env, never prints secrets`.

### Task 7: Runtime wiring + vendored twitter layer

**Files:** Create `agent/src/core/index.ts` (exports), `agent/src/custom-plugins/getGift.ts` (plugin glue: action handler calls extraction → GetGiftClient.claim → trackFulfillment → callback text runs both outcomes; similes/examples updated), `agent/src/character.ts` (default character), `agent/src/index.ts` (boot: loadEnv → runtime → clients — adapted template; chat + direct client), `agent/src/clients/index.ts`; Vendor `agent/src/twitter/*` from `/tmp/opencode/eliza-gift/src/light_twitter-clients/*` + provenance header comment above first line of each file.
- [ ] **Step 1:** Copy vendored twitter files with headers.
- [ ] **Step 2:** Implement plugin glue + runtime files (adaption of template with our core modules; no LLM object-gen dependency — uses buildFunctionCallDetails only as FALLBACK when extraction `{exact:false}`).
- [ ] **Step 3:** Character default (name "GiftPilot" or similar, clients ['twitter','direct'], modelProvider env-driven).
- [ ] **Step 4:** `pnpm typecheck` + `pnpm test` green incl. glue module pure parts (no Twitter dependency in tests).
- [ ] **Step 5:** Bootstrap dep minimal: use `@elizaos/plugin-bootstrap` per template.
- [ ] **Step 6:** Commit `feat(agent): runtime wiring (plugin, runtime, character, vendored twitter client)`.

### Task 8: Tests + CI job + docs

**Files:** extend `.github/workflows/ci.yml` (agent job: pnpm, install --frozen-lockfile, typecheck, tests); agent README; root README layout/layout update; pnpm-lock committed.
- [ ] **Step 1:** ci.yml add `agent` job (setup-node 22 + corepack).
- [ ] **Step 2:** agent/README.md: run instructions, env table, phase-B roadmap, provenance + license note (template MIT).
- [ ] **Step 3:** root README: repo-layout tree + architecture flow updated (agent section pointer).
- [ ] **Step 4:** full: `pnpm typecheck && pnpm test` + contract suite still green; commits `ci(agent)` + `docs(agent)`.
