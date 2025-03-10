// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IntrestRate} from "../src/constants/IntrestRate.sol";
import {Base} from "./Base.t.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
contract OracleTest is Base {
    function test_setKeeper() public {
        vm.startPrank(deployer);
        oracle.setKeeper(address(this), true);
        assertEq(oracle.isKeeper(address(this)), true);
        vm.stopPrank();
    }

    function test_setHeartbeat() public {
        vm.startPrank(deployer);
        oracle.setHeartbeat(address(assets[0]), 1000);
        (uint lastData, uint timestamp, uint heartbeat) = oracle.referenceData(address(assets[0]));
        assertEq(heartbeat, 1000);
        vm.stopPrank();
    }

    function test_updatePrice() public {
        test_setKeeper();
        test_setHeartbeat();
        oracle.updatePrice(address(assets[0]), 1e18 * 80000 / 1e8);
        oracle.updatePrice(address(assets[1]), 1e18 * 2200 / 1e18);
        oracle.updatePrice(address(assets[2]), 1e18 * 1 / 1e6);
        oracle.updatePrice(address(assets[3]), 1e18 * 300 / 1e18);
        oracle.updatePrice(address(assets[4]), 1e18 * 2 / 1e18);
        assertEq(oracle.priceOf(address(assets[0])), 1e18 * 80000 / 1e8);
        assertEq(oracle.priceOf(address(assets[1])), 1e18 * 2200 / 1e18);
        assertEq(oracle.priceOf(address(assets[2])), 1e18 * 1 / 1e6);
        assertEq(oracle.priceOf(address(assets[3])), 1e18 * 300 / 1e18);
        assertEq(oracle.priceOf(address(assets[4])), 1e18 * 2 / 1e18);
    }

    function test_PriceExpiredFail() public {
        test_updatePrice();
        test_setHeartbeat();
        vm.warp(block.timestamp + 1000);
        vm.expectRevert("Oracle: price not updated");
        oracle.priceOf(address(assets[0]));
    }
    
    
}
