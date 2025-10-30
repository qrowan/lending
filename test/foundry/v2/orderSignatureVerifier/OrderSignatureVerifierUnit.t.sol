// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {OrderSignatureVerifier} from "src/v2/libraries/OrderSignatureVerifier.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract OrderSignatureVerifierTest is Test {
    using OrderSignatureVerifier for *;

    function verifySignatureWrapper(bytes32 hash, bytes memory signature, address expectedSigner)
        external
        view
        returns (address)
    {
        return OrderSignatureVerifier.verifyOrderSignature(hash, signature, expectedSigner);
    }

    function test_RevertIf_EOASignatureInvalidSigner() public {
        bytes32 hash = keccak256("test message");
        uint256 privateKey = 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890;
        address wrongSigner = address(0x999);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(OrderSignatureVerifier.InvalidSignature.selector);
        this.verifySignatureWrapper(hash, signature, wrongSigner);
    }

    function test_VerifySignature_Succeeds_WhenEOASignatureIsValid() public view {
        bytes32 hash = keccak256("test message");
        uint256 privateKey = vm.envUint("PRIVATE_KEY1");
        address expectedSigner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        address recoveredSigner = this.verifySignatureWrapper(hash, signature, expectedSigner);

        assertEq(recoveredSigner, expectedSigner);
    }

    function test_RevertIf_ContractSignatureInvalidSigner() public {
        bytes32 hash = keccak256("test message");
        uint256 privateKey = vm.envUint("PRIVATE_KEY1");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        address contractSigner = address(this); // This test contract has code

        vm.expectRevert(OrderSignatureVerifier.InvalidSignature.selector);
        this.verifySignatureWrapper(hash, signature, contractSigner);
    }

    function test_VerifySignature_Succeeds_WhenContractSignatureIsValid() public {
        bytes32 hash = keccak256("test message");
        uint256 privateKey = vm.envUint("PRIVATE_KEY1");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        address expectedSigner = vm.addr(privateKey);

        MockContract mockContract = new MockContract(expectedSigner);

        address recoveredSigner = this.verifySignatureWrapper(hash, signature, address(mockContract));

        assertEq(recoveredSigner, address(mockContract));
    }
}

contract MockContract {
    using ECDSA for bytes32;
    address private _expectedSigner;

    constructor(address expectedSigner) {
        _expectedSigner = expectedSigner;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        address recoveredSigner = hash.recover(signature);
        if (recoveredSigner == _expectedSigner) {
            return this.isValidSignature.selector;
        }
        return bytes4(0);
    }
}
