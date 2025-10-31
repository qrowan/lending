// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library OrderSignatureVerifier {
    error InvalidSignature();
    using ECDSA for bytes32;

    function verifyOrderSignature(bytes32 hash, bytes memory signature, address expectedSigner)
        internal
        view
        returns (address)
    {
        // First try to recover EOA signature
        address recovered = hash.recover(signature);

        // If expected signer is a contract, try EIP-1271
        if (expectedSigner.code.length > 0) {
            try IERC1271(expectedSigner).isValidSignature(hash, signature) returns (bytes4 result) {
                if (result == IERC1271.isValidSignature.selector) {
                    return expectedSigner;
                }
            } catch {}
            revert InvalidSignature();
        }

        // For EOA, verify recovered address matches expected
        if (recovered != expectedSigner) revert InvalidSignature();
        return recovered;
    }
}
