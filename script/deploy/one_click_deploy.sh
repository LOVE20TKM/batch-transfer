#!/bin/bash

if [ -n "${ZSH_VERSION:-}" ]; then
    SCRIPT_PATH="$0"
elif [ -n "${BASH_VERSION:-}" ]; then
    SCRIPT_PATH="${BASH_SOURCE[0]}"
else
    SCRIPT_PATH="$0"
fi

SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT" || return 1 2>/dev/null || exit 1

echo -e "\n[Step 1/5] Initializing environment..."
source "$SCRIPT_DIR/00_init.sh" "$1"
if [ $? -ne 0 ]; then
    echo -e "\033[31mError:\033[0m Failed to initialize environment"
    return 1 2>/dev/null || exit 1
fi

echo -e "\n========================================="
echo -e "  One-Click Deploy BatchTransfer"
echo -e "  Network: $network"
echo -e "========================================="

echo -e "\n[Step 2/5] Running deployment precheck..."
if ! source "$SCRIPT_DIR/00_precheck.sh"; then
    echo -e "\033[31mError:\033[0m Deployment precheck failed"
    return 1 2>/dev/null || exit 1
fi

echo -e "\n[Step 3/5] Deploying BatchTransfer..."
source "$SCRIPT_DIR/01_deploy_batch_transfer.sh"
if [ $? -ne 0 ]; then
    echo -e "\033[31mError:\033[0m Deployment failed"
    return 1 2>/dev/null || exit 1
fi

if [[ "$network" == thinkium70001* ]]; then
    echo -e "\n[Step 4/5] Verifying contract on explorer..."
    source "$SCRIPT_DIR/02_verify.sh"
    if [ $? -ne 0 ]; then
        echo -e "\033[33mWarning:\033[0m Contract verification failed (deployment is still successful)"
    else
        echo -e "\033[32m✓\033[0m Contract verified successfully"
    fi
else
    echo -e "\n[Step 4/5] Skipping contract verification (not a thinkium network)"
fi

echo -e "\n[Step 5/5] Running deployment checks..."
source "$SCRIPT_DIR/99_check.sh"
if [ $? -ne 0 ]; then
    echo -e "\033[31mError:\033[0m Deployment checks failed"
    return 1 2>/dev/null || exit 1
fi

echo -e "\n========================================="
echo -e "\033[32m✓ Deployment completed successfully!\033[0m"
echo -e "========================================="
echo -e "BatchTransfer Address: $batchTransferAddress"
echo -e "Network: $network"
echo -e "=========================================\n"
