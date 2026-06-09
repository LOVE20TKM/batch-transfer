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

echo "========================================="
echo "Verifying BatchTransfer Configuration"
echo "========================================="

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

echo -e "BatchTransfer Address: $batchTransferAddress\n"

batch_transfer_code=$(cast code "$batchTransferAddress" --rpc-url "$RPC_URL" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$batch_transfer_code" ] || [ "$batch_transfer_code" = "0x" ]; then
    echo -e "\033[31mError:\033[0m No contract code found at batchTransferAddress"
    return 1 2>/dev/null || exit 1
fi
echo -e "\033[32m✓\033[0m BatchTransfer contract code found"
echo ""

failed_checks=0

check_equal \
    "BatchTransfer: NATIVE_TRANSFER_GAS_LIMIT" \
    "50000" \
    "$(cast_call "$batchTransferAddress" "NATIVE_TRANSFER_GAS_LIMIT()(uint256)")"
[ $? -ne 0 ] && ((failed_checks++))
echo ""

echo "========================================="
if [ $failed_checks -eq 0 ]; then
    echo -e "\033[32m✓ All parameter checks passed (1/1)\033[0m"
    echo "========================================="
    return 0 2>/dev/null || exit 0
else
    echo -e "\033[31m✗ $failed_checks check(s) failed\033[0m"
    echo "========================================="
    return 1 2>/dev/null || exit 1
fi
