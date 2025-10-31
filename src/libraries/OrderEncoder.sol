// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IBaseStructure} from "../interfaces/IAggregatedInterfaces.sol";

library OrderEncoder {
    function encodeBid(IBaseStructure.Bid memory bid) internal pure returns (bytes memory) {
        return abi.encode(
            bid.collateralToken,
            bid.minCollateralAmount,
            bid.borrowToken,
            bid.maxBorrowAmount,
            bid.interestRateBid,
            bid.dealHook,
            bid.deadline
        );
    }

    function encodeAsk(IBaseStructure.Ask memory ask) internal pure returns (bytes memory) {
        return abi.encode(
            ask.collateralToken,
            ask.maxCollateralAmount,
            ask.borrowToken,
            ask.minBorrowAmount,
            ask.interestRateAsk,
            ask.dealHook,
            ask.deadline
        );
    }

    function decodeBid(bytes memory encoded) internal pure returns (IBaseStructure.Bid memory) {
        (IBaseStructure.Bid memory bid) = abi.decode(encoded, (IBaseStructure.Bid));
        return bid;
    }

    function decodeAsk(bytes memory encoded) internal pure returns (IBaseStructure.Ask memory) {
        (IBaseStructure.Ask memory ask) = abi.decode(encoded, (IBaseStructure.Ask));
        return ask;
    }

    function encodeBidWithAccountInfo(IBaseStructure.BidWithAccountInfo memory bidWithAccountInfo)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(bidWithAccountInfo.bid, bidWithAccountInfo.accountInfo);
    }

    function encodeAskWithAccountInfo(IBaseStructure.AskWithAccountInfo memory askWithAccountInfo)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(askWithAccountInfo.ask, askWithAccountInfo.accountInfo);
    }

    function decodeBidWithAccountInfo(bytes memory encoded)
        internal
        pure
        returns (IBaseStructure.BidWithAccountInfo memory)
    {
        (IBaseStructure.Bid memory bid, IBaseStructure.AccountInfo memory accountInfo) =
            abi.decode(encoded, (IBaseStructure.Bid, IBaseStructure.AccountInfo));
        return IBaseStructure.BidWithAccountInfo({bid: bid, accountInfo: accountInfo});
    }

    function decodeAskWithAccountInfo(bytes memory encoded)
        internal
        pure
        returns (IBaseStructure.AskWithAccountInfo memory)
    {
        (IBaseStructure.Ask memory ask, IBaseStructure.AccountInfo memory accountInfo) =
            abi.decode(encoded, (IBaseStructure.Ask, IBaseStructure.AccountInfo));
        return IBaseStructure.AskWithAccountInfo({ask: ask, accountInfo: accountInfo});
    }

    function getHash(IBaseStructure.Bid memory bid) internal pure returns (bytes32) {
        bytes32 hash;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, mload(add(bid, 0x00))) // collateralToken
            mstore(add(ptr, 0x20), mload(add(bid, 0x20))) // minCollateralAmount
            mstore(add(ptr, 0x40), mload(add(bid, 0x40))) // borrowToken
            mstore(add(ptr, 0x60), mload(add(bid, 0x60))) // maxBorrowAmount
            mstore(add(ptr, 0x80), mload(add(bid, 0x80))) // interestRateBid
            mstore(add(ptr, 0xa0), mload(add(bid, 0xa0))) // dealHook
            mstore(add(ptr, 0xc0), mload(add(bid, 0xc0))) // deadline
            hash := keccak256(ptr, 0xe0)
        }
        return hash;
    }

    function getHash(IBaseStructure.Ask memory ask) internal pure returns (bytes32) {
        bytes32 hash;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, mload(add(ask, 0x00))) // collateralToken
            mstore(add(ptr, 0x20), mload(add(ask, 0x20))) // maxCollateralAmount
            mstore(add(ptr, 0x40), mload(add(ask, 0x40))) // borrowToken
            mstore(add(ptr, 0x60), mload(add(ask, 0x60))) // minBorrowAmount
            mstore(add(ptr, 0x80), mload(add(ask, 0x80))) // interestRateAsk
            mstore(add(ptr, 0xa0), mload(add(ask, 0xa0))) // dealHook
            mstore(add(ptr, 0xc0), mload(add(ask, 0xc0))) // deadline
            hash := keccak256(ptr, 0xe0)
        }
        return hash;
    }
}
