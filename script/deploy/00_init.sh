#!/bin/bash

if [ -n "${ZSH_VERSION:-}" ]; then
    SCRIPT_PATH="$0"
elif [ -n "${BASH_VERSION:-}" ]; then
    SCRIPT_PATH="${BASH_SOURCE[0]}"
else
    SCRIPT_PATH="$0"
fi

SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
NETWORK_ROOT="$(cd "$SCRIPT_DIR/../network" && pwd)"

# ------ set network ------
export network=$1
if [ -z "$network" ] || [ ! -d "$NETWORK_ROOT/$network" ]; then
    echo -e "\033[31mError:\033[0m Network parameter is required."
    echo -e "\nAvailable networks:"
    for net in "$NETWORK_ROOT"/*; do
        [ -d "$net" ] && echo "  - $(basename "$net")"
    done
    return 1 2>/dev/null || exit 1
fi

echo -e "Selected network: \033[36m$network\033[0m"

# ------ dont change below ------
export network_dir="$NETWORK_ROOT/$network"

if [ ! -f "$network_dir/.account" ]; then
    echo -e "\033[31mError:\033[0m .account file not found"
    echo "Please create $network_dir/.account with KEYSTORE_ACCOUNT and ACCOUNT_ADDRESS"
    return 1 2>/dev/null || exit 1
fi

source "$network_dir/.account" && source "$network_dir/network.params"

# ------ Request keystore password ------
request_keystore_password() {
    if [ -n "$KEYSTORE_PASSWORD" ] && [ "$KEYSTORE_PASSWORD_ACCOUNT" = "$KEYSTORE_ACCOUNT" ]; then
        return 0
    fi

    unset KEYSTORE_PASSWORD
    unset KEYSTORE_PASSWORD_ACCOUNT

    if ! command -v osascript >/dev/null 2>&1; then
        echo -e "\033[31mError:\033[0m osascript not found, cannot open password dialog"
        echo "Set KEYSTORE_PASSWORD and KEYSTORE_PASSWORD_ACCOUNT in the environment if you need non-GUI execution."
        return 1
    fi

    local escaped_keystore_account
    escaped_keystore_account=$(printf '%s' "$KEYSTORE_ACCOUNT" | sed 's/\\/\\\\/g; s/"/\\"/g')

    KEYSTORE_PASSWORD="$(osascript -l JavaScript <<JAVASCRIPT
const app = Application.currentApplication();
app.includeStandardAdditions = true;
app.displayDialog("Enter keystore password for $escaped_keystore_account:", {
    defaultAnswer: "",
    hiddenAnswer: true,
    buttons: ["Cancel", "OK"],
    defaultButton: "OK",
}).textReturned;
JAVASCRIPT
)"
    local dialog_status=$?

    if [ $dialog_status -ne 0 ] || [ -z "$KEYSTORE_PASSWORD" ]; then
        echo -e "\033[31mError:\033[0m Keystore password input cancelled"
        return 1
    fi

    export KEYSTORE_PASSWORD
    export KEYSTORE_PASSWORD_ACCOUNT="$KEYSTORE_ACCOUNT"
    echo "Password captured from dialog, will not be requested again in this session"
}

request_keystore_password || return 1 2>/dev/null || exit 1

cast_call() {
    local address=$1
    local function_signature=$2
    shift 2
    local args=("$@")

    cast call "$address" "$function_signature" "${args[@]}" --rpc-url "$RPC_URL"
}
echo "cast_call() loaded"

check_equal() {
    local description="$1"
    local expected="$2"
    local actual="$3"

    expected=$(echo "$expected" | tr '[:upper:]' '[:lower:]')
    actual=$(echo "$actual" | tr '[:upper:]' '[:lower:]')

    if [ "$expected" = "$actual" ]; then
        echo -e "\033[32m✓\033[0m $description"
        echo -e "  Expected: $expected"
        echo -e "  Actual:   $actual"
        return 0
    else
        echo -e "\033[31m✗\033[0m $description"
        echo -e "  Expected: $expected"
        echo -e "  Actual:   $actual"
        return 1
    fi
}
echo "check_equal() loaded"

forge_script() {
    forge script "$@" \
        --rpc-url "$RPC_URL" \
        --account "$KEYSTORE_ACCOUNT" \
        --sender "$ACCOUNT_ADDRESS" \
        --password "$KEYSTORE_PASSWORD" \
        --gas-price 5000000000 \
        --gas-limit 1500000 \
        --broadcast \
        --legacy \
        $([[ "$network" != "anvil" ]] && [[ "$network" != thinkium* ]] && echo "--verify --etherscan-api-key $ETHERSCAN_API_KEY")
}
echo "forge_script() loaded"
