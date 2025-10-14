# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Rowan-Fi Lending Protocol

This document contains architecture, patterns, and development guidance for the Rowan-Fi lending protocol.

## Core Architecture

The protocol consists of multiple interconnected contract systems:

### Core Contracts
- **Config**: Central registry managing vault and position whitelisting
- **Vault**: ERC4626-compliant lending vaults with governance (ERC20Votes) and compound interest
- **MultiAssetPosition**: ERC721 position NFTs with multi-vault collateral/debt tracking
- **VaultGovernor**: Per-vault governance using OpenZeppelin Governor framework
- **Liquidator**: Handles position liquidations with configurable bonus rates

### Key Architecture Patterns
- **Non-Upgradeable Design**: All contracts use standard OpenZeppelin contracts with constructors (no upgradeable patterns)
- **Per-Vault Governance**: Each vault deploys its own VaultGovernor contract for decentralized interest rate control
- **Interest Accrual**: Continuous per-second compound interest using `InterestRate` library
- **Position Balance Model**: Positions track signed balances (positive = collateral, negative = debt)
- **Whitelist-Based Access**: Vaults whitelist contracts that can borrow funds

## Project Structure

```
src/
├── core/
│   ├── Config.sol              # Registry for vaults/positions
│   ├── Vault.sol               # ERC4626 + ERC20Votes + governance
│   └── Liquidator.sol          # Position liquidation logic
├── position/
│   ├── MultiAssetPosition.sol  # ERC721 position management
│   └── IPosition.sol           # Position interface
├── governance/
│   └── VaultGovernor.sol       # OpenZeppelin Governor implementation
├── oracle/
│   └── Oracle.sol              # Price oracle with signature verification
└── constants/
    └── InterestRate.sol        # Interest rate constants and calculations

test/
├── foundry/                    # Standard Foundry tests
│   ├── Base.t.sol             # Test base setup
│   ├── Vault.t.sol            # Vault functionality tests
│   ├── VaultVotes.t.sol       # Governance voting tests
│   └── VaultGovernor.t.sol    # Governor integration tests
└── echidna/                    # Fuzzing tests
    ├── VaultEchidna.sol       # Property-based fuzzing
    └── VaultAssertions.sol    # Assertion-based fuzzing
```

## Code Patterns & Conventions

### Import Organization

```solidity
// Standard pattern for imports (non-upgradeable)
import {ContractName} from "lib/openzeppelin-contracts/contracts/path/ContractName.sol";
import {LocalInterface} from "./LocalContract.sol";
```


### Access Control Modifiers

```solidity
modifier onlyVault(address _vToken) {
    require(IConfig(config).isVault(_vToken), "Only vault can call this function");
    _;
}

modifier onlyPosition(address _position) {
    require(IConfig(config).isPosition(_position), "Only position can call this function");
    _;
}

modifier onlyOwnerOf(uint256 _tokenId) {
    require(ownerOf(_tokenId) == msg.sender, "Only owner can call this function");
    _;
}
```

### Balance Type Checking Pattern

```solidity
enum BalanceType {
    NO_DEBT,
    NO_CREDIT,
    DEBT,
    CREDIT
}

modifier balanceCheck(uint256 _tokenId, address _vToken, BalanceType _balanceType) {
    int256 balance = balances[_tokenId][_vToken];

    if (_balanceType == BalanceType.NO_DEBT && balance < 0) revert HasDebt();
    if (_balanceType == BalanceType.NO_CREDIT && balance > 0) revert HasCredit();
    if (_balanceType == BalanceType.DEBT && balance >= 0) revert NoDebt();
    if (_balanceType == BalanceType.CREDIT && balance <= 0) revert NoCredit();
    _;
}
```

### Interest Rate Calculations

```solidity
// Using InterestRate library for compound interest
import {InterestRate} from "./constants/InterestRate.sol";

// Calculate interest over time
function lentAssets() public view returns (uint256) {
    uint duration = block.timestamp - lastUpdated;
    return InterestRate.calculatePrincipalPlusInterest(
        lentAmountStored,
        interestRatePerSecond,
        duration
    );
}

// Update state after interest accrual
function updateLentAmount(uint256 _amount, bool _add) private {
    lentAmountStored = _add ? lentAmountStored + _amount : lentAmountStored - _amount;
    lastUpdated = block.timestamp;
}
```

### ERC4626 Override Pattern

```solidity
contract Vault is ERC4626Upgradeable, Ownable2StepUpgradeable {
    // Override totalAssets to include lent assets with interest
    function totalAssets() public view override returns (uint256) {
        return super.totalAssets() + lentAssets();
    }
}
```

### EnumerableSet Usage

```solidity
using EnumerableSet for EnumerableSet.AddressSet;

EnumerableSet.AddressSet private vaults;

function addVault(address _vault) external onlyOwner {
    vaults.add(_vault);
}

function getVaults() external view returns (address[] memory) {
    return vaults.values();
}

function isVault(address _vault) external view returns (bool) {
    return vaults.contains(_vault);
}
```

### Position Data Structure

```solidity
struct Position {
    EnumerableSet.AddressSet vaults;  // Vaults this position interacts with
}

mapping(uint256 => Position) private positions;              // tokenId => position
mapping(uint256 => mapping(address => int256)) private balances; // (tokenId, vToken) => balance
mapping(address => uint) public reserves;                   // vToken => reserve
```

