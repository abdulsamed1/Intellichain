#!/bin/bash
set -euo pipefail  # Exit on errors, unset variables, and pipeline failures

# =============================
# Environment Setup
# =============================
readonly APP_ROOT="/app/Intellichain"
readonly CONTRACTS_DIR="$APP_ROOT/contract"

echo "🧹 Cleaning previous Intellichain directory..."
rm -rf "$APP_ROOT" || true

# =============================
# Project Cloning
# =============================
echo "🚀 Cloning Intellichain project from GitHub..."
git clone --recurse-submodules https://github.com/abdulsamed1/Intellichain.git  "$APP_ROOT"

# =============================
# Navigate to Contracts Directory
# =============================
cd "$CONTRACTS_DIR" || { echo "❌ Failed to enter contracts directory"; exit 1; }

# =============================
# Git Submodules Initialization
# =============================
initialize_submodules() {
    if [[ -f .gitmodules ]]; then
        echo "🧩 Syncing and updating git submodules..."
        git submodule sync --quiet
        git submodule update --init --recursive --force
    elif [[ -f foundry.toml ]]; then
        echo "⚠️ No .gitmodules found. Using Foundry to install dependencies..."
        forge install
    else
        echo "⚠️ No git submodules or foundry.toml detected. Skipping submodule setup."
    fi
}

initialize_submodules

# =============================
# Install Dependencies via Makefile
# =============================
run_make_targets() {
    if [[ -f Makefile ]]; then
        if grep -q "init:" Makefile; then
            echo "🔧 Running 'make init'..."
            make install
            make update
        else
            echo "🔧 Running fallback: 'make install' and 'make update'..."
            [[ $(grep -q "install:" Makefile) ]] && make install
            [[ $(grep -q "update:" Makefile) ]] && make update
        fi
    else
        echo "⚠️ Makefile not found. Skipping dependency installation via Make."
    fi
}

run_make_targets

# =============================
# Check for Forge Dependencies
# =============================
check_forge_deps() {
    if [[ ! -d "lib" || -z "$(ls -A lib 2>/dev/null)" ]]; then
        echo "⚠️ Dependency folder 'lib' is empty or missing. Installing via Foundry..."
        forge remappings > remappings.txt || true
        forge install
    fi
}

check_forge_deps

# =============================
# Install Cyfrin Static Analysis Tools
# =============================
setup_cyfrin() {
    local cyfrin_path="/root/.cyfrin/bin/cyfrinup"
    if [[ -x "$cyfrin_path" ]]; then
        echo "🔍 Installing Cyfrin static analysis tools..."
        "$cyfrin_path"
    else
        echo "⚠️ Cyfrinup not found or not executable at $cyfrin_path"
    fi
}

setup_cyfrin

# =============================
# Add Rust-based Tools to PATH
# =============================
setup_rust_tools() {
    if [[ -f "/root/.cargo/env" ]]; then
        echo "🔧 Adding Rust tools (e.g., Aderyn, Safe-Hash) to PATH..."
        source "/root/.cargo/env"
    else
        echo "⚠️ Rust environment not found. Cargo env file missing."
    fi
}


# =============================
# Build Smart Contracts
# =============================
build_contracts() {
    if [[ -f Makefile && $(grep -c "build:" Makefile) -gt 0 ]]; then
        echo "🏗️ Building contracts using Makefile..."
        make build
    else
        echo "🏗️ Building contracts using Forge..."
        forge build
    fi
}

build_contracts

# =============================
# Run Aderyn Static Analysis
# =============================
run_aderyn_analysis() {
    if command -v aderyn &> /dev/null; then
        echo "🧪 Running Aderyn static analysis..."
        aderyn . || echo "⚠️ Warning: Aderyn analysis failed"
    else
        echo "⚠️ Aderyn not found in PATH. Skipping static analysis."
    fi
}

run_aderyn_analysis

# =============================
# Final Shell Access
# =============================
echo "✅ Setup complete. Entering interactive shell..."
exec bash