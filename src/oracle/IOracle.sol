// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IOracle {
    function priceOf(address _asset) external view returns (uint256);
}
