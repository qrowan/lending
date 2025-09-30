// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {InterestRate} from "../src/constants/InterestRate.sol";
import {Base} from "./Base.t.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {PriceMessage} from "../src/oracle/Oracle.sol";
contract OracleTest is Base {
    function test_setKeeper() public {
        vm.startPrank(deployer);
        oracle.setKeeper(keeper1, true);
        oracle.setKeeper(keeper2, true);
        oracle.setKeeper(keeper3, true);
        oracle.setKeeper(keeper4, true);
        assertEq(oracle.isKeeper(keeper1), true);
        assertEq(oracle.isKeeper(keeper2), true);
        assertEq(oracle.isKeeper(keeper3), true);
        assertEq(oracle.isKeeper(keeper4), true);
        vm.stopPrank();
    }

    function test_setHeartbeat() public {
        vm.startPrank(deployer);
        oracle.setHeartbeat(address(assets[0]), 1000);
        (, , uint heartbeat) = oracle.referenceData(address(assets[0]));
        assertEq(heartbeat, 1000);
        vm.stopPrank();
    }

    function test_updatePrice() public {
        test_setKeeper();
        test_setHeartbeat();
        uint256 price = (1e18 * 80000) / 1e8;

        PriceMessage[] memory pMsg = new PriceMessage[](3);
        pMsg[0] = getPMsg(address(assets[0]), price, keeper1Key);
        pMsg[1] = getPMsg(address(assets[0]), price, keeper2Key);
        pMsg[2] = getPMsg(address(assets[0]), price, keeper3Key);

        vm.startPrank(keeper1);
        oracle.updatePrice(address(assets[0]), pMsg);
        assertEq(oracle.priceOf(address(assets[0])), price);
        vm.stopPrank();
    }

    function test_PriceExpiredFail() public {
        test_updatePrice();
        test_setHeartbeat();
        vm.warp(block.timestamp + 1001);
        vm.expectRevert("Oracle: price not updated");
        oracle.priceOf(address(assets[0]));
    }

    function test_medianPriceEven() public {
        test_setKeeper();
        test_setHeartbeat();

        // Test with 4 different prices (even number)
        PriceMessage[] memory pMsg = new PriceMessage[](4);
        pMsg[0] = getPMsg(address(assets[0]), 100e18, keeper1Key);
        pMsg[1] = getPMsg(address(assets[0]), 200e18, keeper2Key);
        pMsg[2] = getPMsg(address(assets[0]), 300e18, keeper3Key);
        pMsg[3] = getPMsg(address(assets[0]), 400e18, keeper4Key);

        vm.startPrank(keeper1);
        oracle.updatePrice(address(assets[0]), pMsg);
        // Median of [100, 200, 300, 400] should be (200 + 300) / 2 = 250
        assertEq(oracle.priceOf(address(assets[0])), 250e18);
        vm.stopPrank();
    }

    function test_medianPriceOdd() public {
        test_setKeeper();
        test_setHeartbeat();

        // Test with 3 different prices (odd number)
        PriceMessage[] memory pMsg = new PriceMessage[](3);
        pMsg[0] = getPMsg(address(assets[0]), 100e18, keeper1Key);
        pMsg[1] = getPMsg(address(assets[0]), 300e18, keeper2Key);
        pMsg[2] = getPMsg(address(assets[0]), 200e18, keeper3Key);

        vm.startPrank(keeper1);
        oracle.updatePrice(address(assets[0]), pMsg);
        // Median of [100, 200, 300] should be 200
        assertEq(oracle.priceOf(address(assets[0])), 200e18);
        vm.stopPrank();
    }
}
