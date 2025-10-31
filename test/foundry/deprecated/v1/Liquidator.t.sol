// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Base} from "./Base.t.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {LiquidateData, RepayData, RewardData} from "src/deprecated/v1/position/MultiAssetPosition.sol";

contract LiquidatorTest is Base {
    function test_Liquidate_Succeeds_WhenPositionUndercollateralized() public {
        // deposit
        vm.startPrank(user1);
        deal(address(assets[0]), user1, 1 ether);
        IERC20(address(assets[0])).approve(address(vaults[0]), 1 ether);
        vaults[0].deposit(1 ether, user1);
        uint256 tokenId = multiAssetPosition.mint(user1);
        vaults[0].transfer(address(multiAssetPosition), 1 ether);
        multiAssetPosition.supply(tokenId, address(vaults[0]));
        vm.stopPrank();

        // borrow
        vm.startPrank(user1);
        multiAssetPosition.borrow(tokenId, address(vaults[1]), 0.5 ether);
        vm.stopPrank();

        // update price. collataral value decreases by 75%
        uint256 currentPrice = oracle.priceOf(address(assets[0]));
        _updatePrice(address(assets[0]), currentPrice / 8);

        // liquidate
        vm.startPrank(user2);
        deal(address(assets[1]), user2, 0.5 ether);
        RepayData[] memory repayData = new RepayData[](1);
        repayData[0] = RepayData({vToken: address(vaults[1]), amount: 0.5 ether});
        RewardData[] memory rewardData = new RewardData[](1);
        rewardData[0] = RewardData({vToken: address(vaults[0]), amount: 0.1 ether});
        LiquidateData memory liquidateData =
            LiquidateData({repayData: repayData, rewardData: rewardData, receiver: user2, payer: user2});
        IERC20(address(assets[1])).approve(address(multiAssetPosition), 0.5 ether);
        liquidator.liquidate(address(multiAssetPosition), tokenId, abi.encode(liquidateData));
        vm.stopPrank();
    }
}
