// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {InterestRate} from "src/constants/InterestRate.sol";

abstract contract InterestRateHandler {
    error TooBigInterestRate();

    uint256 constant MAX_INTEREST_RATE = InterestRate.INTEREST_RATE_1000;

    modifier checkInterestRate(uint256 interestRate) {
        _checkInterestRate(interestRate);
        _;
    }

    function _checkInterestRate(uint256 interestRate) internal pure {
        if (interestRate > MAX_INTEREST_RATE) revert TooBigInterestRate();
    }
}
