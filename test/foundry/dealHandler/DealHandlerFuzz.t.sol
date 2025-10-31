// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {DealHandler} from "src/libraries/DealHandler.sol";
import {IBaseStructure} from "src/interfaces/IAggregatedInterfaces.sol";
import {InterestRate} from "src/constants/InterestRate.sol";

contract DealHandlerTest is Test {
    using DealHandler for *;

    IBaseStructure.Bid internal baseBid;
    IBaseStructure.Ask internal baseAsk;
    IBaseStructure.Deal internal baseDeal;

    function setUp() public {
        baseBid = IBaseStructure.Bid({
            collateralToken: address(0x1),
            minCollateralAmount: 99,
            borrowToken: address(0x2),
            maxBorrowAmount: 201,
            interestRateBid: InterestRate.INTEREST_RATE_5,
            dealHook: address(0x3),
            deadline: 1000
        });

        baseAsk = IBaseStructure.Ask({
            collateralToken: address(0x1),
            maxCollateralAmount: 101,
            borrowToken: address(0x2),
            minBorrowAmount: 199,
            interestRateAsk: InterestRate.INTEREST_RATE_15,
            dealHook: address(0x3),
            deadline: 1000
        });

        baseDeal = IBaseStructure.Deal({
            collateralToken: address(0x1),
            borrowToken: address(0x2),
            collateralAmount: 101,
            borrowAmount: 199,
            interestRate: InterestRate.INTEREST_RATE_10,
            dealHook: address(0x3)
        });
    }

    function testFuzz_CreateDealFromBid_WorksCorrectly(
        address collateralToken,
        uint256 minCollateralAmount,
        address borrowToken,
        uint256 maxBorrowAmount,
        uint256 interestRateBid,
        address dealHook,
        uint256 deadline
    ) public pure {
        IBaseStructure.Bid memory bid = IBaseStructure.Bid({
            collateralToken: collateralToken,
            minCollateralAmount: minCollateralAmount,
            borrowToken: borrowToken,
            maxBorrowAmount: maxBorrowAmount,
            interestRateBid: interestRateBid,
            dealHook: dealHook,
            deadline: deadline
        });

        IBaseStructure.Deal memory deal = bid.createDeal();

        assertEq(deal.collateralToken, bid.collateralToken);
        assertEq(deal.collateralAmount, bid.minCollateralAmount);
        assertEq(deal.borrowToken, bid.borrowToken);
        assertEq(deal.borrowAmount, bid.maxBorrowAmount);
        assertEq(deal.interestRate, bid.interestRateBid);
        assertEq(deal.dealHook, bid.dealHook);
    }

    function testFuzz_CreateDealFromAsk_WorksCorrectly(
        address collateralToken,
        uint256 maxCollateralAmount,
        address borrowToken,
        uint256 minBorrowAmount,
        uint256 interestRateAsk,
        address dealHook,
        uint256 deadline
    ) public pure {
        IBaseStructure.Ask memory ask = IBaseStructure.Ask({
            collateralToken: collateralToken,
            maxCollateralAmount: maxCollateralAmount,
            borrowToken: borrowToken,
            minBorrowAmount: minBorrowAmount,
            interestRateAsk: interestRateAsk,
            dealHook: dealHook,
            deadline: deadline
        });

        IBaseStructure.Deal memory deal = ask.createDeal();

        assertEq(deal.collateralToken, ask.collateralToken);
        assertEq(deal.collateralAmount, ask.maxCollateralAmount);
        assertEq(deal.borrowToken, ask.borrowToken);
        assertEq(deal.borrowAmount, ask.minBorrowAmount);
        assertEq(deal.interestRate, ask.interestRateAsk);
        assertEq(deal.dealHook, ask.dealHook);
    }
}
