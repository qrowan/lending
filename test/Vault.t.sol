// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {TransparentUpgradeableProxy} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IntrestRate} from "../src/constants/IntrestRate.sol";
import {TestUtils} from "./TestUtils.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

contract VaultTest is TestUtils {
    Vault public vault;
    ERC20Mock public asset;
    address public user;
    address public deployer;

    function setUp() public {
        (deployer,) = makeAddrAndKey("deployer");
        vm.startPrank(deployer);
        ProxyAdmin proxyAdmin = new ProxyAdmin(deployer);
        asset = new ERC20Mock();
        Vault _logic = new Vault();
        vault = Vault(_makeProxy(
            proxyAdmin,
            address(_logic),
            abi.encodeWithSelector(Vault.initialize.selector, address(asset))
        ));

        (user,) = makeAddrAndKey("user");
        vm.stopPrank();
    }

    function test_metadata() public {
        console.log("name", vault.name());
        console.log("symbol", vault.symbol());
        console.log("decimals", vault.decimals());
    }

    function test_deposit() public {
        vm.startPrank(user);
        deal(address(asset), user, 1000);
        asset.approve(address(vault), 1000);
        vault.deposit(100, user);
        assertEq(vault.previewRedeem(vault.balanceOf(user)), 100);
        vm.stopPrank();
    }

    function test_withdraw() public {
        test_deposit();
        vm.startPrank(user);
        vault.withdraw(100, user, user);
        assertEq(vault.previewRedeem(vault.balanceOf(user)), 0);
        vm.stopPrank();
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


    function estimateBalance(address _user) public view returns (uint256) {
        return asset.balanceOf(_user) + vault.previewRedeem(vault.balanceOf(_user));
    }

    function test_interest_rate() public {
        uint256 interestRatePerSecond = IntrestRate.INTEREST_RATE_15;
        uint256 duration = 86400 * 365;
        uint256 interestRate = IntrestRate.getIntrestRateForDuration(interestRatePerSecond, duration);
        console.log("interestRate", fromUnit(interestRate, 27, 4));
    }
}
