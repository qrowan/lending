// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract VaultGovernor is Governor, GovernorVotes, GovernorCountingSimple {
    constructor(
        address _token
    ) Governor("VaultGovernor") GovernorVotes(IVotes(_token)) {}

    function votingDelay() public pure override returns (uint256) {
        return 0; // No delay for MVP
    }

    function votingPeriod() public pure override returns (uint256) {
        return 50400; // 1 week assuming 12s block time
    }

    function quorum(
        uint256 /* blockNumber */
    ) public pure override returns (uint256) {
        return 1; // Minimum 1 vote for MVP
    }

    function proposalThreshold() public pure override returns (uint256) {
        return 0; // Anyone can propose for MVP
    }
}
