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

if [[ "$network" != thinkium70001* ]]; then
    echo "Network is not thinkium70001 related, skipping verification"
    return 0 2>/dev/null || exit 0
fi

if [ -z "$RPC_URL" ]; then
    source "$SCRIPT_DIR/00_init.sh" "$network"
fi

if [ -z "$batchTransferAddress" ]; then
    if [ ! -f "$network_dir/address.batch-transfer.params" ]; then
        echo -e "\033[31mError:\033[0m BatchTransfer address file not found: $network_dir/address.batch-transfer.params"
        return 1 2>/dev/null || exit 1
    fi
    source "$network_dir/address.batch-transfer.params"
fi

if [ -z "$batchTransferAddress" ]; then
    echo -e "\033[31mError:\033[0m batchTransferAddress not set"
    return 1 2>/dev/null || exit 1
fi

echo "Verifying contract: BatchTransfer at $batchTransferAddress"

forge verify-contract \
    --chain-id "$CHAIN_ID" \
    --verifier "$VERIFIER" \
    --verifier-url "$VERIFIER_URL" \
    "$batchTransferAddress" \
    src/BatchTransfer.sol:BatchTransfer

if [ $? -eq 0 ]; then
    echo -e "\033[32m✓\033[0m Contract BatchTransfer verified successfully"
    return 0 2>/dev/null || exit 0
else
    echo -e "\033[31m✗\033[0m Failed to verify contract BatchTransfer"
    return 1 2>/dev/null || exit 1
fi