### Dead Shares Pattern for ERC4626

```solidity
uint constant NUMBER_OF_DEAD_SHARES = 1000;
address constant DEAD_ADDRESS = address(0x000000000000000000000000000000000000dEaD);

function initialize(address _asset, address _config) external initializer {
    __ERC4626_init(IERC20(_asset));
    _mint(DEAD_ADDRESS, NUMBER_OF_DEAD_SHARES); // Prevent donation attacks
    // ... rest of initialization
}
```

### Error Handling

```solidity
// Custom errors for gas efficiency
error HasDebt();
error HasCredit();
error NoDebt();
error NoCredit();

// Traditional require statements with descriptive messages
require(amount > 0, "Amount must be greater than 0");
require(ownerOf(_tokenId) == msg.sender, "Only owner can call this function");
```

## Testing Patterns

### Test Setup Pattern

```solidity
contract Setup is Test {
    // Deploy test setup with standardized contracts
    Config config;
    Position position;
    Vault vault;
    ERC20Mock token;

    function setUp() public {
        // Standard setup pattern
    }
}
```

## Development Commands

### Build & Test
```bash
# Build contracts
forge build

# Run all tests
forge test

# Run specific test file
forge test --match-path test/foundry/Vault.t.sol

# Run specific test function
forge test --match-test test_update_interest_rate

# Run tests with gas reporting
forge test --gas-report

# Format code
forge fmt
```

### Fuzzing with Echidna
```bash
# Install Echidna (macOS)
brew install echidna

# Run property-based fuzzing
echidna test/echidna/VaultEchidna.sol --contract VaultEchidna --config echidna.yaml

# Run assertion-based fuzzing (bug finding)
echidna test/echidna/VaultAssertions.sol --contract VaultAssertions --config echidna-assertions.yaml

# Extended fuzzing (production)
echidna test/echidna/VaultEchidna.sol --contract VaultEchidna --test-limit 50000 --timeout 3600
```

### Local Development
```bash
# Start local Anvil node
anvil

# Deploy to local node
forge script script/Vault.s.sol:VaultScript --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# Interact with contracts
cast call $VAULT_ADDRESS "totalAssets()(uint256)" --rpc-url http://localhost:8545
cast call $VAULT_ADDRESS "getVotes(address)(uint256)" $USER_ADDRESS --rpc-url http://localhost:8545
```

## Contract Deployment Order

1. Deploy Config contract
2. Deploy MultiAssetPosition with Config and Oracle addresses
3. Deploy Vault contracts (each creates its own VaultGovernor)
4. Register Position in Config via `setPosition()`
5. Register Vaults in Config via `addVault()`
6. Configure position liquidator and vault whitelisting

## Key Dependencies

- **OpenZeppelin Contracts**: Standard (non-upgradeable) implementations (ERC4626, ERC20Votes, Governor, etc.)
- **Forge-std**: Testing utilities and base test contracts
- **Echidna**: Property-based fuzzing for security testing

## Interest Rate Constants

Available in `InterestRate.sol`:

- `INTEREST_RATE_0_5` - 0.5% APY
- `INTEREST_RATE_5` - 5% APY
- `INTEREST_RATE_10` - 10% APY
- `INTEREST_RATE_15` - 15% APY (used by default in Vault)
- `INTEREST_RATE_20` - 20% APY
- Higher rates available up to 1000000000% APY

## Critical Architecture Details

### Governance Model
- **Per-Vault Governance**: Each vault has its own VaultGovernor contract
- **Dual Control Phase**: Initially owner-controlled, transitions to governance when vault has deposits
- **Interest Rate Control**: Vault token holders vote on interest rate changes
- **Voting Power**: Based on vault token (ERC20Votes) holdings with delegation support

### Position Management
- **Signed Balance System**: Positions track balances as signed integers (+ = collateral, - = debt)
- **Multi-Asset Support**: Single position can have collateral/debt across multiple vaults
- **Health Factor**: Based on oracle prices and liquidation thresholds
- **NFT Representation**: Each position is an ERC721 token

### Interest & Liquidation
- **Continuous Compound Interest**: Per-second calculation using `InterestRate.calculatePrincipalPlusInterest`
- **Interest Rate State Updates**: When rate changes, current interest is calculated and stored
- **Liquidation Bonuses**: Configurable per-position-contract, affects all connected vaults
- **Whitelist-Based Borrowing**: Only whitelisted contracts can borrow from vaults

### Security Features
- **Dead Shares Protection**: 1000 shares minted to dead address prevents inflation attacks
- **Reentrancy Guards**: All state-changing functions protected
- **Access Control**: Role-based permissions using OpenZeppelin patterns
- **Fuzzing Integration**: Echidna property-based testing for invariant verification

## Configuration Notes

- **Arbitrum Deployment**: Configured for Arbitrum mainnet (foundry.toml)
- **Solidity Version**: 0.8.22 with via-IR optimization enabled
- **Test Structure**: Separated into foundry/ and echidna/ directories
- **Non-Upgradeable**: Protocol converted from upgradeable to standard contracts for simplicity
