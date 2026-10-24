# Intellichain Agent Evolution Design

Date: 2026-10-23
Status: approved (owner chose: repo removed from GitHub → scaffold from public template inside Intellichain; private values via `.env`)

## Intent & Why

The AI-agent stage lived in a private repo `Eliza-Chainlink-Functions`
(now removed from GitHub). Its architecture (and a public template twin)
shows: elizaOS v0.1.7 runtime (+ `agent-twitter-client`), one custom plugin
(`getGiftPlugin` → `getGift` action), a viem wallet provider, a manual
`uploadToDON.js` secrets flow, and a **shallow integration** — the agent
fires `sendRequest` and reports a tx hash without knowing the outcome.

We rebuild and evolve it as `agent/` inside the Intellichain repo so the
agent and the hardened `GetGift` contract finally speak to each other:
contract v2 has public getters (`giftCodeRedeemed`), custom errors, and
`GiftRedeemed` / `GiftCodeReleased` events exactly designed for this.

## Goals

1. **Config never committed**: every private value (RPC URL, relayer key,
   sub id, slot/version, Twitter creds, model keys) comes from `.env`,
   loaded + validated by **zod** at boot with actionable error messages.
   `.env.example` carries placeholders only. `donSecretsInfo.txt` stays out
   of git.
2. **Sepolia by default** (was hardcoded Fuji + `// dev TODO`): network
   presets mirror `contract/script/utility/NetworkConfigLibrary.sol`
   (router `0xb83E…`, DON `fun-ethereum-sepolia-1`); agent env selects
   network + `CONTRACT_ADDRESS`, `FUNCTIONS_SUBSCRIPTION_ID`,
   `FUNCTIONS_SLOT_ID`, `FUNCTIONS_SECRET_VERSION`.
3. **Deterministic claim extraction first**: regex + checksum validation
   (viem `getAddress`) for {address, code}; LLM fallback only when regex
   fails — instead of the template's LLM-only `generateObjectDeprecated`
   path (burned tokens; no validation).
   > **Fulfilled as clarify-ask — implemented ruling (review fix pass
   > 2026-10-24):** the LLM fallback was NOT reinstated. When the regex
   > path is inexact, the agent asks the user for the missing piece via
   > `clarifyReply` (candidate-aware, zero tokens). LLM object generation
   > is reserved for elizaOS's own message-response pipeline (who to reply
   > to / when the action applies), never for claim DATA.
4. **Contract-aware claim error surface**: decode GetGift custom errors
   (`CodeAlreadyRedeemed`, `RequestAlreadyInFlight`, `CodeAlreadyRedeemed`,
   `InvalidGiftCode`, `InvalidRecipient`, `CallerNotAllowlisted`) into
   user-facing text instead of raw revert blobs.
5. **Fulfillment monitoring (the big UX gap)**: after `sendRequest` receipt,
   a monitor (viem `watchContractEvent` + polling fallback) reports
   **minted** (`GiftRedeemed` w/ tokenId), **released** (`GiftCodeReleased`
   → tell user to retry), or **timeout** — so the agent can actually confirm
   a gift, not just a transaction.
6. **Ops**: DON secrets upload as a proper script + Makefile target that
   writes `FUNCTIONS_SLOT_ID` / `FUNCTIONS_SECRET_VERSION` into `.env`
   (with expiry reminder) — the 24-hour DON secret expiry was previously
   silent manual toil.
7. **Engineering hygiene**: TypeScript strict, vitest unit tests for the
   pure logic (extraction, env validation, error mapping, monitor state),
   CI job in the existing workflow, provenance headers on vendored files.
8. **Twitter layer**: vendor the template's `light_twitter-clients`
   (MIT) verbatim behind a thin boundary so the claim pipeline doesn't
   depend on Twitter internals; a Phase-B port to elizaOS v1+ can swap it.

## Non-goals (Phase A)

- No elizaOS v1/v2 port (deferred Phase B), no redesign of Twitter auth,
  no Supabase schema changes, no production audit.
- Agent never holds donor user funds; the relayer wallet only pays
  `sendRequest` gas + LINK subscription usage.

## Constraints

- Node ≥ 22, pnpm; `@elizaos/*@0.1.7` per template; `@chainlink/functions-toolkit`
  (^0.3.2, ethers v5 API inside that script only); viem for the app-side.
- Tests must run offline (no Twitter, no RPC, no model keys).
- No real keys anywhere in the repo; CI never uses Twitter/model secrets.

## Design decisions already made (my calls)

- Place at `agent/` (pnpm workspace of one → standard npm layout, no
  monorepo tooling overhead).
- Keep elizaOS v0.1.7 template API for the plugin; wrap our logic in
  pure modules the plugin calls, so the eventual v1/v2 port touches only
  the glue, not the logic.
- `agent/src/networks.ts` duplicates DON router/donId constants (they are
  public addresses); duplication documented so contract repo stays the
  source of truth for deployment, agent repo for runtime constants.
- Reasoning-model provider: whatever `CLOUD`/`OPENAI_API_KEY` resolves to
  in v0.1.7 semantics; documented in `.env.example`.

## Hand-off

Implementation follows in `docs/superpowers/plans/2026-10-23-agent-evolution.md`.
