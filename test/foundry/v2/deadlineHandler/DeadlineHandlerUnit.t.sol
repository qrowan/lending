// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {DeadlineHandler} from "../../../../src/v2/core/core/DeadlineHandler.sol";

contract MockDeadlineHandler is DeadlineHandler {
    function publicCheckDeadline(uint256 deadline) external view {
        _checkDeadline(deadline);
    }

    function publicCheckDeadlineWithModifier(uint256 deadline) external view checkDeadline(deadline) {
        // Function body executes only if deadline is valid
    }
}

contract DeadlineHandlerUnitTest is Test {
    MockDeadlineHandler internal deadlineHandler;

    function setUp() public {
        deadlineHandler = new MockDeadlineHandler();
    }

    // ============ Unit Tests ============

    function test_CheckDeadline_Succeeds_WhenDeadlineIsFuture() public {
        uint256 futureDeadline = block.timestamp + 1000;

        deadlineHandler.publicCheckDeadline(futureDeadline);
    }

    function test_RevertIf_CheckDeadlineWhenExpired() public {
        uint256 pastDeadline = block.timestamp - 1;

        vm.expectRevert(DeadlineHandler.Expired.selector);
        deadlineHandler.publicCheckDeadline(pastDeadline);
    }

    function test_CheckDeadlineModifier_Succeeds_WhenDeadlineIsFuture() public {
        uint256 futureDeadline = block.timestamp + 1000;

        deadlineHandler.publicCheckDeadlineWithModifier(futureDeadline);
    }

    function test_RevertIf_CheckDeadlineModifierWhenExpired() public {
        uint256 pastDeadline = block.timestamp - 1;

        vm.expectRevert(DeadlineHandler.Expired.selector);
        deadlineHandler.publicCheckDeadlineWithModifier(pastDeadline);
    }

    function test_CheckDeadline_Succeeds_WhenDeadlineIsCurrentTimestamp() public {
        uint256 currentDeadline = block.timestamp;

        deadlineHandler.publicCheckDeadline(currentDeadline);
    }

    function test_CheckDeadline_RespectsTimeProgression_AfterTimeAdvancement() public {
        uint256 shortDeadline = block.timestamp + 100;

        deadlineHandler.publicCheckDeadline(shortDeadline);

        vm.warp(block.timestamp + 150);

        vm.expectRevert(DeadlineHandler.Expired.selector);
        deadlineHandler.publicCheckDeadline(shortDeadline);
    }

    function test_CheckDeadline_WorksCorrectly_WithMaxUint256() public {
        uint256 maxDeadline = type(uint256).max;

        deadlineHandler.publicCheckDeadline(maxDeadline);
    }

    function test_RevertIf_CheckDeadlineWithZeroDeadline() public {
        uint256 zeroDeadline = 0;

        vm.expectRevert(DeadlineHandler.Expired.selector);
        deadlineHandler.publicCheckDeadline(zeroDeadline);
    }

    function test_CheckDeadline_WorksCorrectly_WithVeryFarFutureDeadline() public {
        uint256 farFutureDeadline = block.timestamp + 365 days;

        deadlineHandler.publicCheckDeadline(farFutureDeadline);
    }
}
