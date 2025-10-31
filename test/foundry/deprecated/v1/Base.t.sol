// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/Test.sol";
import {Vault} from "src/deprecated/v1/core/Vault.sol";
import {Setup} from "./Setup.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Base is Setup {
    function test_Ownership_CorrectlySet_WhenContractsDeployed() public view {
        assertEq(config.owner(), deployer);
        assertEq(config.pendingOwner(), address(0));
        assertEq(multiAssetPosition.owner(), deployer);
        for (uint256 i = 0; i < vaults.length; i++) {
            assertEq(vaults[i].owner(), deployer);
        }
    }

    function _testDeposit(address _user, address _asset, uint256 _amount) internal {
        console.log("asset", address(_asset));
        Vault vault = vaultOf(_asset);
        console.log("vault", address(vault));
        vm.startPrank(_user);
        deal(address(_asset), _user, _amount);
        IERC20(_asset).approve(address(vault), _amount);
        vault.deposit(_amount, _user);
        assertEq(vault.previewRedeem(vault.balanceOf(_user)), _amount);
        vm.stopPrank();
    }

    function _testWithdraw(address _user, address _asset, uint256 _amount) internal {
        _testDeposit(_user, _asset, _amount);
        Vault vault = vaultOf(_asset);

        vm.startPrank(_user);
        vault.withdraw(_amount, _user, _user);
        assertEq(vault.previewRedeem(vault.balanceOf(_user)), 0);
        vm.stopPrank();
    }

    function vaultOf(address _asset) internal view returns (Vault) {
        for (uint256 i = 0; i < assets.length; i++) {
            if (address(assets[i]) == _asset) {
                return vaults[i];
            }
        }
        revert("Asset not found");
    }
}
