// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {InterestRate} from "../src/constants/InterestRate.sol";
import {Base} from "./Base.t.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
contract OracleTest is Base {
    function test_setKeeper() public {
        vm.startPrank(deployer);
        oracle.setKeeper(keeper1, true);
        oracle.setKeeper(keeper2, true);
        oracle.setKeeper(keeper3, true);
        assertEq(oracle.isKeeper(keeper1), true);
        assertEq(oracle.isKeeper(keeper2), true);
        assertEq(oracle.isKeeper(keeper3), true);
        vm.stopPrank();
    }

    function test_setHeartbeat() public {
        vm.startPrank(deployer);
        oracle.setHeartbeat(address(assets[0]), 1000);
        (uint lastData, uint timestamp, uint heartbeat) = oracle.referenceData(
            address(assets[0])
        );
        assertEq(heartbeat, 1000);
        vm.stopPrank();
    }

    function test_updatePrice() public {
        test_setKeeper();
        test_setHeartbeat();
        bytes[] memory signatures = new bytes[](3);
        signatures[0] = signToPrice(
            address(assets[0]),
            (1e18 * 80000) / 1e8,
            keeper1Key
        );
        signatures[1] = signToPrice(
            address(assets[0]),
            (1e18 * 80000) / 1e8,
            keeper2Key
        );
        signatures[2] = signToPrice(
            address(assets[0]),
            (1e18 * 80000) / 1e8,
            keeper3Key
        );

        vm.startPrank(keeper1);
        oracle.updatePrice(
            address(assets[0]),
            (1e18 * 80000) / 1e8,
            signatures
        );
        assertEq(oracle.priceOf(address(assets[0])), (1e18 * 80000) / 1e8);
        vm.stopPrank();
    }

    function test_PriceExpiredFail() public {
        test_updatePrice();
        test_setHeartbeat();
        vm.warp(block.timestamp + 1001);
        vm.expectRevert("Oracle: price not updated");
        oracle.priceOf(address(assets[0]));
    }

    function signToPrice(
        address asset,
        uint256 price,
        uint256 privateKey
    ) public pure returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked(asset, price));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return createSignature(v, r, s);
    }

    function createSignature(
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (bytes memory) {
        bytes memory signature = new bytes(65);
        assembly {
            mstore(add(signature, 32), r)
            mstore(add(signature, 64), s)
            mstore8(add(signature, 96), v)
        }
        return signature;
    }
}
