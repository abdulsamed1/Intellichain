# @intellichain/agent

The AI-agent stage of Intellichain: an elizaOS agent that watches Twitter for
gift-claim replies, validates them, drives the hardened `GetGift` Chainlink
Functions contract (`contract/`) per-user, and monitors fulfillment so it can
tell a user the truth: **minted**, **released (retry)**, or **timeout**.

> Full documentation is written during the agent plan (`docs/superpowers/plans/
> 2026-10-23-agent-evolution.md`). This stub ships with the scaffold; the
> completed runbook lands with the final agent commit.

Status: **Phase A** — in development (offline-tested; no secrets in the repo).
