// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {DealHandler} from "src/v2/libraries/DealHandler.sol";
import {IBaseStructure} from "src/v2/interfaces/IAggregatedInterfaces.sol";
import {InterestRate} from "src/constants/InterestRate.sol";
import {MockDealHook} from "../dealhookfactory/DealHookFactoryUnit.t.sol";

contract DealHandlerTest is Test {
    using DealHandler for *;

    IBaseStructure.Bid internal baseBid;
    IBaseStructure.Ask internal baseAsk;
    IBaseStructure.Deal internal baseDeal;
    MockDealHook internal mockHook;

    function setUp() public {
        mockHook = new MockDealHook("TestDealHook");

        baseBid = IBaseStructure.Bid({
            collateralToken: address(0x1),
            minCollateralAmount: 99,
            borrowToken: address(0x2),
            maxBorrowAmount: 201,
            interestRateBid: InterestRate.INTEREST_RATE_5,
            dealHook: address(mockHook),
            deadline: 1000
        });

        baseAsk = IBaseStructure.Ask({
            collateralToken: address(0x1),
            maxCollateralAmount: 101,
            borrowToken: address(0x2),
            minBorrowAmount: 199,
            interestRateAsk: InterestRate.INTEREST_RATE_15,
            dealHook: address(mockHook),
            deadline: 1000
        });

        baseDeal = IBaseStructure.Deal({
            collateralToken: address(0x1),
            borrowToken: address(0x2),
            collateralAmount: 101,
            borrowAmount: 199,
            interestRate: InterestRate.INTEREST_RATE_10,
            dealHook: address(mockHook)
        });
    }

    // 1. Deal Creation Tests
    function test_CreateDeal_Succeeds_WhenCalledWithValidBid() public view {
        IBaseStructure.Deal memory deal = baseBid.createDeal();

        assertEq(deal.collateralToken, baseBid.collateralToken);
        assertEq(deal.collateralAmount, baseBid.minCollateralAmount);
        assertEq(deal.borrowToken, baseBid.borrowToken);
        assertEq(deal.borrowAmount, baseBid.maxBorrowAmount);
        assertEq(deal.interestRate, baseBid.interestRateBid);
        assertEq(deal.dealHook, baseBid.dealHook);
    }

    function test_CreateDeal_Succeeds_WhenCalledWithValidAsk() public view {
        IBaseStructure.Deal memory deal = baseAsk.createDeal();

        assertEq(deal.collateralToken, baseAsk.collateralToken);
        assertEq(deal.collateralAmount, baseAsk.maxCollateralAmount);
        assertEq(deal.borrowToken, baseAsk.borrowToken);
        assertEq(deal.borrowAmount, baseAsk.minBorrowAmount);
        assertEq(deal.interestRate, baseAsk.interestRateAsk);
        assertEq(deal.dealHook, baseAsk.dealHook);
    }

    // 2. Deal Validation Success Tests

    function test_ValidateDeal_Succeeds_WhenBidDealIsValid() public view {
        DealHandler.validateDeal(baseDeal, baseBid);
    }

    function test_ValidateDeal_Succeeds_WhenAskDealIsValid() public view {
        DealHandler.validateDeal(baseDeal, baseAsk);
    }

    // 3. Deal Validation Error Tests

    function validateDealWrapperBid(IBaseStructure.Deal memory deal, IBaseStructure.Bid memory bid) external pure {
        DealHandler.validateDeal(deal, bid);
    }

    function test_RevertIf_BidCollateralTokenMismatch() public {
        IBaseStructure.Deal memory fakeDeal = baseDeal;
        fakeDeal.collateralToken = address(0x999);
        vm.expectRevert(abi.encodeWithSelector(DealHandler.DealValidationFailed.selector, true, uint256(1)));
        this.validateDealWrapperBid(fakeDeal, baseBid);
    }

    function test_RevertIf_ValidateBidBorrowTokenMismatch() public {
        IBaseStructure.Deal memory fakeDeal = baseDeal;
        fakeDeal.borrowToken = address(0x999);

        vm.expectRevert(abi.encodeWithSelector(DealHandler.DealValidationFailed.selector, true, uint256(2)));
        this.validateDealWrapperBid(fakeDeal, baseBid);
    }

    function test_RevertIf_ValidateBidDealHookMismatch() public {
        IBaseStructure.Deal memory fakeDeal = baseDeal;
        fakeDeal.dealHook = address(0x999);

        vm.expectRevert(abi.encodeWithSelector(DealHandler.DealValidationFailed.selector, true, uint256(6)));
        this.validateDealWrapperBid(fakeDeal, baseBid);
    }

    function test_RevertIf_ValidateBidCollateralAmountMismatch() public {
        IBaseStructure.Deal memory fakeDeal = baseDeal;
        fakeDeal.collateralAmount = 98;

        vm.expectRevert(abi.encodeWithSelector(DealHandler.DealValidationFailed.selector, true, uint256(3)));
        this.validateDealWrapperBid(fakeDeal, baseBid);
    }

    function test_RevertIf_ValidateBidBorrowAmountMismatch() public {
        IBaseStructure.Deal memory fakeDeal = baseDeal;
        fakeDeal.borrowAmount = 202;

        vm.expectRevert(abi.encodeWithSelector(DealHandler.DealValidationFailed.selector, true, uint256(4)));
        this.validateDealWrapperBid(fakeDeal, baseBid);
    }

    function test_RevertIf_ValidateBidInterestRateMismatch() public {
        IBaseStructure.Deal memory fakeDeal = baseDeal;
        fakeDeal.interestRate = InterestRate.INTEREST_RATE_0_5;

        vm.expectRevert(abi.encodeWithSelector(DealHandler.DealValidationFailed.selector, true, uint256(5)));
        this.validateDealWrapperBid(fakeDeal, baseBid);
    }

    // 4. Ask Validation Error Tests
    function validateDealWrapperAsk(IBaseStructure.Deal memory deal, IBaseStructure.Ask memory ask) external pure {
        DealHandler.validateDeal(deal, ask);
    }

    function test_RevertIf_ValidateAskCollateralTokenMismatch() public {
        IBaseStructure.Deal memory fakeDeal = baseDeal;
        fakeDeal.collateralToken = address(0x999);

        vm.expectRevert(abi.encodeWithSelector(DealHandler.DealValidationFailed.selector, false, uint256(1)));
        this.validateDealWrapperAsk(fakeDeal, baseAsk);
    }

    function test_RevertIf_ValidateAskBorrowTokenMismatch() public {
        IBaseStructure.Deal memory fakeDeal = baseDeal;
        fakeDeal.borrowToken = address(0x999);

        vm.expectRevert(abi.encodeWithSelector(DealHandler.DealValidationFailed.selector, false, uint256(2)));
        this.validateDealWrapperAsk(fakeDeal, baseAsk);
    }

    function test_RevertIf_ValidateAskDealHookMismatch() public {
        IBaseStructure.Deal memory fakeDeal = baseDeal;
        fakeDeal.dealHook = address(0x999);

        vm.expectRevert(abi.encodeWithSelector(DealHandler.DealValidationFailed.selector, false, uint256(6)));
        this.validateDealWrapperAsk(fakeDeal, baseAsk);
    }

    function test_RevertIf_ValidateAskCollateralAmountMismatch() public {
        IBaseStructure.Deal memory fakeDeal = baseDeal;
        fakeDeal.collateralAmount = 102;

        vm.expectRevert(abi.encodeWithSelector(DealHandler.DealValidationFailed.selector, false, uint256(3)));
        this.validateDealWrapperAsk(fakeDeal, baseAsk);
    }

    function test_RevertIf_ValidateAskBorrowAmountMismatch() public {
        IBaseStructure.Deal memory fakeDeal = baseDeal;
        fakeDeal.borrowAmount = 198;

        vm.expectRevert(abi.encodeWithSelector(DealHandler.DealValidationFailed.selector, false, uint256(4)));
        this.validateDealWrapperAsk(fakeDeal, baseAsk);
    }

    function test_RevertIf_ValidateAskInterestRateMismatch() public {
        IBaseStructure.Deal memory fakeDeal = baseDeal;
        fakeDeal.interestRate = InterestRate.INTEREST_RATE_20;

        vm.expectRevert(abi.encodeWithSelector(DealHandler.DealValidationFailed.selector, false, uint256(5)));
        this.validateDealWrapperAsk(fakeDeal, baseAsk);
    }
}
