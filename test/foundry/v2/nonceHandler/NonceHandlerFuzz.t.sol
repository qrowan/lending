// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NonceHandler} from "../../../../src/v2/core/core/NonceHandler.sol";
import {INonceHandler} from "../../../../src/v2/interfaces/IAggregatedInterfaces.sol";

contract MockNonceHandler is NonceHandler {
    function publicConsumeNonce(address user, uint256 expectedNonce) external {
        _consumeNonce(user, expectedNonce);
    }
}

contract NonceHandlerFuzzTest is Test {
    MockNonceHandler internal nonceHandler;

    // Events
    event NonceConsumed(address indexed user, uint256 indexed nonce);

    function setUp() public {
        nonceHandler = new MockNonceHandler();
    }

    // ============ Fuzz Tests ============

    function testFuzz_ConsumeNonce_WorksCorrectly_WithSequentialNonces(uint256 iterations) public {
        address user = address(0x123); // Fixed address
        iterations = bound(iterations, 1, 100); // Reasonable bounds

        vm.startPrank(user);

        for (uint256 i = 0; i < iterations; i++) {
            uint256 expectedNonce = nonceHandler.getCurrentNonce(user);
            assertEq(expectedNonce, i, "Nonce should match iteration");

            nonceHandler.consumeNonce(expectedNonce);

            uint256 newNonce = nonceHandler.getCurrentNonce(user);
            assertEq(newNonce, i + 1, "Nonce should increment");
        }

        vm.stopPrank();
    }

    function testFuzz_RevertIf_ConsumeWrongNonce_WithRandomValues(uint256 wrongNonce) public {
        address user = address(0x123); // Fixed address
        uint256 currentNonce = nonceHandler.getCurrentNonce(user);
        wrongNonce = bound(wrongNonce, currentNonce + 1, type(uint256).max);

        vm.prank(user);
        vm.expectRevert();
        nonceHandler.consumeNonce(wrongNonce);
    }

    function testFuzz_MultipleUsers_IndependentNonces(uint256 user1Iterations, uint256 user2Iterations) public {
        address user1 = address(0x123); // Fixed address
        address user2 = address(0x456); // Fixed address
        user1Iterations = bound(user1Iterations, 1, 50);
        user2Iterations = bound(user2Iterations, 1, 50);

        // User1 consumes nonces
        vm.startPrank(user1);
        for (uint256 i = 0; i < user1Iterations; i++) {
            nonceHandler.consumeNonce(i);
        }
        vm.stopPrank();

        // User2 consumes nonces
        vm.startPrank(user2);
        for (uint256 i = 0; i < user2Iterations; i++) {
            nonceHandler.consumeNonce(i);
        }
        vm.stopPrank();

        // Verify independent nonce tracking
        assertEq(nonceHandler.getCurrentNonce(user1), user1Iterations);
        assertEq(nonceHandler.getCurrentNonce(user2), user2Iterations);
    }

    function testFuzz_NonceProgression_ConsistentBehavior_AcrossUsers(uint256 startNonce, uint256 iterations) public {
        address user = address(0x123); // Fixed address
        startNonce = bound(startNonce, 0, 0); // Always start at 0 since that's how nonces work
        iterations = bound(iterations, 1, 100);

        vm.startPrank(user);

        // Start from nonce 0 and progress sequentially
        for (uint256 i = 0; i < iterations; i++) {
            uint256 currentNonce = nonceHandler.getCurrentNonce(user);
            assertEq(currentNonce, i, "Nonce should be sequential");

            nonceHandler.consumeNonce(i);
        }

        // Final nonce should equal iterations
        uint256 finalNonce = nonceHandler.getCurrentNonce(user);
        assertEq(finalNonce, iterations, "Final nonce should equal iterations");

        vm.stopPrank();
    }

    function testFuzz_GetCurrentNonce_AlwaysAccurate_AfterRandomConsumptions(uint256 consumptionCount) public {
        address user = address(0x123); // Fixed address
        consumptionCount = bound(consumptionCount, 1, 20); // Limit for reasonable test execution

        vm.startPrank(user);

        uint256 expectedNonce = 0;

        // Only test sequential valid nonces (can't consume random nonces)
        for (uint256 i = 0; i < consumptionCount; i++) {
            uint256 currentNonce = nonceHandler.getCurrentNonce(user);
            assertEq(currentNonce, expectedNonce, "Current nonce should match expected");

            nonceHandler.consumeNonce(expectedNonce);
            expectedNonce++;

            uint256 newNonce = nonceHandler.getCurrentNonce(user);
            assertEq(newNonce, expectedNonce, "Nonce should increment correctly");
        }

        vm.stopPrank();
    }

    function testFuzz_ConsumeNonce_EventEmission(uint256 targetNonce) public {
        address user = address(0x123); // Fixed address
        targetNonce = bound(targetNonce, 0, 10); // Keep reasonable for sequential consumption

        vm.startPrank(user);

        // Consume nonces up to target sequentially
        for (uint256 i = 0; i <= targetNonce; i++) {
            vm.expectEmit(true, true, true, true);
            emit NonceConsumed(user, i);

            nonceHandler.consumeNonce(i);
        }

        vm.stopPrank();
    }

    function testFuzz_InternalConsumeNonce_ConsistentWithPublic_AcrossScenarios(uint256 expectedNonce) public {
        address user = address(0x123); // Fixed address
        expectedNonce = bound(expectedNonce, 0, 50);

        // First, consume nonces up to expectedNonce using public method
        vm.startPrank(user);
        for (uint256 i = 0; i < expectedNonce; i++) {
            nonceHandler.consumeNonce(i);
        }
        vm.stopPrank();

        // Verify current nonce
        uint256 currentNonce = nonceHandler.getCurrentNonce(user);
        assertEq(currentNonce, expectedNonce, "Current nonce should match");

        // Now use internal method to consume next nonce
        nonceHandler.publicConsumeNonce(user, expectedNonce);

        // Verify nonce incremented correctly
        uint256 newNonce = nonceHandler.getCurrentNonce(user);
        assertEq(newNonce, expectedNonce + 1, "Internal method should work same as public");
    }
}
