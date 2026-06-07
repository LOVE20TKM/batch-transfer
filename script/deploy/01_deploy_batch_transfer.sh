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

if [ -z "$RPC_URL" ]; then
    echo -e "\033[31mError:\033[0m Environment not initialized. Please run 00_init.sh first."
    return 1 2>/dev/null || exit 1
fi

current_precheck_key="${network}|${RPC_URL}"

if [ "$BATCH_TRANSFER_PRECHECK_DONE" != "1" ] || [ "$BATCH_TRANSFER_PRECHECK_KEY" != "$current_precheck_key" ]; then
    if ! source "$SCRIPT_DIR/00_precheck.sh"; then
        return 1 2>/dev/null || exit 1
    fi
fi

echo "Deploying BatchTransfer contract..."

forge_script script/DeployBatchTransfer.s.sol:DeployBatchTransfer --sig "run()"

if [ $? -eq 0 ]; then
    source "$network_dir/address.batch-transfer.params"
    echo -e "\033[32m✓\033[0m BatchTransfer deployed at: $batchTransferAddress"
    return 0 2>/dev/null || exit 0
else
    echo -e "\033[31m✗\033[0m Failed to deploy BatchTransfer"
    return 1 2>/dev/null || exit 1
fi
