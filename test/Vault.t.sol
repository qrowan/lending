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

    function test_update_interest_rate() public {
        address asset = address(assets[0]);
        Vault vault = vaultOf(asset);
        
        // Deposit initial funds
        _test_deposit(user, asset, 10 ether);
        
        // Borrow some amount
        uint lentAmount = 1 ether;
        vm.startPrank(address(multiAssetPosition));
        vault.borrow(lentAmount, address(vault));
        vm.stopPrank();
        
        // Record initial state
        uint initialLentAssets = vault.lentAssets();
        assertEq(initialLentAssets, lentAmount);
        
        // Earn interest with 15% APR for 1 year
        _timeElapse(86400 * 365); // 1 year
        uint lentAssetsAfter15Percent = vault.lentAssets();
        
        // Calculate expected interest with 15% APR
        uint interestRate15 = InterestRate.getInterestRateForDuration(
            InterestRate.INTEREST_RATE_15,
            86400 * 365
        );
        uint expected15 = lentAmount + (lentAmount * interestRate15) / InterestRate.BASE;
        assertEq(lentAssetsAfter15Percent, expected15, "15% APR calculation incorrect");
        
        // Change interest rate to 20% APR via governance
        vm.prank(vault.governor());
        vault.setInterestRate(InterestRate.INTEREST_RATE_20);
        
        // Verify interest rate changed
        assertEq(vault.interestRatePerSecond(), InterestRate.INTEREST_RATE_20);
        
        // The lentAssets should remain the same immediately after rate change
        uint lentAssetsAfterRateChange = vault.lentAssets();
        assertEq(lentAssetsAfterRateChange, lentAssetsAfter15Percent, "Assets should not change immediately");
        
        // Earn interest with 20% APR for another 1 year
        _timeElapse(86400 * 365); // Another 1 year
        uint finalLentAssets = vault.lentAssets();
        
        // Calculate expected interest with 20% APR on the current amount
        uint interestRate20 = InterestRate.getInterestRateForDuration(
            InterestRate.INTEREST_RATE_20,
            86400 * 365
        );
        uint expectedFinal = lentAssetsAfterRateChange + (lentAssetsAfterRateChange * interestRate20) / InterestRate.BASE;
        assertEq(finalLentAssets, expectedFinal, "20% APR calculation incorrect");
        
        // Verify final totalAssets includes the compounded interest
        uint totalAssets = vault.totalAssets();
        uint expectedTotalAssets = IERC20(vault.asset()).balanceOf(address(vault)) + finalLentAssets;
        assertEq(totalAssets, expectedTotalAssets, "Total assets calculation incorrect");
    }
}
