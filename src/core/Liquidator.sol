// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IPosition} from "@position/IPosition.sol";

contract Liquidator {
    address public config;

    constructor(address _config) {
        config = _config;
    }

    function liquidate(address _position, uint256 _tokenId, bytes memory _data) external {
        IPosition(_position).liquidate(_tokenId, _data);
    }
}
