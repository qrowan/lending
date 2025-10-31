// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IBaseStructure} from "../interfaces/IAggregatedInterfaces.sol";

library DealHandler {
    enum DealError {
        ValidDeal, // 0
        CollateralTokenMismatch, // 1
        BorrowTokenMismatch, // 2
        CollateralAmountMismatch, // 3
        BorrowAmountMismatch, // 4
        InterestRateMismatch, // 5
        DealHookMismatch // 6
    }

    error DealValidationFailed(bool isFromBid, DealError error);

    function createDeal(IBaseStructure.Bid memory bid) internal pure returns (IBaseStructure.Deal memory) {
        // taking bid. use bid's minimum condition.
        return IBaseStructure.Deal({
            collateralToken: bid.collateralToken,
            borrowToken: bid.borrowToken,
            collateralAmount: bid.minCollateralAmount,
            borrowAmount: bid.maxBorrowAmount,
            interestRate: bid.interestRateBid,
            dealHook: bid.dealHook
        });
    }

    function createDeal(IBaseStructure.Ask memory ask) internal pure returns (IBaseStructure.Deal memory) {
        // taking ask. use ask's minimum condition.
        return IBaseStructure.Deal({
            collateralToken: ask.collateralToken,
            borrowToken: ask.borrowToken,
            collateralAmount: ask.maxCollateralAmount,
            borrowAmount: ask.minBorrowAmount,
            interestRate: ask.interestRateAsk,
            dealHook: ask.dealHook
        });
    }

    function validateDeal(IBaseStructure.Deal memory deal, IBaseStructure.Bid memory bid) internal pure {
        DealError error = _validateDeal(deal, bid);
        if (error != DealError.ValidDeal) revert DealValidationFailed(true, error);
    }

    function validateDeal(IBaseStructure.Deal memory deal, IBaseStructure.Ask memory ask) internal pure {
        DealError error = _validateDeal(deal, ask);
        if (error != DealError.ValidDeal) revert DealValidationFailed(false, error);
    }

    function _validateDeal(IBaseStructure.Deal memory deal, IBaseStructure.Bid memory bid)
        internal
        pure
        returns (DealError)
    {
        if (deal.collateralToken != bid.collateralToken) return DealError.CollateralTokenMismatch;
        if (deal.borrowToken != bid.borrowToken) return DealError.BorrowTokenMismatch;
        if (deal.collateralAmount < bid.minCollateralAmount) return DealError.CollateralAmountMismatch;
        if (deal.borrowAmount > bid.maxBorrowAmount) return DealError.BorrowAmountMismatch;
        if (deal.interestRate < bid.interestRateBid) return DealError.InterestRateMismatch;
        if (deal.dealHook != bid.dealHook) return DealError.DealHookMismatch;
        return DealError.ValidDeal;
    }

    function _validateDeal(IBaseStructure.Deal memory deal, IBaseStructure.Ask memory ask)
        private
        pure
        returns (DealError)
    {
        if (deal.collateralToken != ask.collateralToken) return DealError.CollateralTokenMismatch;
        if (deal.borrowToken != ask.borrowToken) return DealError.BorrowTokenMismatch;
        if (deal.collateralAmount > ask.maxCollateralAmount) return DealError.CollateralAmountMismatch;
        if (deal.borrowAmount < ask.minBorrowAmount) return DealError.BorrowAmountMismatch;
        if (deal.interestRate > ask.interestRateAsk) return DealError.InterestRateMismatch;
        if (deal.dealHook != ask.dealHook) return DealError.DealHookMismatch;

        return DealError.ValidDeal;
    }
}
