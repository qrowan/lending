// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IDealHookFactory, IDealHook} from "../../interfaces/IAggregatedInterfaces.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DealHookFactory is IDealHookFactory, Ownable {
    mapping(address => bool) private hookExists;
    uint256 private nextId = 1; // Start from 1, 0 means "not found"

    event DealHookAdded(address indexed dealHook, string name);

    error DealHookNotFound();
    error DealHookAlreadyExists();

    constructor(address _owner) Ownable(_owner) {}

    function addDealHook(address dealHook) external onlyOwner {
        require(!hookExists[dealHook], "Hook already exists");

        hookExists[dealHook] = true;

        string memory name = IDealHook(dealHook).name();

        emit DealHookAdded(dealHook, name);
    }

    function validateDealHook(address dealHook) external {
        if (!hookExists[dealHook]) revert DealHookNotFound();
    }
}
