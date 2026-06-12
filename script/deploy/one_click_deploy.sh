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

echo -e "\n[Step 1/4] Initializing environment..."
source "$SCRIPT_DIR/00_init.sh" "$1"
if [ $? -ne 0 ]; then
    echo -e "\033[31mError:\033[0m Failed to initialize environment"
    return 1 2>/dev/null || exit 1
fi

echo -e "\n========================================="
echo -e "  One-Click Deploy BatchTransfer"
echo -e "  Network: $network"
echo -e "========================================="

echo -e "\n[Step 2/4] Deploying BatchTransfer..."
source "$SCRIPT_DIR/01_deploy_batch_transfer.sh"
if [ $? -ne 0 ]; then
    echo -e "\033[31mError:\033[0m Deployment failed"
    return 1 2>/dev/null || exit 1
fi

echo -e "\n[Step 3/4] Running explorer verification step..."
source "$SCRIPT_DIR/02_verify.sh"
if [ $? -ne 0 ]; then
    echo -e "\033[33mWarning:\033[0m Contract verification failed (deployment is still successful)"
fi

echo -e "\n[Step 4/4] Running deployment checks..."
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
