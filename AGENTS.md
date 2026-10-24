# AGENTS.md

Intellichain is an open-source demonstration of trustless Twitter-based NFT
gifting: an elizaOS agent (`agent/`) watches tweet replies, extracts claim
data deterministically, and drives a hardened Chainlink Functions contract
(`contract/`) that mints ERC-721 gift NFTs and reports fulfillment honestly.

## The two halves

- `contract/` — Foundry/Solidity (forge). Dependencies are pinned git
  submodules; run `make install` there once after cloning.
- `agent/` — TypeScript on elizaOS 0.1.7. The package manager is **pnpm**
  (not npm/yarn; there is no root package.json — run pnpm inside `agent/`).

## Commands

Green gates are the contract for touching anything here:

```bash
cd agent && make check              # tsc --noEmit + the offline vitest suite
cd contract && make build && make test   # offline forge gates
```

Both suites run fully offline (no RPC, no Twitter, no model keys). New tests
should stay offline too — inject a fake at the dependency seam, the way
`agent/src/core/monitor.ts` and `agent/src/core/claim.ts` accept injected
chain surfaces.

## Working agreements

- Secrets live only in gitignored `.env` files (`agent/.env`,
  `contract/.env`). Never commit, print, or log a secret value — boot logs
  print character/resource names, never keys.
- Agent behavior changes start with a failing vitest test first
  (test-driven), then implementation. The pure modules under
  `agent/src/core/` and `agent/src/custom-plugins/` are the pattern to fit.
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`,
  `ci:`), written for both the changelog and a portfolio reader.
- Keep tracked text files glyph-free: no Han/kana/hangul characters in
  `agent/` sources, tests, scripts, or the READMEs (typography consistency
  before commit).
- CI (`.github/workflows/ci.yml`) runs both gates entirely offline and
  needs no repository secrets — keep it that way. Secrets are provisioned
  per-environment by the operator via `.env` and `make don-secrets`.

## Where to dig deeper

- Agent runbook — full env surface, model-key precedence (including the
  FreeLLMAPI free route), vendored provenance, dependency notes:
  [agent/README.md](agent/README.md)
- Deployment, Chainlink Functions subscription/secrets order, contract
  surface, invariants: [README.md](README.md)
- Agent design decisions and implementation plan:
  [specs/2026-10-23-agent-evolution-design.md](docs/superpowers/specs/2026-10-23-agent-evolution-design.md),
  [plans/2026-10-23-agent-evolution.md](docs/superpowers/plans/2026-10-23-agent-evolution.md)
- FreeLLMAPI — the recommended free, self-hosted model route for the agent:
  <https://github.com/abdulsamed1/freellmapi>
