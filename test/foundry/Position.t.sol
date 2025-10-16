// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../../src/core/Vault.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {InterestRate} from "../../src/constants/InterestRate.sol";
import {Base} from "./Base.t.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract PositionTest is Base {
    function test_metadata() public view {
        console.log("name", multiAssetPosition.name());
        console.log("symbol", multiAssetPosition.symbol());
    }

    function test_supply() public returns (uint256) {
        address asset = address(assets[0]);
        uint256 amount = 1 ether;
        _test_deposit(user1, asset, amount);
        vm.startPrank(user1);
        uint256 tokenId = multiAssetPosition.mint(user1);
        IERC20(address(vaultOf(asset))).transfer(address(multiAssetPosition), amount);
        multiAssetPosition.supply(tokenId, address(vaultOf(asset)));
        vm.stopPrank();
        return tokenId;
    }

    function test_borrow() public returns (uint256) {
        address asset = address(assets[1]);
        uint256 tokenId = test_supply();
        vm.startPrank(user1);
        multiAssetPosition.borrow(tokenId, address(vaultOf(asset)), 0.1 ether);
        vm.stopPrank();
        return tokenId;
    }

    function test_repay() public {
        address asset = address(assets[1]);
        uint256 tokenId = test_borrow();
        vm.startPrank(user1);
        IERC20(asset).approve(address(multiAssetPosition), 0.1 ether);
        multiAssetPosition.repay(tokenId, address(vaultOf(asset)), 0.1 ether);
        vm.stopPrank();
    }

    function test_multiAssetPosition() public {
        vm.startPrank(user1); // LP
        for (uint256 i = 0; i < assets.length; i++) {
            deal(address(assets[i]), user1, 100 ether);
            IERC20(address(assets[i])).approve(address(vaults[i]), 100 ether);
            vaults[i].deposit(100 ether, user1);
        }
        vm.stopPrank();

        deal(address(assets[0]), user2, 10 ether);
        deal(address(assets[1]), user2, 10 ether);

        vm.startPrank(user2);
        uint256 tokenId = multiAssetPosition.mint(user2);
        assets[0].approve(address(vaults[0]), 10 ether);
        assets[1].approve(address(vaults[1]), 10 ether);
        vaults[0].deposit(10 ether, user2);
        vaults[1].deposit(10 ether, user2);
        vaults[0].transfer(address(multiAssetPosition), 10 ether);
        vaults[1].transfer(address(multiAssetPosition), 10 ether);
        multiAssetPosition.supply(tokenId, address(vaults[0]));
        multiAssetPosition.supply(tokenId, address(vaults[1]));
        multiAssetPosition.borrow(tokenId, address(vaults[2]), 0.1 ether);
        multiAssetPosition.borrow(tokenId, address(vaults[3]), 0.1 ether);
        vm.stopPrank();

        (address[] memory vaults, int256[] memory amounts) = multiAssetPosition.getPosition(tokenId);
        assertEq(vaults.length, 4);
        assertEq(amounts.length, 4);
        assertEq(vaults[0], address(vaults[0]));
        assertEq(vaults[1], address(vaults[1]));
        assertEq(vaults[2], address(vaults[2]));
        assertEq(vaults[3], address(vaults[3]));
        assertEq(amounts[0], 10 ether);
        assertEq(amounts[1], 10 ether);
        assertEq(amounts[2], -0.1 ether);
        assertEq(amounts[3], -0.1 ether);
    }
}
