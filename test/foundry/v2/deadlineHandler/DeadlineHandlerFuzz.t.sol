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

contract DeadlineHandlerFuzzTest is Test {
    MockDeadlineHandler internal deadlineHandler;

    function setUp() public {
        deadlineHandler = new MockDeadlineHandler();
    }

    // ============ Fuzz Tests ============

    function testFuzz_CheckDeadline_WorksCorrectly_WithValidDeadlines(uint256 futureTimestamp) public {
        futureTimestamp = bound(futureTimestamp, block.timestamp + 1, type(uint256).max);

        deadlineHandler.publicCheckDeadline(futureTimestamp);
    }

    function testFuzz_RevertIf_CheckDeadlineWithExpiredTimestamps(uint256 pastTimestamp) public {
        pastTimestamp = bound(pastTimestamp, 0, block.timestamp - 1);

        vm.expectRevert(DeadlineHandler.Expired.selector);
        deadlineHandler.publicCheckDeadline(pastTimestamp);
    }

    function testFuzz_CheckDeadlineModifier_WorksCorrectly_WithVariousTimestamps(uint256 deadline) public {
        if (deadline >= block.timestamp) {
            deadlineHandler.publicCheckDeadlineWithModifier(deadline);
        } else {
            vm.expectRevert(DeadlineHandler.Expired.selector);
            deadlineHandler.publicCheckDeadlineWithModifier(deadline);
        }
    }

    function testFuzz_DeadlineValidation_ConsistentBehavior_AcrossTimeRanges(uint256 deadline, uint256 timeWarp)
        public
    {
        deadline = bound(deadline, block.timestamp + 1, type(uint256).max / 2);
        timeWarp = bound(timeWarp, 1, type(uint256).max / 2);

        deadlineHandler.publicCheckDeadline(deadline);

        if (deadline < block.timestamp + timeWarp) {
            vm.warp(block.timestamp + timeWarp);
            vm.expectRevert(DeadlineHandler.Expired.selector);
            deadlineHandler.publicCheckDeadline(deadline);
        } else {
            vm.warp(block.timestamp + timeWarp);
            deadlineHandler.publicCheckDeadline(deadline);
        }
    }

    function testFuzz_CheckDeadline_BoundaryConditions_AroundCurrentTime(uint256 offset) public {
        offset = bound(offset, 1, 1000);

        uint256 futureDeadline = block.timestamp + offset;
        deadlineHandler.publicCheckDeadline(futureDeadline);

        uint256 pastDeadline = block.timestamp - offset;
        vm.expectRevert(DeadlineHandler.Expired.selector);
        deadlineHandler.publicCheckDeadline(pastDeadline);
    }

    function testFuzz_CheckDeadline_ExtremeValues_MaxAndMinTimestamps(bool useMax) public {
        if (useMax) {
            deadlineHandler.publicCheckDeadline(type(uint256).max);
        } else {
            vm.expectRevert(DeadlineHandler.Expired.selector);
            deadlineHandler.publicCheckDeadline(0);
        }
    }
}
