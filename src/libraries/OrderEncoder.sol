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
}
