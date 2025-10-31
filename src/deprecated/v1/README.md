## Rowan-Fi Lending Protocol

A decentralized lending protocol built with Solidity and Foundry, featuring governance-enabled vaults, multi-asset positions, and continuous compound interest.

## Overview

This protocol consists of:

- **Config**: Central registry for positions and vaults
- **Vault**: ERC4626-compliant lending vaults with governance (ERC20Votes) and per-second compound interest
- **VaultGovernor**: OpenZeppelin Governor contracts for per-vault governance
- **MultiAssetPosition**: ERC721-based position management with multi-vault collateral/debt tracking
- **Liquidator**: Position liquidation with configurable bonus rates
- **Oracle**: Price oracle with signature verification
- **InterestRate**: Interest rate calculation library with per-second compounding

## Prerequisites

- [Foundry](https://book.getfoundry.sh/) toolkit installed
- [Echidna](https://github.com/crytic/echidna) for fuzzing (optional)
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
# Run all tests
$ forge test

# Run specific test file
$ forge test --match-path test/foundry/Vault.t.sol

# Run specific test function
$ forge test --match-test test_update_interest_rate

# Run tests with gas reporting
$ forge test --gas-report
```

### Fuzzing with Echidna

```shell
# Install Echidna (macOS)
$ brew install echidna

# Run property-based fuzzing
$ echidna test/echidna/VaultEchidna.sol --contract VaultEchidna --config echidna.yaml

# Run assertion-based fuzzing (bug finding)
$ echidna test/echidna/VaultAssertions.sol --contract VaultAssertions --config echidna-assertions.yaml
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

The lending protocol features a non-upgradeable, governance-enabled architecture:

1. **Config Contract**: Central registry managing vault and position whitelisting
2. **Vault Contracts**: ERC4626 + ERC20Votes lending pools with per-vault governance
3. **VaultGovernor Contracts**: OpenZeppelin Governor for each vault (interest rate control)
4. **MultiAssetPosition Contract**: ERC721 NFTs with multi-vault collateral/debt tracking
5. **Liquidator Contract**: Handles position liquidations with configurable bonus rates
6. **Oracle Contract**: Price oracle with cryptographic signature verification
7. **Interest Rate Library**: Per-second compound interest calculations

### Contract Interactions

```shell
# Vault interactions
cast call <VAULT_ADDRESS> "totalAssets()(uint256)" --rpc-url $RPC_URL
cast call <VAULT_ADDRESS> "interestRatePerSecond()(uint256)" --rpc-url $RPC_URL
cast call <VAULT_ADDRESS> "getVotes(address)(uint256)" <USER_ADDRESS> --rpc-url $RPC_URL

# Position interactions
cast call <POSITION_ADDRESS> "getPosition(uint256)(address[],int256[])" <TOKEN_ID> --rpc-url $RPC_URL
cast call <POSITION_ADDRESS> "healthFactor(uint256)(uint256)" <TOKEN_ID> --rpc-url $RPC_URL

# Governance interactions
cast call <GOVERNOR_ADDRESS> "proposalThreshold()(uint256)" --rpc-url $RPC_URL
cast call <GOVERNOR_ADDRESS> "votingPeriod()(uint256)" --rpc-url $RPC_URL
```

### Help

```shell
forge --help
anvil --help
cast --help
```

## Configuration

The protocol is configured for Arbitrum mainnet (see `foundry.toml`):

- **RPC URL**: https://arb1.arbitrum.io/rpc  
- **Solidity Version**: 0.8.22
- **Optimizer**: Enabled with 200 runs
- **Via IR**: Enabled for better optimization
- **Architecture**: Non-upgradeable contracts with governance
- **Testing**: Foundry + Echidna fuzzing integration

## Key Features

- **Per-Vault Governance**: Each vault has its own governance contract
- **Continuous Interest**: Per-second compound interest accrual
- **Multi-Asset Positions**: Single NFT can hold collateral/debt across multiple vaults
- **Flexible Liquidations**: Configurable bonus rates and partial liquidations
- **Security Testing**: Comprehensive Echidna fuzzing for invariant verification
- **Gas Optimized**: Via-IR compilation and optimized contract patterns
