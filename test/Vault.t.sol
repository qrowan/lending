// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/core/Vault.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {InterestRate} from "../src/constants/InterestRate.sol";
import {Base} from "./Base.t.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract VaultTest is Base {
    function test_metadata() public view {
        Vault vault = vaults[0];
        console.log("name", vault.name());
        console.log("symbol", vault.symbol());
        console.log("decimals", vault.decimals());
    }

    function test_deposit() public {
        address asset = address(assets[0]);
        _test_deposit(user, asset, 1 ether);
    }

    function test_withdraw() public {
        address asset = address(assets[0]);
        _test_withdraw(user, asset, 1 ether);
    }

    function test_prevent_inflation_attack() public {
        address asset = address(assets[0]);
        Vault vault = vaultOf(asset);
        (address attacker, ) = makeAddrAndKey("attacker");
        inflaction_attack(attacker);
        deal(address(asset), user, 100e18);
        uint estimatedBefore = estimateBalance(asset, user);
        vm.startPrank(user);
        IERC20(asset).approve(address(vault), type(uint256).max);
        vault.deposit(100e18, user);
        vm.stopPrank();
        uint estimatedAfter = estimateBalance(asset, user);
        assertGt(estimatedAfter, (estimatedBefore * 99) / 100, "attacked");
    }

    function inflaction_attack(address attacker) private {
        address asset = address(assets[0]);
        Vault vault = vaultOf(asset);
        deal(address(asset), attacker, 100e18 + 1);
        console.log(
            "[inflation attack] attacker deposits 1 wei, transfers 100e18"
        );
        vm.startPrank(attacker);
        IERC20(asset).approve(address(vault), type(uint256).max);
        vault.deposit(1, attacker);
        IERC20(asset).transfer(address(vault), 100e18);
        vm.stopPrank();
    }

    function estimateBalance(
        address _asset,
        address _user
    ) private view returns (uint256) {
        return
            IERC20(_asset).balanceOf(_user) +
            vaultOf(_asset).previewRedeem(vaultOf(_asset).balanceOf(_user));
    }

    function test_borrow() public {
        address asset = address(assets[0]);
        Vault vault = vaultOf(asset);
        _test_deposit(user, asset, 1 ether);
        uint interestRate = InterestRate.getInterestRateForDuration(
            vault.interestRatePerSecond(),
            86400 * 365
        );
        uint lentAmount = 0.1 ether;
        vm.startPrank(address(multiAssetPosition));
        vault.borrow(lentAmount, address(vault));
        vm.stopPrank();
        assertEq(vault.lentAssets(), lentAmount);
        _timeElapse(86400 * 365);
        assertEq(
            vault.lentAssets(),
            lentAmount + (lentAmount * interestRate) / InterestRate.BASE
        );
    }
}
