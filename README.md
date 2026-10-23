# Intellichain 🔗✨

**Twitter → AI agent → Chainlink Functions → NFT gift, without trusting anyone with the database.**

Users reply to a tweet with a claim code and their wallet address. An
[ElizaOS](https://github.com/elizaOS/eliza) agent parses the reply, a
Chainlink Functions DON verifies the code against a Supabase table, and the
`GetGift` contract mints an ERC-721 gift NFT straight to the claimed wallet.

> ⚠️ **This is un-audited code, derived from Chainlink's example contracts.**
> Do not use it in production without a professional audit.

## 🏗️ How it works

![System Diagram](img/image.jpg)

1. **User Tweet Reply** — the user replies to a tweet with their wallet address and a claim code.
2. **AI Agent (ElizaOS)** — parses the tweet, extracts wallet + code, validates intent.
3. [**Chainlink Functions**](https://functions.chain.link/) — a decentralizedDON runs the claim-check JavaScript in a trusted execution environment: it calls Supabase, verifies the code exists and is unused, and returns the gift type.
4. **`GetGift` contract (Sepolia)** — receives the signed oracle result and mints the mapped gift NFT.
5. **User receives the gift** — the NFT (with IPFS metadata) lands in the claimed wallet.

On-chain invariants keep the system honest:

| Invariant | Mechanism |
|---|---|
| A code is redeemed **at most once**, even with two concurrent requests | the code is *claimed atomically* in `sendRequest` and only released again if fulfillment fails |
| LINK is never burned on a request that can never be fulfilled | only one request may await fulfillment (`RequestAlreadyInFlight`), and code/recipient are validated *before* the paid request |
| No empty-metadata mints | an oracle-valid code whose gift type is not registered does not mint; the code is released so the admin can `addGift()` it |
| Admin can never be bricked | removing the **last** allowlisted member reverts (`CannotRemoveLastAllowlisted`) |
| Everything indexable | `GiftRedeemed`, `GiftCodeReleased`, `GiftAdded`, `AllowListAdded/Removed` events + public mapping getters |

## 📦 Repository layout

```
.
├── contract/                # Foundry project (the deliverable)
│   ├── src/GetGift.sol      # Chainlink Functions client + ERC-721 gift minter
│   ├── script/              # deployment, interaction, config helpers
│   ├── test/unit/           # 55 offline unit tests (no RPC required)
│   └── Makefile             # build / test / fmt / deploy / interact / verify
├── .github/workflows/ci.yml # format → build → unit tests on every push/PR
├── Dockerfile + entrypoint.sh
└── img/                     # system diagram
```

The maturity stages were developed on separate branches and are **frozen there
as historical snapshots**: `testing` (test-first stage), `Script`
(deployment stage), `Agent` (the ElizaOS agent). Everything that matters is
consolidated here on `main`.

## 🚀 Quickstart

Prerequisites: [Foundry](https://book.getfoundry.sh/) (`curl -L https://foundry.paradigm.xyz | bash && foundryup`), `git`, `make`.

```bash
git clone --recurse-submodules https://github.com/abdulsamed1/Intellichain.git
cd Intellichain/contract

# dependencies (pinned git submodules: forge-std, OpenZeppelin, Chainlink)
make install

# configure: copy the example and fill in your own values, never commit .env
cp .env.example .env

# build + test everything OFFLINE (no RPC key needed)
make build
make test
make fmt          # format;   make fmt-check fails CI if unformatted

# deploy to Sepolia (needs SEPOLIA_RPC_URL + PRIVATE_KEY in .env)
make deploy CONTRACT_NAME=src/GetGift.sol:GetGift

# verify on Etherscan (needs ETHERSCAN_API_KEY)
make verify CONTRACT_ADDRESS=0x...

# coverage report for GetGift.sol
make coverage     # → ./coverage-report/index.html
```

The deployment scripts read network defaults from
`contract/script/utility/NetworkConfigLibrary.sol` (Sepolia router
`0xb83E47C2bC239B3bf370bc41e1459A34b41238D0`, DON `fun-ethereum-sepolia-1`);
the router/DON are passed into the constructor, so the same bytecode serves
other networks by extending that one file.

> 🔁 The contract at [`0x3437c36913b3f2f18a71f63750d0a35fbd6b2135`](https://sepolia.etherscan.io/address/0x3437c36913b3f2f18a71f63750d0a35fbd6b2135)
> is the **original example deployment** — main has evolved beyond it and
> needs a fresh deployment.

## ⚙️ Environment variables

| Variable | Used by | Notes |
|---|---|---|
| `SEPOLIA_RPC_URL` | deploy / verify / cast targets | Alchemy or Infura endpoint |
| `MAINNET_RPC_URL` | fork tests, `make anvil-fork` | not needed for plain tests |
| `ETHERSCAN_API_KEY` | `make verify` | etherscan.io account |
| `PRIVATE_KEY` | deploy / broadcast | fund with Sepolia ETH + LINK |
| `CONTRACT_ADDRESS`, `WALLET_ADDRESS` | interaction targets | addresses of deployed contract / your wallet |
| `CONTRACT_NAME`, `SCRIPT_FILE` | deploy / interact | defaults match this repo |
| `FUNCTION`, plus target-specific args (`SALT`, `VALUE`, `TX_HASH`, …) | misc cast targets | see `make help` |

Plain `make build` / `make test` / `make fmt` need **nothing** — they are
fully offline.

## 🐳 Docker

The image is the **dev/AI-toolchain** (Foundry, Slither, Cyfrinup, Node), not
a production service; `entrypoint.sh` clones this repo (with submodules)
into `/app/Intellichain` and runs `install → build → static analysis`,
then drops you into a shell:

```bash
# build the toolchain image (note the space after `.`)
docker build -t intellichain:latest .

# start it; mount nothing — the entrypoint clones the repo itself
docker run -it --rm intellichain:latest bash
```

Inside you already have a compiled, analyzed copy of the project in
`/app/Intellichain/contract`.

## 🧪 Testing

55 tests across 7 suites (`contract/test/unit/`), all offline:

| Suite | Covers |
|---|---|
| `GetGift.init.t.sol` | constructor + injected router/DON |
| `GetGift.access.t.sol` | allowlist paths, count bookkeeping, lockout guard, events |
| `GetGift.request.t.sol` | request validation, racing claims, in-flight invariant |
| `GetGift.fulfillment.t.sol` | fulfillment outcomes, release paths, minting, events |
| `GetGift.nft.t.sol` | mint/metadata correctness, registry getters |
| `GetGift.gas.t.sol` | gas profiling for request + fulfillment |
| `utilites/GetGift.utils.t.sol` | shared base (mocked Chainlink router) |

## 📜 Contract surface (`src/GetGift.sol`)

- **Errors** `UnexpectedRequestID`, `CallerNotAllowlisted`, `CodeAlreadyRedeemed`, `RequestAlreadyInFlight`, `InvalidGiftCode`, `InvalidRecipient`, `CannotRemoveLastAllowlisted`, `AddressNotAllowlisted`, `InvalidGiftDefinition`
- **Events** `Response`, `GiftRedeemed`, `GiftCodeReleased`, `GiftAdded`, `AllowListAdded`, `AllowListRemoved`
- **Admin** (allowlist-gated): `addGift`, `addGiftToAllowList → addToAllowList`, `removeFromAllowList(address)`, `sendRequest`
- **Oracle-only** `handleOracleFulfillment` (router-gated, Chainlink standard)
- Chainlink request details: DON-hosted Supabase API key (slot/version), inline SOURCE JS, 300k callback gas

## 🙏 Provenance

The contract started from Chainlink's
[GetGift Functions example](https://github.com/smartcontractkit/examples)
and the [Cyfrin Updraft](https://github.com/Cyfrin) workflow (audit → test →
deploy stages), reworked hardening-first into what is here now. The ElizaOS
agent stage lives on the `Agent` branch.

## ✅ Use cases

- **Marketing campaigns** — reward users who engage with tweets.
- **Event ticketing** — issue NFTs based on RSVP codes.
- **Gaming** — claim in-game items through social media.
