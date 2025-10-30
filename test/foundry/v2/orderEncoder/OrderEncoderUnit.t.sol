// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {OrderEncoder} from "src/v2/libraries/OrderEncoder.sol";
import {IBaseStructure} from "src/v2/interfaces/IAggregatedInterfaces.sol";

contract OrderEncoderUnitTest is Test {
    using OrderEncoder for *;

    function test_EncodeBid_ReturnsCorrectBytes_WhenValidBidProvided() public pure {
        IBaseStructure.Bid memory bid = IBaseStructure.Bid({
            collateralToken: address(0x1),
            minCollateralAmount: 100,
            borrowToken: address(0x2),
            maxBorrowAmount: 200,
            interestRateBid: 500,
            dealHook: address(0x3),
            deadline: 1000
        });

        bytes memory encoded = OrderEncoder.encodeBid(bid);

        // Should be able to decode back to same values
        IBaseStructure.Bid memory decoded = OrderEncoder.decodeBid(encoded);

        assertEq(decoded.collateralToken, bid.collateralToken);
        assertEq(decoded.minCollateralAmount, bid.minCollateralAmount);
        assertEq(decoded.borrowToken, bid.borrowToken);
        assertEq(decoded.maxBorrowAmount, bid.maxBorrowAmount);
        assertEq(decoded.interestRateBid, bid.interestRateBid);
        assertEq(decoded.dealHook, bid.dealHook);
        assertEq(decoded.deadline, bid.deadline);
    }

    function test_EncodeAsk_ReturnsCorrectBytes_WhenValidAskProvided() public pure {
        IBaseStructure.Ask memory ask = IBaseStructure.Ask({
            collateralToken: address(0x1),
            maxCollateralAmount: 100,
            borrowToken: address(0x2),
            minBorrowAmount: 200,
            interestRateAsk: 500,
            dealHook: address(0x3),
            deadline: 1000
        });

        bytes memory encoded = OrderEncoder.encodeAsk(ask);

        // Should be able to decode back to same values
        IBaseStructure.Ask memory decoded = OrderEncoder.decodeAsk(encoded);

        assertEq(decoded.collateralToken, ask.collateralToken);
        assertEq(decoded.maxCollateralAmount, ask.maxCollateralAmount);
        assertEq(decoded.borrowToken, ask.borrowToken);
        assertEq(decoded.minBorrowAmount, ask.minBorrowAmount);
        assertEq(decoded.interestRateAsk, ask.interestRateAsk);
        assertEq(decoded.dealHook, ask.dealHook);
        assertEq(decoded.deadline, ask.deadline);
    }

    function test_EncodeBidWithAccountInfo_ReturnsCorrectBytes_WhenAccountInfoProvided() public pure {
        IBaseStructure.Bid memory bid = IBaseStructure.Bid({
            collateralToken: address(0x1),
            minCollateralAmount: 100,
            borrowToken: address(0x2),
            maxBorrowAmount: 200,
            interestRateBid: 500,
            dealHook: address(0x3),
            deadline: 1000
        });

        IBaseStructure.AccountInfo memory accountInfo = IBaseStructure.AccountInfo({account: address(0x123), nonce: 42});

        IBaseStructure.BidWithAccountInfo memory bidWithAccountInfo =
            IBaseStructure.BidWithAccountInfo({bid: bid, accountInfo: accountInfo});

        bytes memory encoded = OrderEncoder.encodeBidWithAccountInfo(bidWithAccountInfo);
        IBaseStructure.BidWithAccountInfo memory decoded = OrderEncoder.decodeBidWithAccountInfo(encoded);

        // Check bid fields
        assertEq(decoded.bid.collateralToken, bid.collateralToken);
        assertEq(decoded.bid.minCollateralAmount, bid.minCollateralAmount);
        assertEq(decoded.bid.borrowToken, bid.borrowToken);
        assertEq(decoded.bid.maxBorrowAmount, bid.maxBorrowAmount);
        assertEq(decoded.bid.interestRateBid, bid.interestRateBid);
        assertEq(decoded.bid.dealHook, bid.dealHook);
        assertEq(decoded.bid.deadline, bid.deadline);

        // Check account info fields
        assertEq(decoded.accountInfo.account, accountInfo.account);
        assertEq(decoded.accountInfo.nonce, accountInfo.nonce);
    }

    function test_EncodeAskWithAccountInfo_ReturnsCorrectBytes_WhenAccountInfoProvided() public pure {
        IBaseStructure.Ask memory ask = IBaseStructure.Ask({
            collateralToken: address(0x1),
            maxCollateralAmount: 100,
            borrowToken: address(0x2),
            minBorrowAmount: 200,
            interestRateAsk: 500,
            dealHook: address(0x3),
            deadline: 1000
        });

        IBaseStructure.AccountInfo memory accountInfo = IBaseStructure.AccountInfo({account: address(0x123), nonce: 42});

        IBaseStructure.AskWithAccountInfo memory askWithAccountInfo =
            IBaseStructure.AskWithAccountInfo({ask: ask, accountInfo: accountInfo});

        bytes memory encoded = OrderEncoder.encodeAskWithAccountInfo(askWithAccountInfo);
        IBaseStructure.AskWithAccountInfo memory decoded = OrderEncoder.decodeAskWithAccountInfo(encoded);

        // Check ask fields
        assertEq(decoded.ask.collateralToken, ask.collateralToken);
        assertEq(decoded.ask.maxCollateralAmount, ask.maxCollateralAmount);
        assertEq(decoded.ask.borrowToken, ask.borrowToken);
        assertEq(decoded.ask.minBorrowAmount, ask.minBorrowAmount);
        assertEq(decoded.ask.interestRateAsk, ask.interestRateAsk);
        assertEq(decoded.ask.dealHook, ask.dealHook);
        assertEq(decoded.ask.deadline, ask.deadline);

        // Check account info fields
        assertEq(decoded.accountInfo.account, accountInfo.account);
        assertEq(decoded.accountInfo.nonce, accountInfo.nonce);
    }

    function test_GetBidHash_ReturnsCorrectHash_WhenValidBidProvided() public pure {
        IBaseStructure.Bid memory bid = IBaseStructure.Bid({
            collateralToken: address(0x1),
            minCollateralAmount: 100,
            borrowToken: address(0x2),
            maxBorrowAmount: 200,
            interestRateBid: 500,
            dealHook: address(0x3),
            deadline: 1000
        });

        bytes32 hash1 = OrderEncoder.getHash(bid);
        bytes32 hash2 = OrderEncoder.getHash(bid);

        // Same bid should produce same hash
        assertEq(hash1, hash2);

        // Different bid should produce different hash
        bid.minCollateralAmount = 101;
        bytes32 hash3 = OrderEncoder.getHash(bid);
        assertTrue(hash1 != hash3);
    }

    function test_GetAskHash_ReturnsCorrectHash_WhenValidAskProvided() public pure {
        IBaseStructure.Ask memory ask = IBaseStructure.Ask({
            collateralToken: address(0x1),
            maxCollateralAmount: 100,
            borrowToken: address(0x2),
            minBorrowAmount: 200,
            interestRateAsk: 500,
            dealHook: address(0x3),
            deadline: 1000
        });

        bytes32 hash1 = OrderEncoder.getHash(ask);
        bytes32 hash2 = OrderEncoder.getHash(ask);

        // Same ask should produce same hash
        assertEq(hash1, hash2);

        // Different ask should produce different hash
        ask.maxCollateralAmount = 101;
        bytes32 hash3 = OrderEncoder.getHash(ask);
        assertTrue(hash1 != hash3);
    }

    function test_HashConsistency_MatchesManualCalculation_WhenBidProvided() public pure {
        IBaseStructure.Bid memory bid = IBaseStructure.Bid({
            collateralToken: address(0x1),
            minCollateralAmount: 100,
            borrowToken: address(0x2),
            maxBorrowAmount: 200,
            interestRateBid: 500,
            dealHook: address(0x3),
            deadline: 1000
        });

        // Hash should be consistent with manual keccak256 of encoded data
        bytes memory encoded = OrderEncoder.encodeBid(bid);
        bytes32 manualHash = keccak256(encoded);
        bytes32 libraryHash = OrderEncoder.getHash(bid);

        assertEq(manualHash, libraryHash);
    }
}
