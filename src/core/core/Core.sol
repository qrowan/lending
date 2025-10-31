// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ICore, IBaseStructure, IDealHook, IDealHookFactory} from "../../interfaces/IAggregatedInterfaces.sol";
import {NonceHandler} from "./NonceHandler.sol";
import {OrderEncoder} from "../../libraries/OrderEncoder.sol";
import {OrderSignatureVerifier} from "../../libraries/OrderSignatureVerifier.sol";
import {DealHandler} from "../../libraries/DealHandler.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDealManager} from "../../interfaces/IAggregatedInterfaces.sol";
import {DeadlineHandler} from "./DeadlineHandler.sol";
import {InterestRateHandler} from "./InterestRateHandler.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract Core is ICore, NonceHandler, ReentrancyGuard, DeadlineHandler, InterestRateHandler {
    using ECDSA for bytes32;
    using OrderEncoder for *;
    using DealHandler for *;
    using SafeERC20 for IERC20;

    address dealManager;
    address dealHookFactory;

    constructor(address _dealManager, address _dealHookFactory) {
        dealHookFactory = _dealHookFactory;
        dealManager = _dealManager;
    }

    // Events
    event BidTaken(bytes32 indexed bidHash, address indexed taker, address indexed bidder);
    event AskTaken(bytes32 indexed askHash, address indexed taker, address indexed asker);
    event LoanRepaid(uint256 indexed dealNumber, address indexed repayer, uint256 repayAmount, uint256 remainingDebt);
    event Liquidated(
        uint256 indexed dealNumber, address indexed liquidator, uint256 repayAmount, uint256 withdrawAmount
    );
    event CollateralWithdrawn(
        uint256 indexed dealNumber, address indexed withdrawer, uint256 withdrawAmount, uint256 remainingCollateral
    );

    // Take bid function - seller wants to borrow, taker provides funds
    function takeBid(BidWithAccountInfo memory bidWithAccountInfo, bytes memory bidSignature)
        external
        nonReentrant
        DeadlineHandler.checkDeadline(bidWithAccountInfo.bid.deadline)
        InterestRateHandler.checkInterestRate(bidWithAccountInfo.bid.interestRateBid)
    {
        // msg.sender = borrower = seller = asker
        bytes32 bidHash = bidWithAccountInfo.bid.getHash();

        // Verify signature and get bidder
        address bidder =
            OrderSignatureVerifier.verifyOrderSignature(bidHash, bidSignature, bidWithAccountInfo.accountInfo.account);

        // Consume nonce
        _consumeNonce(bidder, bidWithAccountInfo.accountInfo.nonce);

        IBaseStructure.Deal memory deal = bidWithAccountInfo.bid.createDeal();

        // Execute bid-specific logic (to be implemented by inheriting contracts)
        _transferForDeal(deal, msg.sender, bidder);

        IDealManager(dealManager).createDeal(deal, bidder, msg.sender);
        IDealHookFactory(dealHookFactory).validateDealHook(deal.dealHook);
        IDealHook(deal.dealHook).onDealCreated(deal);

        emit BidTaken(bidHash, msg.sender, bidder);
        emit NonceConsumed(bidder, bidWithAccountInfo.accountInfo.nonce);
    }

    // Take ask function - buyer wants to lend, taker borrows funds
    function takeAsk(AskWithAccountInfo memory askWithAccountInfo, bytes memory askSignature)
        external
        nonReentrant
        DeadlineHandler.checkDeadline(askWithAccountInfo.ask.deadline)
        InterestRateHandler.checkInterestRate(askWithAccountInfo.ask.interestRateAsk)
    {
        // msg.sender = lender = buyer = bidder
        bytes32 askHash = askWithAccountInfo.ask.getHash();

        // Verify signature and get asker
        address asker =
            OrderSignatureVerifier.verifyOrderSignature(askHash, askSignature, askWithAccountInfo.accountInfo.account);

        // Consume nonce
        _consumeNonce(asker, askWithAccountInfo.accountInfo.nonce);

        IBaseStructure.Deal memory deal = askWithAccountInfo.ask.createDeal();

        // Execute ask-specific logic (to be implemented by inheriting contracts)
        _transferForDeal(deal, asker, msg.sender);

        IDealManager(dealManager).createDeal(deal, msg.sender, asker);
        IDealHookFactory(dealHookFactory).validateDealHook(deal.dealHook);
        IDealHook(deal.dealHook).onDealCreated(deal);

        emit AskTaken(askHash, msg.sender, asker);
        emit NonceConsumed(asker, askWithAccountInfo.accountInfo.nonce);
    }

    function _transferForDeal(Deal memory deal, address seller, address buyer) internal {
        IERC20(deal.collateralToken).safeTransferFrom(seller, address(this), deal.collateralAmount);
        IERC20(deal.borrowToken).safeTransferFrom(buyer, seller, deal.borrowAmount);
    }

    function execute(
        Deal memory deal,
        BidWithAccountInfo memory bidWithAccountInfo,
        bytes memory bidSignature,
        AskWithAccountInfo memory askWithAccountInfo,
        bytes memory askSignature
    )
        external
        DeadlineHandler.checkDeadline(bidWithAccountInfo.bid.deadline)
        DeadlineHandler.checkDeadline(askWithAccountInfo.ask.deadline)
        InterestRateHandler.checkInterestRate(bidWithAccountInfo.bid.interestRateBid)
        InterestRateHandler.checkInterestRate(askWithAccountInfo.ask.interestRateAsk)
    {
        bytes32 askHash = askWithAccountInfo.ask.getHash();

        // Verify signature and get asker
        address asker =
            OrderSignatureVerifier.verifyOrderSignature(askHash, askSignature, askWithAccountInfo.accountInfo.account);

        bytes32 bidHash = bidWithAccountInfo.bid.getHash();
        address bidder =
            OrderSignatureVerifier.verifyOrderSignature(bidHash, bidSignature, bidWithAccountInfo.accountInfo.account);

        deal.validateDeal(bidWithAccountInfo.bid);
        deal.validateDeal(askWithAccountInfo.ask);

        // Consume nonce
        _consumeNonce(asker, askWithAccountInfo.accountInfo.nonce);
        _consumeNonce(bidder, bidWithAccountInfo.accountInfo.nonce);

        // Execute bid-specific logic (to be implemented by inheriting contracts)
        _transferForDeal(deal, asker, bidder);

        IDealManager(dealManager).createDeal(deal, asker, bidder);

        emit BidTaken(bidHash, asker, bidder);
        emit AskTaken(askHash, asker, bidder);
        emit NonceConsumed(asker, askWithAccountInfo.accountInfo.nonce);
        emit NonceConsumed(bidder, bidWithAccountInfo.accountInfo.nonce);
    }

    function repay(uint256 dealNumber, uint256 repayAmount) external nonReentrant {
        _repay(dealNumber, repayAmount);
    }

    function _repay(uint256 dealNumber, uint256 repayAmount) internal {
        // Update deal state with accrued interest first
        DealWithState memory dealWithState = IDealManager(dealManager).updateDealState(dealNumber);

        Deal memory deal = dealWithState.deal;
        DealState memory state = dealWithState.state;

        // Calculate actual repayment amount (cannot exceed total debt)
        uint256 actualRepayAmount = Math.min(repayAmount, deal.borrowAmount);
        require(actualRepayAmount > 0, "Nothing to repay");

        // Transfer repayment from caller to buyer (buyer)
        IERC20(deal.borrowToken).safeTransferFrom(msg.sender, state.buyer, actualRepayAmount);

        // Update the deal's borrow amount (reduce debt)
        uint256 newBorrowAmount = deal.borrowAmount - actualRepayAmount;
        dealWithState = IDealManager(dealManager).updateBorrowAmount(dealNumber, newBorrowAmount);

        IDealHookFactory(dealHookFactory).validateDealHook(deal.dealHook);
        IDealHook(deal.dealHook).onDealRepaid(dealWithState.deal);

        emit LoanRepaid(dealNumber, msg.sender, actualRepayAmount, newBorrowAmount);
    }

    function withdrawCollateral(uint256 dealNumber, uint256 withdrawAmount) external nonReentrant {
        uint256 tokenId = IDealManager(dealManager).getSellerTokenId(dealNumber);
        require(msg.sender == IDealManager(dealManager).ownerOf(tokenId), "Not the seller");
        _withdrawCollateral(dealNumber, withdrawAmount);
        Deal memory deal = IDealManager(dealManager).getDeal(dealNumber);
        if (deal.collateralAmount == 0) {
            IDealManager(dealManager).burnDeal(dealNumber);
        }
    }

    function _withdrawCollateral(uint256 dealNumber, uint256 withdrawAmount) internal {
        // Update deal state with accrued interest first
        DealWithState memory dealWithState = IDealManager(dealManager).updateDealState(dealNumber);

        Deal memory deal = dealWithState.deal;

        // Calculate actual withdrawal amount (cannot exceed total collateral)
        uint256 actualWithdrawAmount = Math.min(withdrawAmount, deal.collateralAmount);
        require(actualWithdrawAmount > 0, "Nothing to withdraw");

        // Update the deal's collateral amount (reduce collateral)
        uint256 newCollateralAmount = deal.collateralAmount - actualWithdrawAmount;
        dealWithState = IDealManager(dealManager).updateCollateralAmount(dealNumber, newCollateralAmount);

        // transfer
        IERC20(deal.collateralToken).safeTransfer(msg.sender, actualWithdrawAmount);

        IDealHookFactory(dealHookFactory).validateDealHook(dealWithState.deal.dealHook);
        IDealHook(dealWithState.deal.dealHook).onDealCollateralWithdrawn(dealWithState.deal);

        // emit events
        emit CollateralWithdrawn(dealNumber, msg.sender, actualWithdrawAmount, newCollateralAmount);
    }

    function liquidate(uint256 dealNumber, uint256 repayAmount, uint256 withdrawAmount) external nonReentrant {
        DealWithState memory dealWithStateBefore = IDealManager(dealManager).updateDealState(dealNumber);

        _repay(dealNumber, repayAmount);
        _withdrawCollateral(dealNumber, withdrawAmount);

        DealWithState memory dealWithStateAfter = IDealManager(dealManager).updateDealState(dealNumber);

        IDealHookFactory(dealHookFactory).validateDealHook(dealWithStateBefore.deal.dealHook);
        IDealHook(dealWithStateBefore.deal.dealHook).onDealLiquidated(dealWithStateBefore.deal, dealWithStateAfter.deal);
        if (dealWithStateAfter.deal.collateralAmount == 0) {
            IDealManager(dealManager).burnDeal(dealNumber);
        }

        emit Liquidated(dealNumber, msg.sender, repayAmount, withdrawAmount);
    }
}
