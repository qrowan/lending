// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {TransparentUpgradeableProxy} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract VaultTest is Test {
    Vault public vault;
    ERC20Mock public asset;
    address public user;

    function setUp() public {
        asset = new ERC20Mock();
        Vault _logic = new Vault();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(_logic),
            address(this),
            abi.encodeWithSelector(Vault.initialize.selector, address(asset))
        );
        address proxyAddress = address(proxy);
        vault = Vault(proxyAddress);

        (user,) = makeAddrAndKey("user");
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
        assertEq(vault.balanceOf(user), 100);
        vm.stopPrank();
    }

    function test_withdraw() public {
        test_deposit();
        vm.startPrank(user);
        vault.withdraw(100, user, user);
        assertEq(vault.balanceOf(user), 0);
        vm.stopPrank();
    }
}
