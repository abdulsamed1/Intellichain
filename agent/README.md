# @intellichain/agent

The AI-agent stage of Intellichain: an [elizaOS](https://github.com/elizaOS/eliza)
(0.1.7) agent that watches Twitter for gift-claim replies, validates them
**deterministically**, drives the hardened `GetGift` Chainlink Functions
contract (`../contract/`) per-user, and monitors fulfillment so it can tell
the user the truth: **minted**, **released (retry anytime)**, or **not
finished (still watching)**.

Status: **offline-tested** — the vitest suite and CI need **zero** secrets
(no Twitter login, no RPC, no model key, no DON secrets). Everything private
is supplied by the operator via `agent/.env` only. Nothing is ever printed
or committed.

## Architecture

```
tweet mention ──▶ vendor'd twitter client (interactions.ts)
                     │  elizaOS message pipeline (who/when = LLM)
                     ▼
               GET_GIFT action  ── data decisions are DETERMINISTIC ──
                     │            extractClaim(): EIP-55 address + masked code
                     │  inexact  → clarifyReply() (asks for the missing piece)
                     ▼
             GetGiftClient.claim(code, address)
                     │  cheap local mirror of contract checks, then sendRequest()
                     │  contract errors speak verbatim via mapContractError
                     ▼   submitted(txHash)
             reply in-thread: code + tx + "I'll follow up here"
                     │  fire-and-forget (never blocks the loop)
                     ▼
             trackFulfillment(deps) — GiftRedeemed/GiftCodeReleased events
             + giftCodeRedeemed poll (first-settled wins)
                     ▼
             outcomeReply(): minted 🎉 / released ↔ retry / still-watching ⏳
```

Key wiring: chain clients are constructed **once at boot**
(`src/core/claim.ts::makeClients`) and published through the claim-stack
registry (`src/custom-plugins/registry.ts::wireClaimStack`). The action
reads them per invocation; unwired access throws an error that names the
boot step instead of dereferencing null.

## Quickstart

Prerequisites: Node `>=22`, pnpm `10.34.8` (see `packageManager`), a funded
relayer wallet, and the contract deployed (see `../contract/README.md`).

1. **Deploy the contract first** — from `contract/`: `make deploy`. Copy the
   resulting address into `CONTRACT_ADDRESS`.
2. **Prepare the chain side** — the relayer wallet must be
   [allowlisted](../contract/README.md#allowlist) on `GetGift`, funded with
   Sepolia ETH, with LINK approved into the Functions subscription.
3. **Configure the agent**
   ```bash
   cd agent
   cp .env.example .env
   $EDITOR .env     # fill EVERY required row; see the tables below
   ```
4. **Upload DON-hosted secrets** (writes `FUNCTIONS_SLOT_ID` /
   `FUNCTIONS_SECRET_VERSION` back into `.env`; never the key itself):
   ```bash
   make don-secrets
   ```
5. **Verify offline, then start**
   ```bash
   make check     # typecheck + 48-test offline suite
   make start     # boots GiftPilot: direct chat + twitter watcher
   ```

The agent talks to Sepolia (+ local Anvil for development). For Anvil
exercises run the Anvil fork per the contract README and point
`SEPOLIA_RPC_URL` at the fork's HTTP endpoint.

## Environment surface (`agent/.env` — the only source of truth)

| Group | Variables | Required | Notes |
|---|---|---|---|
| Network | `SEPOLIA_RPC_URL` | ✓ | JSON-RPC (Alchemy/Infura free tier) |
| Network | `MAINNET_RPC_URL` | – | archive/mainnet fork context |
| Relayer | `EVM_PRIVATE_KEY` | ✓ | dedicated key; allowlisted + funded |
| Contract | `CONTRACT_ADDRESS` | ✓ | checksummed GetGift address |
| Functions | `FUNCTIONS_SUBSCRIPTION_ID` | ✓ | billing subscription (owner: you) |
| Functions | `FUNCTIONS_SLOT_ID`, `FUNCTIONS_SECRET_VERSION` | ✓ (post step 4) | written back by `make don-secrets` |
| Fulfillment | `FULFILLMENT_TICK_MS`, `FULFILLMENT_MAX_TICKS` | – | poll cadence/ceiling; defaults 15000 ms × 60 (≈15 min) |
| DON upload | `SUPABASE_API_KEY` | (only for step 4) | used by the upload script only; never leaves the box |
| Twitter | `TWITTER_USERNAME`, `TWITTER_EMAIL`, `TWITTER_PASSWORD` | ✓ (twitter clients) | app account, 2FA-readiness |
| Twitter | `TWITTER_2FA_SECRET` | – | TOTP base32 secret |
| Twitter | `TWITTER_TARGET_USERS` | – | accounts to watch; defaults to mentions only |
| Twitter | `TWITTER_SEARCH_ENABLE` | – | proactive search (more API surface) |
| Model | `OPENAI_API_KEY` \> `OPENROUTER_API_KEY` \> `CLOUD` | ✓ (one) | precedence; see below |
| Model | `MODEL_SMALL` / `MODEL_MEDIUM` / `MODEL_LARGE` | – | per-size model pinning |
| Runtime | `SERVER_PORT` | – | direct-client API port (default 3000) |

`loadEnv()` validates EVERYTHING up-front (zod per-field schemas; errors
name the offending variable) — the agent refuses to boot half-configured.

### Model key precedence

1. `OPENAI_API_KEY` → provider `OPENAI`.
2. `OPENROUTER_API_KEY` → provider `OPENROUTER`.
3. `CLOUD` alone → provider `OPENAI`, with the cloud key riding the
   OpenAI-compatible surface. elizaOS 0.1.7 has **no CLOUD provider**; its
   OPENAI surface reads `OPENAI_API_URL` **straight from `process.env`** —
   so to point CLOUD at a custom (non-OpenAI) endpoint, add:
   ```env
   OPENAI_API_URL=https://your-openai-compatible-endpoint/v1
   ```
   (Trustworthy providers that speak the OpenAI Chat Completions dialect,
   e.g. aggregator endpoints, work as-is.)
4. No key → the boot fails with the precedence message.

The chosen keys are injected into the **in-memory character clone** at
runtime — never into files, never into logs (the private key's *address*
is logged as public boot metadata; the key itself never).

## The claim flow in one screen

- A tweet carrying a code + a `0x…`-address is extracted **deterministically**
  (EIP-55 checksum-validated, code mask-matched) — no LLM object generation
  anywhere in the claim path. elizaOS's model only decides *when* the
  action applies.
- Inexact message → the user is asked for exactly the missing piece.
- Rejected claim → the contract's own error text, wrapped politely
  (`mapContractError` mirrors: used code, not allowlisted, in-flight
  collision, …).
- Submitted → in-thread confirmation with the tx hash, then the fulfillment
  watcher reports the settled outcome (minted / released / still-watching).
  The watcher polls `giftCodeRedeemed` post-shield, so poll-false reliably
  means the code was released (retry anytime).

## Vendored code & licenses

`src/twitter/` is vendored from the [elizaOS starter](https://github.com/elizaOS/eliza-starter)
v0.1.1 (**MIT**) — `light_twitter-clients/{base,environment,index,
interactions,post,utils}` — plus adapted support files (boot/config/chat/
database/cache/clients). Each file carries a provenance header listing its
adaptations (behavior-preserving strictness pins only; `environment.ts` was
wired to the `.env` pipeline as the single source of truth).

## Make targets

| Target | What it does |
|---|---|
| `make typecheck` | `tsc --noEmit` over the agent |
| `make test` | offline vitest suite (5 files / 48 tests) |
| `make check` | both (the CI gate) |
| `make don-secrets` | encrypt + upload DON secrets; writes slot/version into `.env` |
| `make start` | start the runtime from `.env` |
| `make help` | list targets |

## CI

`.github/workflows/ci.yml` runs the contract job **and** an agent job
(pnpm frozen-lockfile install → `pnpm typecheck` → `pnpm test`) — both are
fully offline and require no repository secrets.
