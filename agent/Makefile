# Agent-stage targets. Requires pnpm (see package.json packageManager) and
# node >= 22. `make don-secrets` uploads the DON-hosted secrets and writes
# FUNCTIONS_SLOT_ID / FUNCTIONS_SECRET_VERSION back into .env (never the key).

.PHONY: help typecheck test check don-secrets start

help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

typecheck: ## Run tsc --noEmit over the agent
	pnpm typecheck

test: ## Run the offline vitest suite (no Twitter/RPC/model keys needed)
	pnpm test

check: typecheck test ## Type-check + tests (CI gate)

don-secrets: ## Upload DON-hosted secrets; writes slot/version into .env
	pnpm don-secrets

start: ## Start the agent runtime (reads .env)
	pnpm start
