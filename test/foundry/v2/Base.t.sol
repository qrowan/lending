// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IBaseStructure} from "src/v2/interfaces/IAggregatedInterfaces.sol";
import {OrderEncoder} from "src/v2/libraries/OrderEncoder.sol";

contract Base is Test {
    using OrderEncoder for *;

    function getSignature(IBaseStructure.Bid memory bid, uint256 privateKey) internal pure returns (bytes memory) {
        bytes32 hash = bid.getHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        return abi.encodePacked(r, s, v);
    }

    function getSignature(IBaseStructure.Ask memory ask, uint256 privateKey) internal pure returns (bytes memory) {
        bytes32 hash = ask.getHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        return abi.encodePacked(r, s, v);
    }
}
