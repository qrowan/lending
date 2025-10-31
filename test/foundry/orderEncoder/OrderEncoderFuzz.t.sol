// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {OrderEncoder} from "src/libraries/OrderEncoder.sol";
import {IBaseStructure} from "src/interfaces/IAggregatedInterfaces.sol";

contract OrderEncoderFuzzTest is Test {
    using OrderEncoder for *;

    function testFuzz_BidEncodingRoundtrip_WorksCorrectly(
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

        bytes memory encoded = OrderEncoder.encodeBid(bid);
        IBaseStructure.Bid memory decoded = OrderEncoder.decodeBid(encoded);

        assertEq(decoded.collateralToken, bid.collateralToken);
        assertEq(decoded.minCollateralAmount, bid.minCollateralAmount);
        assertEq(decoded.borrowToken, bid.borrowToken);
        assertEq(decoded.maxBorrowAmount, bid.maxBorrowAmount);
        assertEq(decoded.interestRateBid, bid.interestRateBid);
        assertEq(decoded.dealHook, bid.dealHook);
        assertEq(decoded.deadline, bid.deadline);
    }

    function testFuzz_AskEncodingRoundtrip_WorksCorrectly(
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

        bytes memory encoded = OrderEncoder.encodeAsk(ask);
        IBaseStructure.Ask memory decoded = OrderEncoder.decodeAsk(encoded);

        assertEq(decoded.collateralToken, ask.collateralToken);
        assertEq(decoded.maxCollateralAmount, ask.maxCollateralAmount);
        assertEq(decoded.borrowToken, ask.borrowToken);
        assertEq(decoded.minBorrowAmount, ask.minBorrowAmount);
        assertEq(decoded.interestRateAsk, ask.interestRateAsk);
        assertEq(decoded.dealHook, ask.dealHook);
        assertEq(decoded.deadline, ask.deadline);
    }
}
