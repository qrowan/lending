## Rowan-Fi Lending Protocol

A decentralized lending protocol built with Solidity and Foundry, featuring upgradeable smart contracts for lending, borrowing, and position management.

## Overview

This protocol consists of:

- **Config**: Central registry for positions and vaults
- **Vault**: ERC4626-compliant lending vaults with interest accrual
- **Position**: ERC721-based position management with collateral/debt tracking
- **Oracle**: Price oracle functionality
- **InterestRate**: Interest rate calculation library

## Prerequisites

- [Foundry](https://book.getfoundry.sh/) toolkit installed
- Git for dependency management

## Installation

```shell
# Clone the repository
git clone <repository-url>
cd lending

# Install dependencies
forge install

# Update git submodules
git submodule update --init --recursive
```

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

Deploy the protocol contracts:

```shell
# Deploy to testnet
forge script script/Vault.s.sol:VaultScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# For mainnet deployment, add --verify flag
forge script script/Vault.s.sol:VaultScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

### Development

Local development with Anvil:

```shell
# Start local node
anvil

# Deploy to local node (in another terminal)
forge script script/Vault.s.sol:VaultScript --rpc-url http://localhost:8545 --private-key <anvil_private_key> --broadcast
```

### Protocol Architecture

The lending protocol uses an upgradeable architecture:

1. **Config Contract**: Manages registered vaults and positions
2. **Vault Contracts**: ERC4626-compliant lending pools with compound interest
3. **Position Contract**: ERC721 NFTs representing user positions with collateral/debt tracking
4. **Interest Rate Library**: Provides per-second compound interest calculations

### Contract Interactions

```shell
# Example: Check vault total assets
cast call <VAULT_ADDRESS> "totalAssets()(uint256)" --rpc-url $RPC_URL

# Example: Get position data
cast call <POSITION_ADDRESS> "getPosition(uint256)(address[],int256[])" <TOKEN_ID> --rpc-url $RPC_URL
```

### Help

```shell
forge --help
anvil --help
cast --help
```

## Configuration

The protocol is configured for Arbitrum mainnet (see `foundry.toml`):

- RPC URL: https://arb1.arbitrum.io/rpc
- Solidity version: 0.8.22
- Optimizer enabled with 200 runs
- Via IR compilation enabled
