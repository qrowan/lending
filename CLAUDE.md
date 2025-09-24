# Claude Code Patterns - Rowan-Fi Lending Protocol

This document contains code patterns and conventions for the Rowan-Fi lending protocol to help Claude Code assist with development.

## Project Structure

```
src/
├── Config.sol                    # Central registry for positions and vaults
├── Vault.sol                   # ERC4626 lending vault implementation
├── Position.sol                # ERC721 position management with collateral/debt tracking
├── Oracle.sol                  # Price oracle functionality
└── constants/
    └── InterestRate.sol         # Interest rate calculations and constants
test/
├── Setup.t.sol                 # Test setup and utilities
├── Vault.t.sol                 # Vault contract tests
├── Position.t.sol              # Position contract tests
├── Oracle.t.sol                # Oracle contract tests
└── TestUtils.sol               # Test helper functions
script/
└── Vault.s.sol                 # Deployment script
```

## Code Patterns & Conventions

### Import Organization

```solidity
// Standard pattern for imports
import {ContractName} from "openzeppelin-contracts-upgradeable/contracts/path/ContractName.sol";
import {LibraryName} from "openzeppelin-contracts/contracts/path/LibraryName.sol";
import {LocalInterface} from "./LocalContract.sol";
```

### Upgradeable Contract Pattern

```solidity
contract ContractName is ContractUpgradeable, Ownable2StepUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(address param) external initializer {
        __ContractName_init(param);
        __Ownable_init(msg.sender);
    }
}
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

## Build & Test Commands

```bash
# Build contracts
forge build

# Run tests
forge test

# Run tests with gas reporting
forge test --gas-report

# Run specific test
forge test --match-test testFunctionName

# Format code
forge fmt

# Deploy script
forge script script/Vault.s.sol:VaultScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## Contract Deployment Order

1. Deploy Config contract
2. Deploy Position contract with Config address
3. Deploy Vault contracts with asset and Config addresses
4. Register Position in Config via `setPosition()`
5. Register Vaults in Config via `addVault()`

## Key Dependencies

- OpenZeppelin Contracts (Upgradeable): For upgradeable contract patterns
- OpenZeppelin Contracts: For standard implementations
- Forge-std: For testing utilities

## Interest Rate Constants

Available in `InterestRate.sol`:

- `INTEREST_RATE_0_5` - 0.5% APY
- `INTEREST_RATE_5` - 5% APY
- `INTEREST_RATE_10` - 10% APY
- `INTEREST_RATE_15` - 15% APY (used by default in Vault)
- `INTEREST_RATE_20` - 20% APY
- Higher rates available up to 1000000000% APY

## Architecture Notes

- All contracts are upgradeable using OpenZeppelin's upgradeable contracts
- Position balances can be positive (credit/collateral) or negative (debt)
- Vaults accrue interest continuously using per-second compound interest
- Config contract acts as registry and access control for the protocol
