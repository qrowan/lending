// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPosition {
    function isLiquidatable(uint256 _tokenId) external view returns (bool);
    function liquidate(uint256 _tokenId, bytes memory _data) external;
}
