// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Ownable2Step} from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {EnumerableSet} from "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

interface IConfig {
    function isWhitelisted(address _position) external view returns (bool);
    function isVault(address _vault) external view returns (bool);
}
contract Config is Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private vaults;
    constructor() Ownable(msg.sender) {}

    function addVault(address _vault) external onlyOwner {
        vaults.add(_vault);
    }

    function removeVault(address _vault) external onlyOwner {
        vaults.remove(_vault);
    }

    function getVaults() external view returns (address[] memory) {
        return vaults.values();
    }

    function isVault(address _vault) external view returns (bool) {
        return vaults.contains(_vault);
    }
}
