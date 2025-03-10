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

    function testSupply() public {
        uint256 amount = 1 ether;
        _test_deposit(amount);
        vm.startPrank(user);
        uint256 tokenId = position.mint(user);
        IERC20(address(vault)).transfer(address(position), amount);
        position.supply(tokenId, address(vault));
        vm.stopPrank();
    }
}
