# Intellichain — "Total Mastery" Upgrade Design

Date: 2026-10-23
Status: approved to proceed (owner opted out of Q&A)

## Intent & Why

Intellichain is a Chainlink Functions + NFT gift-claiming system (Sepolia today):
a user replies to a tweet with a claim code and wallet; an ElizaOS agent parses
it; a Chainlink Functions DON verifies the code against Supabase; the deployed
`GetGift` contract mints an ERC-721 gift NFT to the wallet.

The repo currently keeps its maturity stages on separate branches
(`testing` = unit tests, `Script` = deploy/interact scripts, `Agent` = ElizaOS
part) while `main` holds only the contract. The goal of this upgrade is a
portfolio-grade `main` branch that demonstrates mastery of the whole pipeline:
a hardened contract, a complete test suite, working scripts, clean tooling,
CI, and honest documentation — without touching the other branches (they stay
as historical stage snapshots).

## Goals

1. **Consolidate** — bring `contract/test` (from `testing`) and
   `contract/script` (from `Script`) onto `main`; drop committed coverage
   output; keep git history via `git checkout <ref> --`.
2. **Harden `GetGift.sol`** (behavior-preserving where it matters, fixing real defects):
   - **Double-claim race** (HIGH): `sendRequest` only *checks* `giftCodeRedeemed`;
     the flag is set later in `fulfillRequest`. Two requests with the same code
     can both be in flight and both mint. Fix: **claim the code atomically at
     request time**, release it again in `fulfillRequest` if fulfillment fails
     (error) or the code is genuinely unknown ("not found").
   - **Lost/orphaned fulfillment** (MED): only one Chainlink request at a time
     is supportable (`s_lastRequestId` guard); concurrent requests silently
     orphan earlier ones and burn LINK. Fix: an explicit "one request in
     flight" invariant — `sendRequest` reverts while a previous request has
     not been fulfilled yet.
   - **Allowlist lockout** (MED): allowlist members may invite other members
     (by design) but nothing prevents the *last* member from being removed,
     bricking all admin paths. Fix: track the allowlisted count; revert on
     removing the last remaining member.
   - **`removeFromAllowList` can only remove `msg.sender`** — an admin cannot
     remove someone they invited. Fix: take an address parameter.
   - **Unknown gift type mints an empty-metadata token** (MED): Supabase may
     return a `gift_name` that has no mapping in `giftToTokenUri`; the mint
     ignores `tokenUri == ""`. Fix: revert and release the code so the admin
     can `addGift` the missing type; the claimant can retry without loss.
   - **Fail fast before burning LINK**: validate `args` (at least one code,
     non-empty string) before sending a paid request.
   - **Observability**: `giftCodeRedeemed` / `allowList` / `giftToTokenUri`
     become public mappings (auto getters), plus `GiftRedeemed`,
     `GiftCodeReleased`, `GiftAdded`, `AllowListAdded`, `AllowListRemoved`
     events for off-chain indexing.
   - Replace bare `require` strings with **custom errors**; complete NatSpec.
   - Keep every semantic of the Chainlink interaction exactly as-is (SOURCE
     JS, request encoding, `handleOracleFulfillment` path) — do not relitigate
     Chainlink's example contract response handling.
3. **Test suite mastery** — keep the existing 6 suites (adapted to new errors
   and the parameterized removal), and add TDD tests for every new: race fix,
   in-flight invariant, count-based lockout, unknown gift type release,
   arg validation, and all events/getters.
4. **Tooling & CI**
   - `.github/workflows/ci.yml`: format check → build → unit tests (no network
     needed) on push/PR.
   - `.env.example` with placeholder values (replaces `envexample.sh`, which
     leaks-looking truncated keys); Makefile `.env` include keeps submodules.
   - `foundry.toml`: remove the misleading `[profile.test] src='test'` profile;
     keep a working coverage profile.
   - Makefile: decouple plain `forge test`/`build`/`fmt` from
     `SEPOLIA_RPC_URL` (today `make test` demands a live RPC key); keep fork/tx
     targets as-is.
   - `contract/.gitignore`: never commit `coverage-report/`.
5. **Docs** — rewrite `README.md`: system architecture, repo layout (incl.
   where the stage branches live), env-var table, quickstart
   (build/test/deploy/interact/coverage), corrected Docker instructions
   (the current ones are broken: `intellichain:latest.` missing space,
   `/intellichain` typo), security notes about the "not audited" banner.

## Non-goals / Anti-goals

- Do NOT merge or modify the `Agent` branch's ElizaOS code here — reference it in the README.
- Do NOT deploy anything or rotate real keys.
- Do NOT change the Chainlink request/response protocol semantics.
- Anti-goal: breaking the existing passing tests when a change is purely incremental.
- Anti-goal: exhaustive audit-grade rework beyond the defects above (the
  "EXAMPLE / UN-AUDITED" banner stays prominent).

## Constraints

- Solidity `^0.8.19` / solc `0.8.20`, Foundry + git submodules (forge-std,
  openzeppelin-contracts, chainlink) via `contract/.gitmodules`. OpenZeppelin
  v5 is current for the pinned submodule; keep `ERC721URIStorage +
  ReentrancyGuard` imports as-is.
- All work on **local `main`** with clean, logical commits; nothing is pushed.
- Tests must pass fully (`forge test`) with **no live RPC** required.

## Builder's Calls Already Made Here (mine)

- Error style switches from strings to **custom errors**; existing tests are
  updated alongside (cleaner + gas-cheaper; matches Foundry/Cyfrin best practice).
- Unknown gift type ⇒ **revert + release code** (not "mint empty token").
- `removeFromAllowList(address)` **with last-admin protection** (count-based).
- In-flight serialization reuses the existing single `s_lastRequestId`-keyed
  invariant rather than a request-ID list (keeps the Chainlink client pattern
  intact).
- `envexample.sh` deleted in favor of hand-usable `.env.example`.

## Hand-off

Implementation plan lives right after this in the session log; each contract
change goes through TDD: failing test first, minimal fix, full suite green,
then commit.
