// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {InterestRate} from "@constants/InterestRate.sol";
import {Base} from "./Base.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Oracle, PriceMessage} from "@oracle/Oracle.sol";

contract OracleTest is Base {
    
    // Additional test variables for EIP-712 specific tests
    address testKeeper = makeAddr("testKeeper");
    uint256 testKeeperPrivateKey = 0x1234;
    address testAsset = makeAddr("testAsset");
    
    function setUp() public override {
        super.setUp();
        
        // Set up additional keeper for EIP-712 tests
        vm.prank(deployer);
        oracle.setKeeper(vm.addr(testKeeperPrivateKey), true);
        testKeeper = vm.addr(testKeeperPrivateKey);
    }

    // ============ Basic Oracle Functionality Tests ============
    
    function test_setKeeper() public {
        vm.startPrank(deployer);
        oracle.setKeeper(keeper1, true);
        oracle.setKeeper(keeper2, true);
        oracle.setKeeper(keeper3, true);
        oracle.setKeeper(keeper4, true);
        assertEq(oracle.isKeeper(keeper1), true);
        assertEq(oracle.isKeeper(keeper2), true);
        assertEq(oracle.isKeeper(keeper3), true);
        assertEq(oracle.isKeeper(keeper4), true);
        vm.stopPrank();
    }

    function test_setHeartbeat() public {
        vm.startPrank(deployer);
        oracle.setHeartbeat(address(assets[0]), 1000);
        (, , uint heartbeat) = oracle.referenceData(address(assets[0]));
        assertEq(heartbeat, 1000);
        vm.stopPrank();
    }

    function test_updatePrice() public {
        test_setKeeper();
        test_setHeartbeat();
        uint256 price = (1e18 * 80000) / 1e8;

        PriceMessage[] memory pMsg = new PriceMessage[](3);
        pMsg[0] = getPMsg(address(assets[0]), price, keeper1Key);
        pMsg[1] = getPMsg(address(assets[0]), price, keeper2Key);
        pMsg[2] = getPMsg(address(assets[0]), price, keeper3Key);

        vm.startPrank(keeper1);
        oracle.updatePrice(address(assets[0]), pMsg);
        assertEq(oracle.priceOf(address(assets[0])), price);
        vm.stopPrank();
    }

    function test_PriceExpiredFail() public {
        test_updatePrice();
        test_setHeartbeat();
        vm.warp(block.timestamp + 1001);
        vm.expectRevert("Oracle: price not updated");
        oracle.priceOf(address(assets[0]));
    }

    // ============ Median Price Calculation Tests ============

    function test_medianPriceEven() public {
        test_setKeeper();
        test_setHeartbeat();

        // Test with 4 different prices (even number)
        PriceMessage[] memory pMsg = new PriceMessage[](4);
        pMsg[0] = getPMsg(address(assets[0]), 100e18, keeper1Key);
        pMsg[1] = getPMsg(address(assets[0]), 200e18, keeper2Key);
        pMsg[2] = getPMsg(address(assets[0]), 300e18, keeper3Key);
        pMsg[3] = getPMsg(address(assets[0]), 400e18, keeper4Key);

        vm.startPrank(keeper1);
        oracle.updatePrice(address(assets[0]), pMsg);
        // Median of [100, 200, 300, 400] should be (200 + 300) / 2 = 250
        assertEq(oracle.priceOf(address(assets[0])), 250e18);
        vm.stopPrank();
    }

    function test_medianPriceOdd() public {
        test_setKeeper();
        test_setHeartbeat();

        // Test with 3 different prices (odd number)
        PriceMessage[] memory pMsg = new PriceMessage[](3);
        pMsg[0] = getPMsg(address(assets[0]), 100e18, keeper1Key);
        pMsg[1] = getPMsg(address(assets[0]), 300e18, keeper2Key);
        pMsg[2] = getPMsg(address(assets[0]), 200e18, keeper3Key);

        vm.startPrank(keeper1);
        oracle.updatePrice(address(assets[0]), pMsg);
        // Median of [100, 200, 300] should be 200
        assertEq(oracle.priceOf(address(assets[0])), 200e18);
        vm.stopPrank();
    }

    // ============ EIP-712 Signature Tests ============
    
    function test_EIP712Signature() public {
        uint256 price = 1000e18;
        
        // Create 3 signatures for the required minimum
        PriceMessage[] memory priceMessages = new PriceMessage[](3);
        priceMessages[0] = getPMsg(testAsset, price, testKeeperPrivateKey);
        priceMessages[1] = getPMsg(testAsset, price, keeper1Key);
        priceMessages[2] = getPMsg(testAsset, price, keeper2Key);
        
        // Update price - should succeed with EIP-712 signature
        vm.prank(testKeeper);
        oracle.updatePrice(testAsset, priceMessages);
        
        // Verify price was updated
        (uint lastData, uint updatedTimestamp,) = oracle.referenceData(testAsset);
        assertEq(lastData, price);
        assertEq(updatedTimestamp, block.timestamp);
    }
    
    function test_EIP712DomainSeparation() public {
        uint256 price = 1000e18;
        uint256 chainId = block.chainid;
        uint256 timestamp = block.timestamp;
        
        // Deploy a second oracle with different domain
        vm.prank(deployer);
        Oracle oracle2 = new Oracle(1);
        vm.prank(deployer);
        oracle2.setKeeper(testKeeper, true);
        
        // Get hashes from both oracles
        bytes32 hash1 = oracle.getPriceMessageHash(testAsset, price, chainId, timestamp);
        bytes32 hash2 = oracle2.getPriceMessageHash(testAsset, price, chainId, timestamp);
        
        // Hashes should be different due to domain separation
        assertNotEq(hash1, hash2, "Domain separation failed");
    }
    
    function test_EIP712ReplayProtection() public {
        uint256 price = 1000e18;
        uint256 chainId = block.chainid;
        uint256 timestamp = block.timestamp;
        
        // Create valid signature for current chain
        bytes32 digest = oracle.getPriceMessageHash(testAsset, price, chainId, timestamp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(testKeeperPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Try to use signature with different chain ID (should fail)
        PriceMessage[] memory priceMessages = new PriceMessage[](3);
        priceMessages[0] = PriceMessage({
            asset: testAsset,
            price: price,
            chainId: chainId + 1, // Wrong chain ID
            timestamp: timestamp,
            signature: signature
        });
        priceMessages[1] = getPMsg(testAsset, price, keeper1Key);
        priceMessages[2] = getPMsg(testAsset, price, keeper2Key);
        
        vm.expectRevert("Oracle: invalid signer");
        vm.prank(testKeeper);
        oracle.updatePrice(testAsset, priceMessages);
    }
    
    function test_EIP712TypeHashValidation() public {
        // Test that the type hash is correctly formed by verifying signature validation works
        // This indirectly tests that PRICE_MESSAGE_TYPEHASH matches the expected format
        uint256 price = 1000e18;
        
        // Create 3 signatures for the required minimum
        PriceMessage[] memory priceMessages = new PriceMessage[](3);
        priceMessages[0] = getPMsg(testAsset, price, testKeeperPrivateKey);
        priceMessages[1] = getPMsg(testAsset, price, keeper1Key);
        priceMessages[2] = getPMsg(testAsset, price, keeper2Key);
        
        // Should succeed, proving type hash is correct
        vm.prank(testKeeper);
        oracle.updatePrice(testAsset, priceMessages);
    }
    
    function test_InvalidEIP712Signature() public {
        uint256 price = 1000e18;
        uint256 chainId = block.chainid;
        uint256 timestamp = block.timestamp;
        
        // Create signature for different data
        bytes32 wrongDigest = oracle.getPriceMessageHash(testAsset, price + 1, chainId, timestamp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(testKeeperPrivateKey, wrongDigest);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Try to use signature with original data
        PriceMessage[] memory priceMessages = new PriceMessage[](3);
        priceMessages[0] = PriceMessage({
            asset: testAsset,
            price: price, // Different from what was signed
            chainId: chainId,
            timestamp: timestamp,
            signature: signature
        });
        priceMessages[1] = getPMsg(testAsset, price, keeper1Key);
        priceMessages[2] = getPMsg(testAsset, price, keeper2Key);
        
        vm.expectRevert("Oracle: invalid signer");
        vm.prank(testKeeper);
        oracle.updatePrice(testAsset, priceMessages);
    }

    // ============ Error Cases Tests ============

    function test_OnlyKeeperCanUpdatePrice() public {
        uint256 price = 1000e18;
        PriceMessage[] memory pMsg = new PriceMessage[](1);
        pMsg[0] = getPMsg(testAsset, price, testKeeperPrivateKey);

        // Non-keeper should fail
        vm.expectRevert("Oracle: only keeper can call this function");
        oracle.updatePrice(testAsset, pMsg);
    }

    function test_InsufficientSignatures() public {
        // Oracle requires 3 signatures but we only provide 1
        uint256 price = 1000e18;
        PriceMessage[] memory pMsg = new PriceMessage[](1);
        pMsg[0] = getPMsg(testAsset, price, keeper1Key);

        vm.expectRevert("Oracle: not enough signatures");
        vm.prank(keeper1);
        oracle.updatePrice(testAsset, pMsg);
    }

    function test_DuplicateSigner() public {
        test_setKeeper();
        uint256 price = 1000e18;
        
        // Use same signer twice
        PriceMessage[] memory pMsg = new PriceMessage[](3);
        pMsg[0] = getPMsg(testAsset, price, keeper1Key);
        pMsg[1] = getPMsg(testAsset, price, keeper1Key); // Duplicate
        pMsg[2] = getPMsg(testAsset, price, keeper2Key);

        vm.expectRevert("Oracle: duplicate signer");
        vm.prank(keeper1);
        oracle.updatePrice(testAsset, pMsg);
    }

    function test_ExpiredTimestamp() public {
        test_setKeeper();
        uint256 price = 1000e18;
        uint256 oldTimestamp = block.timestamp - 11; // Beyond 10 second limit

        bytes32 digest = oracle.getPriceMessageHash(testAsset, price, block.chainid, oldTimestamp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(keeper1Key, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        PriceMessage[] memory pMsg = new PriceMessage[](3);
        pMsg[0] = PriceMessage({
            asset: testAsset,
            price: price,
            chainId: block.chainid,
            timestamp: oldTimestamp,
            signature: signature
        });
        pMsg[1] = getPMsg(testAsset, price, keeper2Key);
        pMsg[2] = getPMsg(testAsset, price, keeper3Key);

        vm.expectRevert("Oracle: invalid timestamp");
        vm.prank(keeper1);
        oracle.updatePrice(testAsset, pMsg);
    }

    function test_WrongAsset() public {
        test_setKeeper();
        uint256 price = 1000e18;
        address wrongAsset = makeAddr("wrongAsset");

        PriceMessage[] memory pMsg = new PriceMessage[](3);
        pMsg[0] = getPMsg(wrongAsset, price, keeper1Key); // Wrong asset in message
        pMsg[1] = getPMsg(testAsset, price, keeper2Key);
        pMsg[2] = getPMsg(testAsset, price, keeper3Key);

        vm.expectRevert("Oracle: wrong asset");
        vm.prank(keeper1);
        oracle.updatePrice(testAsset, pMsg); // Updating different asset
    }

    // ============ Pause Functionality Tests ============

    function test_PauseUnpause() public {
        vm.startPrank(deployer);
        
        // Pause oracle
        oracle.pause();
        
        // Should revert when paused
        vm.expectRevert();
        oracle.priceOf(testAsset);
        
        // Unpause oracle
        oracle.unpause();
        vm.stopPrank();
        
        // Now should work (though no price set, will revert for different reason)
        vm.expectRevert("Oracle: price not updated");
        oracle.priceOf(testAsset);
    }
}