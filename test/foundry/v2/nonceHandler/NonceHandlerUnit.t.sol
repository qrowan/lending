// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NonceHandler} from "src/v2/core/core/NonceHandler.sol";

contract MockNonceHandler is NonceHandler {
    function publicConsumeNonce(address user, uint256 expectedNonce) external {
        _consumeNonce(user, expectedNonce);
    }
}

contract NonceHandlerUnitTest is Test {
    MockNonceHandler internal nonceHandler;

    // Events
    event NonceConsumed(address indexed user, uint256 indexed nonce);

    function setUp() public {
        nonceHandler = new MockNonceHandler();
    }

    // ============ Unit Tests ============

    function test_GetCurrentNonce_ReturnsZero_WhenUserHasNoNonce() public view {
        address user = address(0x123);

        uint256 nonce = nonceHandler.getCurrentNonce(user);

        assertEq(nonce, 0, "Initial nonce should be 0");
    }

    function test_ConsumeNonce_IncrementsNonce_WhenValidNonceProvided() public {
        address user = address(0x123);

        vm.prank(user);
        nonceHandler.consumeNonce(0);

        uint256 newNonce = nonceHandler.getCurrentNonce(user);
        assertEq(newNonce, 1, "Nonce should increment to 1");
    }

    function test_RevertIf_ConsumeNonceWithWrongNonce() public {
        address user = address(0x123);

        vm.prank(user);
        vm.expectRevert(); // Should revert when trying to consume nonce 1 when current is 0
        nonceHandler.consumeNonce(1);
    }

    function test_ConsumeNonce_EmitsEvent_WhenNonceConsumed() public {
        address user = address(0x123);
        uint256 expectedNonce = 0;

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit NonceConsumed(user, expectedNonce);
        nonceHandler.consumeNonce(expectedNonce);
    }

    function test_InternalConsumeNonce_WorksCorrectly_WhenCalledDirectly() public {
        address user = address(0x123);
        uint256 expectedNonce = 0;

        nonceHandler.publicConsumeNonce(user, expectedNonce);

        uint256 newNonce = nonceHandler.getCurrentNonce(user);
        assertEq(newNonce, 1, "Nonce should increment to 1");
    }

    function test_RevertIf_InternalConsumeNonceWithWrongNonce() public {
        address user = address(0x123);

        vm.expectRevert();
        nonceHandler.publicConsumeNonce(user, 1); // Wrong nonce, should be 0
    }

    function test_GetCurrentNonce_ReturnsCorrectValue_AfterMultipleConsumptions() public {
        address user = address(0x123);

        // Consume nonces sequentially
        vm.startPrank(user);
        nonceHandler.consumeNonce(0);
        nonceHandler.consumeNonce(1);
        nonceHandler.consumeNonce(2);
        vm.stopPrank();

        uint256 finalNonce = nonceHandler.getCurrentNonce(user);
        assertEq(finalNonce, 3, "Nonce should be 3 after consuming 0, 1, 2");
    }

    function test_ConsumeNonce_WorksCorrectly_WithSequentialNonces() public {
        address user = address(0x123);

        vm.startPrank(user);

        // Test sequential nonce consumption
        for (uint256 i = 0; i < 5; i++) {
            uint256 currentNonce = nonceHandler.getCurrentNonce(user);
            assertEq(currentNonce, i, "Current nonce should match iteration");

            nonceHandler.consumeNonce(i);

            uint256 newNonce = nonceHandler.getCurrentNonce(user);
            assertEq(newNonce, i + 1, "Nonce should increment");
        }

        vm.stopPrank();
    }

    function test_RevertIf_ConsumeNonceOutOfOrder() public {
        address user = address(0x123);

        vm.startPrank(user);

        // Consume nonce 0 successfully
        nonceHandler.consumeNonce(0);

        // Try to consume nonce 0 again (should fail)
        vm.expectRevert();
        nonceHandler.consumeNonce(0);

        // Try to consume nonce 2 (skipping 1, should fail)
        vm.expectRevert();
        nonceHandler.consumeNonce(2);

        vm.stopPrank();
    }

    function test_NonceStorage_IndependentPerUser_WhenMultipleUsers() public {
        address user1 = address(0x123);
        address user2 = address(0x456);

        // User1 consumes some nonces
        vm.startPrank(user1);
        nonceHandler.consumeNonce(0);
        nonceHandler.consumeNonce(1);
        vm.stopPrank();

        // User2 starts from 0
        vm.prank(user2);
        nonceHandler.consumeNonce(0);

        // Verify independent nonce tracking
        assertEq(nonceHandler.getCurrentNonce(user1), 2, "User1 should have nonce 2");
        assertEq(nonceHandler.getCurrentNonce(user2), 1, "User2 should have nonce 1");
    }
}
