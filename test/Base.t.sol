// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {IntrestRate} from "../src/constants/IntrestRate.sol";
import {Setup} from "./Setup.t.sol";
import {ERC20Customized} from "./Setup.t.sol";

contract Base is Setup {
    function _test_deposit(uint256 amount) internal {
        console.log("asset", address(asset));
        console.log("vault", address(vault));
        vm.startPrank(user);
        deal(address(asset), user, amount);
        asset.approve(address(vault), amount);
        vault.deposit(amount, user);
        assertEq(vault.previewRedeem(vault.balanceOf(user)), amount);
        vm.stopPrank();
    }

    function _test_withdraw(uint256 amount) internal {
        _test_deposit(amount);
        vm.startPrank(user);
        vault.withdraw(amount, user, user);
        assertEq(vault.previewRedeem(vault.balanceOf(user)), 0);
        vm.stopPrank();
    }
}
