// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {DealHookFactory} from "src/core/dealManager/DealHookFactory.sol";
import {IDealHook} from "src/interfaces/IAggregatedInterfaces.sol";

contract DealHookFactoryTest is Test {
    DealHookFactory internal factory;
    MockDealHook internal mockHook;

    function setUp() public {
        factory = new DealHookFactory(address(this));
        mockHook = new MockDealHook("TestHook");
    }

    function test_AddDealHook_Succeeds_WhenCalledByOwner() public {
        factory.addDealHook(address(mockHook));

        factory.validateDealHook(address(mockHook));
    }

    function test_RevertIf_DealHookNotFound() public {
        address nonExistentHook = address(0x999);

        vm.expectRevert(DealHookFactory.DealHookNotFound.selector);
        factory.validateDealHook(nonExistentHook);
    }

    function test_RevertIf_AddDealHookAlreadyExists() public {
        factory.addDealHook(address(mockHook));

        vm.expectRevert("Hook already exists");
        factory.addDealHook(address(mockHook));
    }

    function test_RevertIf_AddDealHookCalledByNonOwner() public {
        address notOwner = address(0x456);

        vm.prank(notOwner);
        vm.expectRevert();
        factory.addDealHook(address(mockHook));
    }
}

contract MockDealHook is IDealHook {
    string private _name;
    uint256 public numberOfCreated;
    uint256 public numberOfWithdrawn;
    uint256 public numberOfRepaid;
    uint256 public numberOfLiquidated;

    constructor(string memory __name) {
        _name = __name;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function onDealCreated(Deal memory) external override {
        numberOfCreated++;
    }

    function onDealCollateralWithdrawn(Deal memory) external override {
        numberOfWithdrawn++;
    }

    function onDealRepaid(Deal memory) external override {
        numberOfRepaid++;
    }

    function onDealLiquidated(Deal memory, Deal memory) external override {
        numberOfLiquidated++;
    }
}
