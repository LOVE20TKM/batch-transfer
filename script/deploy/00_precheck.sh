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

if [ -z "$CHAIN_ID" ]; then
    echo -e "\033[31mError:\033[0m CHAIN_ID not set. Please run 00_init.sh first."
    return 1 2>/dev/null || exit 1
fi

current_precheck_key="${network}|${RPC_URL}"

echo "========================================="
echo "Prechecking BatchTransfer Deployment"
echo "========================================="
echo "Network: $network"
echo "Network Dir: $network_dir"
echo "RPC_URL: $RPC_URL"

actual_chain_id=$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$actual_chain_id" ]; then
    echo -e "\033[31mError:\033[0m Failed to read chain id from RPC"
    return 1 2>/dev/null || exit 1
fi

if [ "$actual_chain_id" != "$CHAIN_ID" ]; then
    echo -e "\033[31mError:\033[0m RPC chain id mismatch"
    echo "  Expected: $CHAIN_ID"
    echo "  Actual:   $actual_chain_id"
    return 1 2>/dev/null || exit 1
fi
echo -e "\033[32m✓\033[0m RPC chain id matches: $actual_chain_id"

address_file="$network_dir/address.batch-transfer.params"
if [ -f "$address_file" ]; then
    source "$address_file"

    if [ -n "$batchTransferAddress" ]; then
        batch_transfer_code=$(cast code "$batchTransferAddress" --rpc-url "$RPC_URL" 2>/dev/null)
        if [ -n "$batch_transfer_code" ] && [ "$batch_transfer_code" != "0x" ]; then
            echo -e "\033[33mWarning:\033[0m Existing BatchTransfer deployment detected"
            echo "  BatchTransfer Address: $batchTransferAddress"

            if [ "$FORCE_REDEPLOY" != "1" ]; then
                echo -e "\033[31mError:\033[0m Refusing to redeploy while address.batch-transfer.params already points to live code"
                echo "Set FORCE_REDEPLOY=1 if you really want to replace it."
                return 1 2>/dev/null || exit 1
            fi

            echo -e "\033[33mWarning:\033[0m FORCE_REDEPLOY=1 set, continuing"
        else
            echo -e "\033[33mWarning:\033[0m Existing address.batch-transfer.params found, but no live code at that address"
        fi
    fi
fi

export BATCH_TRANSFER_PRECHECK_DONE=1
export BATCH_TRANSFER_PRECHECK_KEY="$current_precheck_key"
echo -e "\033[32m✓\033[0m BatchTransfer deployment precheck passed"
echo "========================================="
