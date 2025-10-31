// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IConfig {
    function isVault(address _vault) external view returns (bool);
    function getLiquidator() external view returns (address);
}

contract Config is Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private vaults;
    address private liquidator;

    constructor() Ownable(msg.sender) {}

    function addVault(address _vault) external onlyOwner {
        vaults.add(_vault);
    }

    function getVaults() external view returns (address[] memory) {
        return vaults.values();
    }

    function isVault(address _vault) external view returns (bool) {
        return vaults.contains(_vault);
    }

    function setLiquidator(address _liquidator) external onlyOwner {
        liquidator = _liquidator;
    }

    function getLiquidator() external view returns (address) {
        require(liquidator != address(0), "Liquidator not set");
        return liquidator;
    }
}
