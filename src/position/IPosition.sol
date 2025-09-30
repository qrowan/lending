// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPosition {
    function heath() external view returns (uint256);
    function liquidate() external;
}