# Intellichain "Total Mastery" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the staged Intellichain repo onto a portfolio-grade `main`: hardened `GetGift` contract, full test suite, tooling, CI, and honest docs.

**Architecture:** Single Foundry project (`contract/`) + dev-toolchain Docker + GitHub Actions CI. Contract hardening is done incrementally — mechanical error-style conversion first, then one TDD task per defect, each ending in a full-suite-gate and a commit.

**Tech Stack:** Solidity 0.8.20 (Foundry 1.8.6), OpenZeppelin v5 + Chainlink Functions v1_0_0 (git submodules), Bash Makefile, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-23-total-mastery-design.md`

## Global Constraints

- solc `0.8.20`, `pragma solidity ^0.8.19`; Foundry; forge-std / openzeppelin-contracts / chainlink submodules only (no npm deps for the contract).
- Full suite green before every commit: `forge test` — **no live RPC required anywhere in the default path**.
- Keep Chainlink interop semantics exactly: `SOURCE` JS, `handleOracleFulfillment`, `onlyRouter`.
- All commits on local `main`; never push; existing remote branches untouched.
- Keep ERC-721 name/symbol `"Gift"/"GT"` and the three default ITEM mappings & IPFS URIs byte-identical.

## Review Focus

- **Same code claimed twice → exactly one NFT ever.** Pinned by `test_SendRequest_ClaimsCodeAtRequestTime` (Task 3) and `test_FulfillRequest_ReleasesCode*` (Task 4) — after release, re-claim must succeed and a *failed* fulfillment must never leave a code locked out.
- **LINK is never burned for a request thatCore cannot be fulfilled.** In-flight enforcement + pre-send validation pinned by `test_SendRequest_RevertIfRequestAlreadyInFlight`, `..._RevertIfEmptyGiftCode`, `..._RevertIfRecipientZero` (Task 3).
- **Admin cannot be bricked.** Last-remaining allowlist member removal must revert; pinned by `test_RemoveFromAllowList_CannotRemoveLastAdmin` (Task 5).
- **Unknown-but-valid DB gift must not mint empty metadata nor burn the code.** No mint + code released; pinned by `test_FulfillRequest_NoMintForUnknownGiftType` (Task 4).
- **Indexers can rebuild state.** `Transfer`/`GiftRedeemed`/`GiftCodeReleased`/`AllowList*`/`GiftAdded` events present; pinned by Task 4/5 event tests.

---

### Task 1: Baseline green on consolidated `main`

**Files:** none modified (verification task; fixes only if something blocks compilation/run).

**Interfaces:** Produces the working baseline all later tasks build on: `forge test` passes with the consolidated suites.

- [ ] **Step 1: Ensure submodules present** (`git submodule update --init --recursive --depth 1` — already running in background; verify `contract/lib/forge-std/src`, `lib/openzeppelin-contracts/contracts`, `lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol` exist)
- [ ] **Step 2: Run** `forge test` (from `contract/`). Expected: all consolidated tests pass (or the exact failures documented-only; fix baseline blockers only — e.g. unknown foundry.toml keys like `env_file`, missing `FunctionsV1EventsMock` remap).
- [ ] **Step 3:** If `env_file` is rejected by Foundry 1.8.6, remove that key (env vars arrive via Makefile `export`). 
- [ ] **Step 4: Commit** `test: consolidate unit tests from testing branch onto main` (tests + scripts already staged; include `aderyn.toml`, `contract/script/*`, spec doc).

### Task 2: Custom-errors conversion (mechanical, behavior-preserving)

**Files:**
- Modify: `contract/src/GetGift.sol` (errors, revert sites only)
- Modify: existing expectRevert sites in `contract/test/unit/GetGift.access.t.sol`, `GetGift.request.t.sol`, `GetGift.nft.t.sol`

**Interfaces:**
- Consumes: baseline suite (Task 1)
- Produces (used by Tasks 3–5, tests, README): error set in `GetGift`:
  `UnexpectedRequestID(bytes32)` (kept), `CallerNotAllowlisted()`, `CodeAlreadyRedeemed()`, `RequestAlreadyInFlight()(unused until Task 3 — define in Task 3 only, NOT here)`, `InvalidGiftCode()`, `InvalidRecipient()`(Task 3 only), `CannotRemoveLastAllowlisted()`, `AddressNotAllowlisted()`(Task 5 only), `InvalidGiftDefinition()`(Task 5 only).
  In Task 2 only: define `CallerNotAllowlisted()`, `CodeAlreadyRedeemed()`; leave everything else untouched.

- [ ] **Step 1:** Modify `GetGift.sol`: error decls `CallerNotAllowlisted()`, `CodeAlreadyRedeemed()`; revert sites: modifier `onlyAllowList` → `revert CallerNotAllowlisted()`; `sendRequest` "the code is redeemed" → `revert CodeAlreadyRedeemed()`. No other behavior changes.
- [ ] **Step 2:** Update test expects: `vm.expectRevert(GetGift.CallerNotAllowlisted.selector)` for the 4 allowlist-permission sites (access×5 incl. reuse, request×1) and `vm.expectRevert(GetGift.CodeAlreadyRedeemed.selector)` (nft×1, request×1). Import `GetGift` type where not imported.
- [ ] **Step 3: Run** `forge test -vvv`. Expected: PASS (all suites). If the legacy `expectRevert("OnlyRouterCanFulfill()")` string site fails under 1.8.6, convert it to `vm.expectRevert(abi.encodeWithSignature("OnlyRouterCanFulfill()"))` matching its parent error's data exactly.
- [ ] **Step 4: Commit** `refactor: custom errors for allowlist and code-redemption guards`

### Task 3: sendRequest hardening — fail fast, atomic claim, one-request invariant

**Files:**
- Modify: `contract/src/GetGift.sol`
- Test: `contract/test/unit/GetGift.request.t.sol` (new tests)

**Interfaces:**
- Consumes: Task 2 errors; utils base `GetGiftBase` (setUp, user/accounts, validGiftCode).
- Produces: new state `bool public requestIdInFlight;` (name: `requestIdInFlight` — read by UI/mocks in Task 4), errors `RequestAlreadyInFlight()`, `InvalidGiftCode()`, `InvalidRecipient()`; behavior: request claims its code atomically (sets `giftCodeRedeemed[giftCode] = true` in `sendRequest`), `requestIdInFlight = true` on send, and enforces args/recipient validity before the paid Chainlink call.

- [ ] **Step 1: Write failing tests** in `GetGift.request.t.sol`:
  - `test_SendRequest_ClaimsCodeAtRequestTime` — send valid request, do NOT fulfill; second `sendRequest` with same code from same user reverts `CodeAlreadyRedeemed` (the double-mint race).
  - `test_SendRequest_RevertIfRequestAlreadyInFlight` — send valid req, then a *different*-code request reverts `RequestAlreadyInFlight`.
  - `test_SendRequest_RevertIfEmptyGiftCode` — args[0] = `""` → `InvalidGiftCode`.
  - `test_SendRequest_RevertIfRecipientZero` — userAddr zero → `InvalidRecipient`.
- [ ] **Step 2: Run** `forge test --match-contract GetGiftRequestTest -vvv`. Expected: 4 FAIL.
- [ ] **Step 3: Implement in `sendRequest`** (top of body, in this order): `if (requestIdInFlight) revert RequestAlreadyInFlight();` → `if (args.length != 1) revert InvalidGiftCode();` (note: keep `req.setArgs(args)` semantics; args length 1 is the protocol assumption — the JS indexes `args[0]`) → `if (bytes(args[0]).length == 0) revert InvalidGiftCode();` → `if (userAddr == address(0)) revert InvalidRecipient();` → `if (giftCodeRedeemed[giftCode]) revert CodeAlreadyRedeemed();` → `giftCodeRedeemed[giftCode] = true;` → `requestIdInFlight = true;` then existing request code. Remove the old comment-only duplicate check & the old mid-function positioning.
- [ ] **Step 4: Run full suite.** Expected: PASS (existing fulfillment tests fulfill between sends → `requestIdInFlight` cleared).
- [ ] **Step 5: Commit** `fix(contract): atomic code claim, one-request invariant, fail-fast validation`

### Task 4: fulfillRequest hardening — release paths, events, hygiene

**Files:**
- Modify: `contract/src/GetGift.sol`
- Test: `contract/test/unit/GetGift.fulfillment.t.sol` (new tests)

**Interfaces:**
- Consumes: Task 3 (`requestIdInFlight` cleared on fulfillment).
- Produces: events `GiftRedeemed(bytes32 indexed requestId, address indexed recipient, string giftCode, string giftName, uint256 indexed tokenId)` and `GiftCodeReleased(string giftCode)`; behavior: on *any* non-mint outcome (err non-empty, "not found", unknown gift type) → `giftCodeRedeemed[giftCode] = false` + `emit GiftCodeReleased(giftCode)`, still no throw; mint path emits `GiftRedeemed`; `reqIdToAddr`/`reqIdToGiftCode` deleted after use in every path.

- [ ] **Step 1: Write failing tests** in `GetGift.fulfillment.t.sol`:
  - `test_FulfillRequest_ReleasesCodeOnError` — fulfill with err → `sendRequest` same code succeeds again.
  - `test_FulfillRequest_ReleasesCodeIfNotFound` — fulfill response `abi.encode("not found")` → no mint (`assertEq(getGift.tokenId(), 0)`) and same-code re-request succeeds.
  - `test_FulfillRequest_NoMintForUnknownGiftType` — response `abi.encode("mystery gift")` (not in `giftToTokenUri`) → no mint, code released (re-request succeeds).
  - `test_FulfillRequest_EmitsGiftRedeemed` — `vm.expectEmit` the indexed `GiftRedeemed(requestId, user, validGiftCode, "100 discount", expectedTokenId)`.
  - `test_FulfillRequest_EmitsGiftCodeReleased` — err case emits `GiftCodeReleased(validGiftCode)`.
- [ ] **Step 2: Run** `--match-contract GetGiftFulfillmentTest -vvv`. Expected: new 5 FAIL.
- [ ] **Step 3: Implement** in `fulfillRequest` after the `UnexpectedRequestID` guard: clear `requestIdInFlight = false` first; keep `s_lastResponse/s_lastError` + `emit Response` as-is. Add internal helper `function _releaseGiftCode(string memory giftCode) internal { giftCodeRedeemed[giftCode] = false; emit GiftCodeReleased(giftCode); }`. Structure the outcomes: read `giftCode` (from `reqIdToGiftCode`), then `err.length != 0` → `_releaseGiftCode(giftCode); return;` → `keccak256(response) == keccak256(abi.encode("not found"))` → `_releaseGiftCode(giftCode); return;` → else decode `giftType`, lookup `tokenUri` → `if (bytes(tokenUri).length == 0)` → `_releaseGiftCode(giftCode); return;` (no mint, no revert) → else `safeMint` + `emit GiftRedeemed(requestId, userAddr, giftCode, giftType, theMintedTokenId)`. In EVERY final path (all four), `delete reqIdToAddr[requestId]; delete reqIdToGiftCode[requestId];` (safeMint path reads `userAddr` before the deletes; make `safeMint` return the minted id: `function safeMint(address to, string memory uri) internal nonReentrant returns (uint256)`).
- [ ] **Step 4: Run full suite.** Expected: PASS.
- [ ] **Step 5: Commit** `fix(contract): release claimed codes on failed fulfillment, emit redemption events`

### Task 5: Allowlist + gift registry mastery

**Files:**
- Modify: `contract/src/GetGift.sol`
- Test: `contract/test/unit/GetGift.access.t.sol` (new + update), `GetGift.nft.t.sol` (getter tests)

**Interfaces:**
- Consumes: Task 2's `CallerNotAllowlisted`, Task 4 events.
- Produces: `removeFromAllowList(address addrToRemove) external onlyAllowList` (signature change — tests + InteractWithGetGift.s.sol updated); new errors `CannotRemoveLastAllowlisted()`, `AddressNotAllowlisted()`, `InvalidGiftDefinition()`; `uint256 public allowListCount;` (getter); behavior: count tracked in constructor (init 1) / addGift-path; removal of non-listed reverts; removal of last remaining reverts; `addGift` validates non-empty name+uri and emits `GiftAdded(string giftName, string tokenUri)`; `AllowListAdded(address indexed)` / `AllowListRemoved(address indexed)` emitted on respectively adding (only on real state change) and removal; visibility: `allowList`, `giftCodeRedeemed`, `giftToTokenUri` become `public` mappings (auto-getters). `addGift` may re-register/overwrite existing names (intentional admin power) but still emits.

- [ ] **Step 1: Write failing tests** (access suite): `test_RemoveFromAllowList_ByAddress` (owner removes user; user loses perms), `test_RemoveFromAllowList_CannotRemoveLastAdmin` (only owner on list; owner removes self → `CannotRemoveLastAllowlisted`), `test_RemoveFromAllowList_RevertIfNotListed` (allowlisted caller removes stranger → `AddressNotAllowlisted`), `test_AddToAllowList_CountAndEvents` (`allowListCount` correct after add+dup-add; `vm.expectEmit` `AllowListAdded`), `test_RemoveFromAllowList_EmitsEvent`.
- [ ] **Step 2: Write failing tests** (nft suite for registry): `test_AddGift_RegistersNewGiftType` (add `("new item", "ipfs://new")`; fulfill a request whose response encodes `"new item"` → mint with that URI; NFT owner + tokenURI asserted), `test_AddGift_RevertIfEmptyName`, `test_AddGift_RevertIfEmptyUri`, `test_GiftToTokenUri_PublicGetters` (`getGift.giftToTokenUri(ITEM_1)` returns ITEM_1_METADATA; `getGift.giftCodeRedeemed(code)` toggles false→false after released fulfillment... exact: false initially, true while claimed *in flight* (after send, before fulfill), false again after released fulfill).
- [ ] **Step 3: Run** targeted suites. Expected: all new FAIL (compile error on the old no-arg `removeFromAllowList` usage — update those two existing call sites in access tests to self-removal with explicit address).
- [ ] **Step 4: Implement** per Interfaces block in `GetGift.sol`; update `contract/script/InteractWithGetGift.s.sol` FUNCTION selector strings that referenced `removeFromAllowList` if any (or the envexample FUNCTION comment).
- [ ] **Step 5: Run full suite.** Expected: PASS.
- [ ] **Step 6: Commit** `feat(contract): parameterized allowlist removal with lockout guard, validated gift registry, public getters`.

### Task 6: Tooling — env example, Makefile, foundry.toml, gitignore, fmt

**Files:**
- Create: `contract/.env.example`
- Delete: `contract/envexample.sh`
- Modify: `contract/Makefile`, `contract/foundry.toml`, `contract/.gitignore`
- Batch format: `forge fmt` across repo.

**Interfaces:** plain `make build` / `make test` / `make fmt-check` work with zero env vars.

- [ ] **Step 1:** `contract/.env.example` — placeholders only (no real-looking keys): `SEPOLIA_RPC_URL`, `MAINNET_RPC_URL`, `ETHERSCAN_API_KEY`, `PRIVATE_KEY`, `CONTRACT_ADDRESS`, `WALLET_ADDRESS`, `CONTRACT_NAME=src/GetGift.sol:GetGift`, `SCRIPT_FILE=script/DeployGetGift.s.sol:DeployGetGift`, `FUNCTION=`, commented usage lines. Delete `envexample.sh`.
- [ ] **Step 2:** Makefile: `test` and `build` and `coverage` and `snapshot` no longer depend on `check-network` (drop from `test` target; keep `--ffi` off normal path — only `test-fork`/`deploy-fork` fork targets use RPC); add `fmt:` and `fmt-check:` targets (`forge fmt`, `forge fmt --check`); add `sizes:` (`forge --version` no… use `forge inspect GetGiftERC721`? skip — keep minimal: fmt only).
- [ ] **Step 3:** foundry.toml: delete bogus `[profile.test]` (src must stay `src`), remove `no_match_test` duplication-consistency (keep), and drop `env_file` if Task 1 found it unsupported (otherwise keep).
- [ ] **Step 4:** contract/.gitignore: add `coverage-report/`, `lcov.info`.
- [ ] **Step 5:** run `forge fmt` (contract dir) and `forge fmt --check`. Fix any diffs.
- [ ] **Step 6: Run full suite** (`make build && make test`). PASS → commit `chore: env example, Makefile RPC-free test path, config cleanup, formatting`.

### Task 7: CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:** mirrors Makefile: setup foundry + submodules + `fmt-check` + build + `forge test`.

- [ ] **Step 1:** workflow: on push/PR; `foundry-rs/foundry-toolchain@v1`; `git submodule update --init --recursive`; `forge fmt --check`, `forge build`, `forge test -vvv`. One job `contract`.
- [ ] **Step 2:** lint check locally: `bash -n` not needed (no scripts); validate YAML parses (eyeball / `python3 -c yaml.safe_load`).
- [ ] **Step 3: Commit** `ci: build+test+fmt workflow`.

### Task 8: README + docs truth pass

**Files:**
- Modify: `README.md` (root)
- Modify: `docs/superpowers/specs/…` if reality diverged (only if so)

- [ ] **Step 1:** Rewrite: overview + how it works (existing diagram), repo layout incl. stage branches (`testing`, `Script`, `Agent` frozen as historical stages), quickstart (clone/submodule/build/test/env/deploy/interact/coverage), env table keyed to `.env.example`, Docker section fixed (real image is the dev toolchain that clones the repo via `entrypoint.sh`; correct `docker build -t intellichain:latest .` and `docker run -it --rm intellichain:latest bash`), security section (banner stays: un-audited; race-status of the ORIGINAL defect documented as fixed w/ mystery-type tradeoff), contract surface summary (errors/events), and acknowledgement of the Chainlink example-derived provenance.
- [ ] **Step 2:** Cross-check every command in README against Makefile targets actually present.
- [ ] **Step 3: Commit** `docs: truth pass on README (architecture, quickstart, docker, security)`.

### Task 9: Final verification & wrap

- [ ] **Step 1:** `forge fmt --check && forge build && forge test -vvv` — expect: clean, all PASS.
- [ ] **Step 2:** `git -C . diff origin/main --stat` review; `git log --oneline` shows clean logical commits; no secrets introduced anywhere (`grep -RIE "(0x[a-fA-F0-9]{40})"` on non-lib files for accidental real addresses is informational only — the Sepolia router/DON/contract addresses are public knowledge, fine).
- [ ] **Step 3:** Report to owner: summary of commits + `git push` instructions (they own the push).
