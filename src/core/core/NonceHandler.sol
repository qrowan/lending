// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {INonceHandler} from "../../interfaces/IAggregatedInterfaces.sol";

abstract contract NonceHandler is INonceHandler {
    // State variables
    mapping(address => uint256) public nonces;

    function _consumeNonce(address user, uint256 expectedNonce) internal virtual {
        unchecked {
            if (++nonces[user] != expectedNonce + 1) revert WrongNonce(user, expectedNonce);
        }
        emit NonceConsumed(user, expectedNonce);
    }

    // Nonce management functions
    function consumeNonce(uint256 targetNonce) external virtual {
        _consumeNonce(msg.sender, targetNonce);
    }

    function getCurrentNonce(address user) external view virtual returns (uint256) {
        return nonces[user];
    }
}
