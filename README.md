# Lending V2: Orderbook-Based Lending Protocol

A next-generation decentralized lending protocol featuring orderbook-based lending with automated liquidity pool integration.

## Architecture Overview

V2 introduces a hybrid system combining:
- **Direct P2P Trading**: Users can directly match lending orders
- **Automated LP Pools**: Liquidity providers deposit funds managed by keepers
- **Bot Matching**: Third-party bots (or any EOA) can match compatible orders
- **Dual NFT Positions**: Each executed deal creates separate NFTs for buyer and seller

## Core Contracts

### Core.sol
Main orderbook engine supporting P2P trading, bot-mediated matching, and liquidations.

**Key Functions:**
- `takeBid`: Execute a bid order
- `takeAsk`: Execute an ask order  
- `execute`: Bot-mediated order matching
- `repay`: Repay borrowed funds (anyone can repay)
- `withdrawCollateral`: Withdraw collateral (seller only)
- `liquidate`: Liquidate positions

### DealManager.sol
ERC721 contract managing executed lending agreements as dual NFTs (one for buyer, one for seller).

**Key Functions:**
- `createDeal`: Create new deal with dual NFTs
- `getDeal`: Retrieve deal details
- `getDealWithState`: Get deal with buyer/seller info
- `isBuyerNft`: Check if NFT represents buyer position (even token IDs)
- `isSellerNft`: Check if NFT represents seller position (odd token IDs)
- `getPairedTokenId`: Get the paired NFT ID for the same deal
- `getDealNumber`: Get deal number from token ID
- `getSellerTokenId`: Get seller NFT ID from deal number
- `getBuyerTokenId`: Get buyer NFT ID from deal number
- `updateDealState`: Update deal with accrued interest
- `burnDeal`: Burn both NFTs when deal is closed

### DealHookFactory.sol
Factory for managing deal hooks with efficient dual mapping.

**Key Functions:**
- `addDealHook`: Register new deal hook (owner only)
- `validateDealHook`: validates existence

### IDealHook Interface
Hooks for deal lifecycle events.

**Key Functions:**
- `NAME`: Hook identifier
- `onDealCreated`: Called when deal is created
- `onDealRepaid`: Called when deal is repaid
- `onDealCollateralWithdrawn`: Called when collateral is withdrawn
- `onDealLiquidated`: Called when deal is liquidated

### ILP Interface (To be implemented)
ERC4626-compliant liquidity pools with EIP-1271 contract signature support.

**Key Functions:**
- `bond`: View bond/reserve amount
- `interestRate`: Current interest rate
- `addCollateral`: Add collateral to deals
- `fee`: Fee percentage
- `minimumDealCheck`: Validate deal parameters
- `isKeeper`: Verify keeper authorization
- `isValidSignature`: EIP-1271 contract signing

## Data Structures

### Orders

#### Bid (Seller Order)
```solidity
struct Bid {
    address collateralToken;        // Token offered as collateral
    uint256 minCollateralAmount;   // Minimum collateral to provide
    address borrowToken;            // Token to borrow
    uint256 maxBorrowAmount;        // Maximum amount to borrow
    uint256 interestRateBid;        // Maximum interest rate willing to pay
    address dealHook;               // Deal hook contract address
    uint256 deadline;               // Order expiration timestamp
}
```

#### Ask (Buyer Order)
```solidity
struct Ask {
    address collateralToken;        // Required collateral token
    uint256 maxCollateralAmount;   // Maximum collateral to accept
    address borrowToken;            // Token to lend
    uint256 minBorrowAmount;        // Minimum amount to lend
    uint256 interestRateAsk;        // Minimum interest rate required
    address dealHook;               // Deal hook contract address
    uint256 deadline;               // Order expiration timestamp
}
```

### Deal (Executed Agreement)
```solidity
struct Deal {
    address collateralToken;        // Collateral token
    address borrowToken;            // Borrowed token
    uint256 collateralAmount;       // Actual collateral amount
    uint256 borrowAmount;           // Actual borrowed amount (includes accrued interest)
    uint256 interestRate;           // Agreed interest rate
    address dealHook;               // Deal hook contract address
}
```

### Deal State
```solidity
struct DealState {
    address buyer;                  // Buyer address
    address seller;                 // Seller address
    uint256 lastUpdated;            // Last interest update timestamp
}

struct DealWithState {
    Deal deal;                      // Deal details
    DealState state;                // Deal state with participants
}
```

### New Data Structures

#### BidWithAccountInfo & AskWithAccountInfo
```solidity
struct AccountInfo {
    address account;               // Order signer address
    uint nonce;                   // Account nonce for order invalidation
}

struct BidWithAccountInfo {
    Bid bid;                      // Bid order details
    AccountInfo accountInfo;      // Account and nonce info
}

struct AskWithAccountInfo {
    Ask ask;                      // Ask order details  
    AccountInfo accountInfo;      // Account and nonce info
}
```


## Trading Workflows

### 1. P2P Direct Trading
1. **Order Creation**: User signs bid/ask off-chain
2. **Order Taking**: Counterparty calls `takeBid()` or `takeAsk()`
3. **Execution**: Core validates signatures and creates deal
4. **Dual NFT Minting**: Deal contract mints separate NFTs for buyer and seller

