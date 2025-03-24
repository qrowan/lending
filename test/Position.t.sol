// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IntrestRate} from "../src/constants/IntrestRate.sol";
import {Base} from "./Base.t.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
contract PositionTest is Base {
    function test_metadata() public view {
        console.log("name", position.name());
        console.log("symbol", position.symbol());
    }

    function test_supply() public {
        address asset = address(assets[0]);
        uint256 amount = 1 ether;
        _test_deposit(user, asset, amount);
        vm.startPrank(user);
        uint256 tokenId = position.mint(user);
        IERC20(address(vaultOf(asset))).transfer(address(position), amount);
        position.supply(tokenId, address(vaultOf(asset)));
        vm.stopPrank();
    }

    function test_borrow() public {
        address asset = address(assets[0]);
        test_supply();
        vm.startPrank(user1);
        uint256 tokenId = position.mint(user1);
        position.borrow(tokenId, address(vaultOf(asset)), 1 ether);
        vm.stopPrank();
    }

    function test_position() public {
        vm.startPrank(user1); // LP
        for (uint256 i = 0; i < assets.length; i++) {
            deal(address(assets[i]), user1, 100 ether);
            IERC20(address(assets[i])).approve(
                address(vaults[i]),
                100 ether
            );
            vaults[i].deposit(100 ether, user1);
        }
        vm.stopPrank();

        deal(address(assets[0]), user2, 10 ether);
        deal(address(assets[1]), user2, 10 ether);

        vm.startPrank(user2);
        uint256 tokenId = position.mint(user2);
        assets[0].approve(address(vaults[0]), 10 ether);
        assets[1].approve(address(vaults[1]), 10 ether);
        vaults[0].deposit(10 ether, user2);
        vaults[1].deposit(10 ether, user2);
        vaults[0].transfer(address(position), 10 ether);
        vaults[1].transfer(address(position), 10 ether);
        position.supply(tokenId, address(vaults[0]));
        position.supply(tokenId, address(vaults[1]));
        position.borrow(tokenId, address(vaults[2]), 10 ether);
        position.borrow(tokenId, address(vaults[3]), 10 ether);
        vm.stopPrank();
    }
}
