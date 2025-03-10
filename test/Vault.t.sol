// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IntrestRate} from "../src/constants/IntrestRate.sol";
import {Base} from "./Base.t.sol";

contract VaultTest is Base {
    function test_metadata() public view {
        console.log("name", vault.name());
        console.log("symbol", vault.symbol());
        console.log("decimals", vault.decimals());
    }

    function test_deposit() public {
        _test_deposit(1 ether);
    }

    function test_withdraw() public {
        _test_withdraw(1 ether);
    }

    function test_prevent_inflation_attack() public {
        (address attacker,) = makeAddrAndKey("attacker");
        inflaction_attack(attacker);
        deal(address(asset), user, 100e18);
        uint estimatedBefore = estimateBalance(user);
        vm.startPrank(user);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(100e18, user);
        vm.stopPrank();
        uint estimatedAfter = estimateBalance(user);
        assertGt(estimatedAfter, estimatedBefore * 99 / 100, "attacked");
    }

    function inflaction_attack(address attacker) private {
        deal(address(asset), attacker, 100e18 + 1);
        console.log("[inflation attack] attacker deposits 1 wei, transfers 100e18");
        vm.startPrank(attacker);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(1, attacker);
        asset.transfer(address(vault), 100e18);
        vm.stopPrank();
    }


    function estimateBalance(address _user) private view returns (uint256) {
        return asset.balanceOf(_user) + vault.previewRedeem(vault.balanceOf(_user));
    }

    function test_borrow() public {
        _test_deposit(1 ether);
        uint interestRate = IntrestRate.getIntrestRateForDuration(vault.interestRatePerSecond(), 86400 * 365);
        uint lentAmount = 0.1 ether;
        vm.startPrank(address(position));
        vault.borrow(lentAmount, address(vault));
        vm.stopPrank();
        assertEq(vault.lentAssets(), lentAmount);
        _timeElapse(86400 * 365);
        assertEq(vault.lentAssets(), lentAmount + lentAmount * interestRate / IntrestRate.BASE);
    }
}
