// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

abstract contract DeadlineHandler {
    error Expired();

    modifier checkDeadline(uint256 deadline) {
        _checkDeadline(deadline);
        _;
    }

    function _checkDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert Expired();
    }
}
