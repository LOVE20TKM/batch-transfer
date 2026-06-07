# Batch Transfer

Stateless utility contract for batch native-token transfers, batch ERC20 transfers, and batch balance queries.

## Scope

This repository contains one contract and its deployment scripts:

- `batchTransferNative(address[] recipients, uint256[] amounts)`
- `batchTransferERC20(address token, address[] recipients, uint256[] amounts)`
- `nativeBalances(address[] accounts)`
- `erc20Balances(address token, address[] accounts)`

The contract is intentionally simple:

- No owner
- No admin
- No upgradeability
- No custody

## Safety Model

- Transfers are atomic: one failed transfer reverts the whole batch.
- Native transfers require `msg.value == sum(amounts)`.
- Native transfers forward `NATIVE_TRANSFER_GAS_LIMIT` gas to each recipient.
- ERC20 transfers verify token code exists before interacting with the token.
- ERC20 transfers precheck sender balance and allowance before executing transfer calls.
- ERC20 transfers accept both standard boolean-return tokens and legacy no-return tokens.
- Zero recipients and zero transfer amounts are rejected.
- Transfer batches are capped at `MAX_TRANSFER_RECIPIENTS`.
- Balance query batches are capped at `MAX_BALANCE_ACCOUNTS`.

Some token-specific rules cannot be predicted generically, including blacklist logic, paused tokens, fee-on-transfer behavior, and custom recipient restrictions.

## Repository Hygiene

- Local secrets live in `script/network/<network>/.account` and are ignored by Git.
- Deployment outputs such as `broadcast/` and `script/network/<network>/address.*.params` are treated as local artifacts and are ignored by Git.
- If you want to publish canonical deployed addresses, put them in this README or release notes instead of committing local script output.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git submodules initialized for `forge-std`
- macOS if you want the deployment script to open a GUI password dialog through `osascript`

Clone with submodules, or initialize them after cloning:

```shell
git clone --recurse-submodules <repo-url>
```

```shell
git submodule update --init --recursive
```

## Development

```shell
forge fmt --check
forge build
forge test
```

## Deploy

1. Copy the account template for the target network.
2. Fill in your local keystore account metadata.
3. Run the one-click deploy script from the repository root.

```shell
cp script/network/<network>/.account.example script/network/<network>/.account
source script/deploy/one_click_deploy.sh <network>
```

The deploy flow will:

- Load `script/network/<network>/.account`
- Load `script/network/<network>/network.params`
- Ask for the keystore password through a hidden macOS dialog
- Run a precheck against the configured RPC
- Deploy `BatchTransfer`
- Verify on Thinkium networks
- Write the local deployment result to `script/network/<network>/address.batch-transfer.params`

For non-GUI execution, set `KEYSTORE_PASSWORD` and `KEYSTORE_PASSWORD_ACCOUNT` in the shell environment before running the script.
