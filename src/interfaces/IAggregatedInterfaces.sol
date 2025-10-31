// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";

interface IBaseStructure {
    struct Deal {
        address collateralToken;
        address borrowToken;
        uint256 collateralAmount;
        uint256 borrowAmount;
        uint256 interestRate;
        address dealHook;
    }

    struct DealWithState {
        Deal deal;
        DealState state;
    }

    struct DealState {
        address buyer;
        address seller;
        uint256 lastUpdated;
    }

    struct AssetManagement {
        address vault;
        bytes4 depositMethod;
        bytes4 withdrawMethod;
    }

    struct AccountInfo {
        address account;
        uint256 nonce;
    }

    struct Bid {
        address collateralToken;
        uint256 minCollateralAmount;
        address borrowToken;
        uint256 maxBorrowAmount;
        uint256 interestRateBid;
        address dealHook;
        uint256 deadline;
    }

    struct Ask {
        address collateralToken;
        uint256 maxCollateralAmount;
        address borrowToken;
        uint256 minBorrowAmount;
        uint256 interestRateAsk;
        address dealHook;
        uint256 deadline;
    }

    struct BidWithAccountInfo {
        Bid bid;
        AccountInfo accountInfo;
    }

    struct AskWithAccountInfo {
        Ask ask;
        AccountInfo accountInfo;
    }
}

interface INonceHandlerError {
    event NonceConsumed(address indexed user, uint256 indexed nonce);
    error WrongNonce(address user, uint256 nonce);
}

interface INonceHandler is INonceHandlerError {
    function consumeNonce(uint256 targetNonce) external;
    function getCurrentNonce(address user) external view returns (uint256);
}

interface IDealManager is IERC721, IBaseStructure {
    function createDeal(Deal memory deal, address buyer, address seller)
        external
        returns (uint256 dealNumber, uint256 buyerTokenId, uint256 sellerTokenId);

    function updateDealState(uint256 dealNumber) external returns (DealWithState memory);
    function updateBorrowAmount(uint256 dealNumber, uint256 newBorrowAmount) external returns (DealWithState memory);
    function updateCollateralAmount(uint256 dealNumber, uint256 newCollateralAmount)
        external
        returns (DealWithState memory);

    function getDeal(uint256 dealNumber) external view returns (Deal memory);

    function getDealWithState(uint256 dealNumber) external view returns (DealWithState memory);

    function getDealWithTokenId(uint256 tokenId) external view returns (Deal memory);

    function getDealWithTokenIdWithAccounts(uint256 tokenId) external view returns (DealWithState memory);

    // NFT type identification
    function isBuyerNft(uint256 tokenId) external view returns (bool);
    function isSellerNft(uint256 tokenId) external view returns (bool);

    // Get paired NFT ID
    function getPairedTokenId(uint256 tokenId) external view returns (uint256);

    // Get deal number from token ID
    function getDealNumber(uint256 tokenId) external view returns (uint256);

    function getSellerTokenId(uint256 dealNumber) external view returns (uint256);
    function getBuyerTokenId(uint256 dealNumber) external view returns (uint256);
    function burnDeal(uint256 dealNumber) external;
}

interface ILiquidator is IBaseStructure {
    function liquidate(uint256 dealNumber, uint256 repayAmount) external;
}

interface ICore is INonceHandler, IBaseStructure {
    // borrow. sell. pay interest.
    function takeBid(BidWithAccountInfo memory bidWithAccountInfo, bytes memory bidSignature) external;

    // lend. buy. get interest.
    function takeAsk(AskWithAccountInfo memory askWithAccountInfo, bytes memory askSignature) external;

    // execute a pair of bid and ask.
    function execute(
        Deal memory deal,
        BidWithAccountInfo memory bidWithAccountInfo,
        bytes memory bidSignature,
        AskWithAccountInfo memory askWithAccountInfo,
        bytes memory askSignature
    ) external;

    function repay(uint256 dealNumber, uint256 repayAmount) external;
}

interface ILP is IERC4626, IBaseStructure, IERC1271 {
    // LP allows multiple users to deposit funds and keepers to take profitable bids for operation. Customized LPs should be able to implement this freely.
    function bond() external view returns (uint256);
    function interestRate() external view returns (uint256); // read-only view
    function addCollateral(Deal memory deal, uint256 collateralAmount) external;
    function fee() external view returns (uint256);
    function minimumDealCheck(Deal memory deal) external view returns (bool);
    function isKeeper(address keeper) external view returns (bool);
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}

interface IDealHookFactory {
    function addDealHook(address dealHook) external;
    function validateDealHook(address dealHook) external;
}

interface IDealHook is IBaseStructure {
    function name() external view returns (string memory);
    function onDealCreated(Deal memory dealAfter) external;
    function onDealCollateralWithdrawn(Deal memory dealAfter) external;
    function onDealRepaid(Deal memory dealAfter) external;
    function onDealLiquidated(Deal memory dealBefore, Deal memory dealAfter) external;
}
