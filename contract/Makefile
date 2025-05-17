# -*- makefile -*-
# Makefile for Foundry Project - Professional Edition

# --------------------------
# Environment Configuration
# --------------------------
ifneq (,$(wildcard .env))
    include .env
    export
endif

# --------------------------
# Phony Targets Declaration
# --------------------------
.PHONY: help \
        init clean install update build \
        test test-fork coverage snapshot \
        anvil anvil-fork node \
        deploy verify \
        send call create2 multisig \
        storage logs events \
        balance nonce gas block \
        erc20 erc721 erc1155 \
        proof debug trace \
        calldata abi sig tx receipt \
        fork-cheatcodes gas-report

# --------------------------
# Global Variables
# --------------------------
MNEMONIC="test test test test test test test test test test test junk"

# --------------------------
# Utility Functions
# --------------------------
define check_var
	@if [ -z "$${$(1)}" ]; then \
		echo "❌ Error: $(1) not set!"; \
		exit 1; \
	fi
endef

define call_contract
	@cast call $(1) "$(2)" $(3) --rpc-url $(TestNet)
endef

# --------------------------
# Main Targets
# --------------------------
help:  ## Display comprehensive help menu
	@printf "\033[1;36m%s\033[0m\n" "Foundry Project Management System"
	@printf "\033[1;34m%-25s\033[0m%s\n" "Target" "Description"
	@printf "───────────────────────────────────────────────\n"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[1;32m%-25s\033[0m%s\n", $$1, $$2}' $(MAKEFILE_LIST)


# --------------------------
# Project Setup
# --------------------------
clean:  ## Clean build artifacts and dependencies
	@echo "🧹 Cleaning build artifacts..."
	@forge clean

install:  ## Install dependencies via Git submodules
	@echo "📦 Installing project dependencies using Git submodules..."
	@git submodule init
	@git submodule update --recursive --remote --force
	@forge install

update:  ## Update all submodules
	@echo "🔄 Updating all dependencies..."
	@git submodule update --remote --merge --recursive
	@forge build

build:  ## Compile contracts
	@echo "🏗️  Building contracts..."
	@forge build --optimize --force

# --------------------------
# Testing & Verification
# --------------------------

test: check-network  ## Run basic tests
	@echo "🧪 Running basic tests..."
	@forge test -vvvv --ffi 


test-fork: check-network  ## Run tests on forked network
	@echo "🧪 Running tests on forked network..."
	@forge test -vvv --fork-url $(Mainnet) --ffi

test-func:  ## Run specific test 
	@echo "🧪 Running test on function..."
	@forge test --match-test $(FUNCTION_TEST) -vvv

coverage:  ## Generate coverage report
	@echo "📊 Generating coverage report..."
	@forge coverage --ir-minimum --via-ir --report lcov

snapshot:  ## Create test snapshots
	@echo "📸 Creating test snapshots..."
	@forge snapshot

gas-report:  ## Generate gas optimization report
	@echo "⛽ Generating gas optimization report..."
	@forge test --gas-report

# --------------------------
# Fork & Local Node
# --------------------------

# Start a local Anvil node without forking
anvil: ## Start Anvil node
	@echo "⏳ Stopping any running Anvil instances..."
	@pkill -9 anvil || true
	@echo "🚀 Starting Anvil node..."
	@anvil --mnemonic $(MNEMONIC) &
	@sleep 2
	@echo "✅ Anvil is running..."

# Start an Anvil node with mainnet forking
anvil-fork: ## Start Anvil node with fork
	@echo "⏳ Stopping any running Anvil instances..."
	@pkill -9 anvil || true
	@echo "🚀 Starting Anvil Fork node..."
	@anvil --mnemonic $(MNEMONIC) --fork-url $(Mainnet) &
	@sleep 2
	@echo "✅ Anvil Fork is running..."

# Start a local Anvil node (no mnemonic, no forking)
node: ## Start local node
	@echo "⏳ Stopping any running Anvil instances..."
	@pkill -9 anvil || true
	@echo "🚀 Starting local Anvil node..."
	@anvil &
	@sleep 2
	@echo "✅ Local Anvil node is running..."

# Start an Anvil Fork and deploy a contract using Foundry's Forge
deploy-fork: ## Start Anvil Fork and Deploy Contract
	@echo "🚀 Starting Anvil Fork for deployment..."
	@pkill -9 anvil || true
	@anvil --mnemonic $(MNEMONIC) --fork-url $(Mainnet) &
	@sleep 30
	@echo "📜 Deploying Contract..."
	@forge script $(CONTRACT_NAME) \
		--rpc-url http://127.0.0.1:8545 \
		--broadcast \
		-vvvv

# Start an Anvil Fork at a specific block to reduce Infura requests and deploy a contract
deploy-fork-lastblock: ## Start Anvil Fork at last block and Deploy Contract
	@echo "🚀 Starting Anvil Fork for deployment at a specific block..."
	@anvil --mnemonic $(MNEMONIC) --fork-url $(Mainnet) --fork-block-number 21954976 &
	@sleep 30
	@echo "📜 Deploying Contract..."
	@forge script ${CONTRACT_NAME} \
		--rpc-url http://127.0.0.1:8545 \
		--broadcast

# --------------------------
# Deployment & Interaction
# --------------------------
deploy: ## Deploy to testnet live network	
	@echo "🚀 Starting Deploy on testnet live network..."
	@forge script $(CONTRACT_NAME) \
		--rpc-url $(TestNet) \
		--keystore $(KEYSTORE_PASSWORD) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

verify: check-network check-contract  ## Verify deployed contract
	@echo "🔍 Verifying deployed contract..."
	@forge verify-contract $(CONTRACT_ADDRESS) $(CONTRACT_NAME) \
		--chain-id 11155111 \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

# --------------------------
# Contract Interactions
# --------------------------
send: check-network check-keystore check-contract  ## Send transaction
	@echo "📤 Sending transaction..."
	@cast send $(CONTRACT_ADDRESS) "$(FUNCTION)" \
		--rpc-url $(TestNet) \
		--keystore $(KEYSTORE_PASSWORD) \
		--value $(VALUE) \
		--legacy

call: check-network check-contract  ## Call view function
	@echo "📞 Calling view function..."
	@cast call $(CONTRACT_ADDRESS) "$(FUNCTION)" \
		--rpc-url $(TestNet)

create2: check-network check-keystore  ## Deploy with CREATE2
	@echo "🚀 Deploying contract with CREATE2..."
	@forge create2 $(CONTRACT_NAME) \
		--rpc-url $(TestNet) \
		--keystore $(KEYSTORE_PASSWORD) \
		--init-code-hash $(SALT)

multisig: check-network  ## Generate multisig transaction
	@echo "🔐 Generating multisig transaction..."
	@cast mksig "$(FUNCTION)" $(ARGS)

# --------------------------
# Chain Inspection
# --------------------------
storage: check-network check-contract  ## Inspect contract storage
	@echo "🔎 Inspecting contract storage..."
	@cast storage $(CONTRACT_ADDRESS) $(SLOT) --rpc-url $(TestNet)

logs: check-network check-contract  ## View contract logs
	@echo "📝 Displaying contract logs..."
	@cast logs --from-block $(BLOCK) --address $(CONTRACT_ADDRESS) --rpc-url $(SEPOLIA_RPC_URL)

events: check-network check-contract  ## Decode contract events
	@echo "🎫 Decoding contract events..."
	@cast events $(CONTRACT_ADDRESS) \
		--rpc-url $(TestNet) \
		--from-block $(FROM_BLOCK) \
		--to-block $(TO_BLOCK)

# --------------------------
# Account Management
# --------------------------
balance: check-network check-address  ## Check ETH balance
	@echo "💰 Checking ETH balance..."
	@cast balance $(WALLET_ADDRESS) --rpc-url $(TestNet)

nonce: check-network check-address  ## Check account nonce
	@echo "🔢 Checking account nonce..."
	@cast nonce $(WALLET_ADDRESS) --rpc-url $(TestNet)

gas: check-network  ## Get current gas price
	@echo "⛽ Fetching current gas price..."
	@cast gas-price --rpc-url $(TestNet)

block: check-network  ## Get block information
	@echo "📦 Fetching block information..."
	@cast block $(BLOCK_NUMBER) --rpc-url $(TestNet) --json

# --------------------------
# Advanced Cast Utilities
# --------------------------
calldata:  ## Generate calldata
	@echo "📝 Generating calldata..."
	@cast calldata "$(SIG)" $(ARGS)

abi: check-contract  ## Generate contract ABI
	@echo "📜 Generating contract ABI..."
	@cast abi $(CONTRACT_NAME)

sig:  ## Get function selector
	@echo "⚙️ Retrieving function selector..."
	@cast sig "$(FUNCTION)"

tx: check-network  ## Get transaction details
	@echo "🔍 Fetching transaction details..."
	@cast tx $(TX_HASH) --rpc-url $(TestNet) --json

receipt: check-network  ## Get transaction receipt
	@echo "📃 Fetching transaction receipt..."
	@cast receipt $(TX_HASH) --rpc-url $(TestNet) --json

# --------------------------
# Token Standards
# --------------------------
erc20: check-network check-address  ## قراءة رصيد ERC20
	@echo "💸 Reading ERC20 token balance..."
	$(call call_contract, $(TOKEN_ADDRESS), "balanceOf(address)", $(WALLET_ADDRESS))

erc721: check-network check-address  ## قراءة مالك توكن ERC721
	@echo "🖼️ Reading ERC721 token owner..."
	$(call call_contract, $(NFT_ADDRESS), "ownerOf(uint256)", $(TOKEN_ID))

erc1155: check-network check-address  ## قراءة رصيد ERC1155
	@echo "🔢 Reading ERC1155 token balance..."
	$(call call_contract, $(MULTI_TOKEN_ADDRESS), "balanceOf(address,uint256)", "$(WALLET_ADDRESS) $(TOKEN_ID)")

# --------------------------
# Development Utilities
# --------------------------
proof: check-network check-contract  ## Generate storage proof
	@echo "🔐 Generating storage proof..."
	@cast proof $(CONTRACT_ADDRESS) $(STORAGE_KEY) --rpc-url $(TestNet)

debug: check-network  ## Debug transaction
	@echo "🐞 Debugging transaction..."
	@cast debug $(TX_HASH) --rpc-url $(TestNet)

trace: check-network  ## Trace transaction
	@echo "🔍 Tracing transaction..."
	@cast trace $(TX_HASH) --rpc-url $(TestNet) --steps --verbose

fork-cheatcodes: check-network  ## Access mainnet state
	@echo "🌐 Accessing mainnet state via fork cheatcodes..."
	@forge script --fork-url $(TestNet) --sig "run(address)" $(CHEAT_ADDRESS)

# --------------------------
# Validation Helpers
# --------------------------
check-network:
	$(call check_var,TestNet)

check-keystore:
	$(call check_var,KEYSTORE_PASSWORD)

check-contract:
	$(call check_var,CONTRACT_ADDRESS)

check-address:
	$(call check_var,WALLET_ADDRESS)