### 2. LP Pool Trading
1. **Liquidity Provision**: Users deposit tokens into LP pools
2. **Keeper Management**: Authorized keepers monitor orderbook
3. **Profitable Execution**: Keepers take profitable bids using pool funds
4. **Yield Distribution**: Interest earnings distributed to LP token holders

### 3. Bot Matching
1. **Order Discovery**: Bots scan for compatible bid/ask pairs
2. **Matching Execution**: Bot calls `execute(bid, ask)` 
3. **Deal Creation**: Core validates both orders and creates deal with dual NFTs
4. **Fee Collection**: Bot may collect matching fees

### 4. Liquidation Process
1. **Deal Monitoring**: Anyone can monitor deal health and interest accrual
2. **Liquidation Execution**: Anyone calls `liquidate()` with repay and withdraw amounts
3. **Debt Repayment**: Liquidator repays part/all of the debt
4. **Collateral Seizure**: Liquidator withdraws collateral as compensation
5. **Position Update**: Deal state updated, NFTs burned if fully closed

## Signature Validation

### EOA Signatures
Standard ECDSA signature recovery for externally owned accounts.

### Contract Signatures (EIP-1271)
LP contracts implement `isValidSignature()` to enable:
- Keeper-authorized order signing
- Pre-approved order validation
- Custom authorization logic

Example LP signature validation:
```solidity
function isValidSignature(bytes32 hash, bytes memory signature) 
    external view returns (bytes4) {
    address signer = ECDSA.recover(hash, signature);
    if (isKeeper(signer) && isValidOrderHash(hash)) {
        return 0x1626ba7e; // EIP-1271 magic value
    }
    return 0xffffffff; // Invalid
}
```

## Deal Hook System

The `dealHook` field in orders and deals specifies which hook contract manages the deal lifecycle:

- **Hook Registration**: Deal hooks are registered via `DealHookFactory`
- **Lifecycle Events**: Hooks receive callbacks for deal creation, repayment, collateral withdrawal, and liquidation
- **Custom Logic**: Each hook can implement custom validation and management logic
- **Extensibility**: New deal types can be added by deploying new hook contracts

Example hooks:
- **BaseDealHook**: Abstract base contract providing common hook functionality
- **BasicDealHook**: Standard lending implementation with margin requirements
- **Custom Hooks**: Specialized lending products with unique terms

## Security Features

- **Deadline Protection**: All orders include expiration timestamps
- **Signature Verification**: ECDSA + EIP-1271 support for EOA and contract signatures
- **Nonce Management**: Order invalidation via nonce consumption
- **Access Controls**: Core-only access for deal management functions
- **Reentrancy Protection**: All external functions protected with ReentrancyGuard
- **Interest Accrual**: Automatic compound interest calculation with overflow protection
- **Hook Validation**: Deal hooks must be registered before use

## Integration Examples

### Creating a BidWithAccountInfo Order
```solidity
Bid memory bid = Bid({
    collateralToken: address(WETH),
    minCollateralAmount: 1 ether,
    borrowToken: address(USDC),
    maxBorrowAmount: 15000e6,
    interestRateBid: 500, // 5% per year
    dealHook: address(basicDealHook),
    deadline: block.timestamp + 7 days
});

BidWithAccountInfo memory bidWithAccountInfo = BidWithAccountInfo({
    bid: bid,
    accountInfo: AccountInfo({
        account: msg.sender,
        nonce: currentNonce
    })
});
```

### LP Pool Interaction
```solidity
// Deposit into LP
lpContract.deposit(1000e6, msg.sender);

// Keeper takes profitable bid
if (lpContract.isKeeper(msg.sender)) {
    lpContract.takeBid(profitableBidWithAccountInfo, signature);
}
```

## Future Enhancements

- **Order Books**: On-chain order book storage and management
- **Price Oracles**: Integration with Chainlink and other price feeds
- **Advanced Matching**: Partial order fills and advanced matching algorithms
- **Cross-Chain**: Support for cross-chain lending agreements
- **Governance**: DAO governance for protocol parameters

## Development Status

### ✅ Completed Components
- **Core.sol**: Complete orderbook engine with P2P trading, repayment, and liquidation
- **DealManager.sol**: ERC721 dual NFT system with efficient token management and deal burning
- **DealHookFactory.sol**: Hook registration system with gas-optimized lookups
- **OrderEncoder.sol**: Gas-optimized order encoding and hashing with inline assembly
- **NonceHandler.sol**: Nonce management for order invalidation
- **OrderSignatureVerifier.sol**: ECDSA and EIP-1271 signature validation
- **DeadlineHandler.sol**: Order expiration validation
- **DealHandler.sol**: Deal creation and validation logic
- **BaseDealHook.sol**: Abstract base contract for deal hooks
- **BasicDealHook.sol**: Standard lending hook implementation

### 🚧 In Progress
- **LP.sol**: ERC4626-compliant liquidity pools (next priority)

### 📋 Architecture Features
- **Dual NFT System**: Each deal creates separate buyer and seller NFTs
- **Hook-Based Extensibility**: Custom deal types via hook contracts
- **Gas Optimizations**: Inline assembly for keccak256 operations
- **Interest Accrual**: Automatic compound interest with overflow protection
- **Flexible Repayment**: Anyone can repay on behalf of sellers
- **Efficient Liquidation**: Combined repay + withdraw operations
- **Comprehensive Testing**: Full unit and fuzz test coverage for all components