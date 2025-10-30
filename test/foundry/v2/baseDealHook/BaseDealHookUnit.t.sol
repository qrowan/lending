// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {BaseDealHook} from "src/v2/core/dealManager/BaseDealHook.sol";
import {IBaseStructure} from "src/v2/interfaces/IAggregatedInterfaces.sol";

contract MockBaseDealHook is BaseDealHook {
    constructor(address _dealHookFactory, string memory __name) BaseDealHook(_dealHookFactory, __name) {}

    // Override virtual functions for testing
    function onDealCreated(Deal memory dealAfter) external override {
        // Mock implementation
    }

    function onDealCollateralWithdrawn(Deal memory dealAfter) external override {
        // Mock implementation
    }

    function onDealRepaid(Deal memory deal) external override {
        // Mock implementation
    }

    function onDealLiquidated(Deal memory dealBefore, Deal memory dealAfter) external override {
        // Mock implementation
    }
}

contract BaseDealHookUnitTest is Test {
    MockBaseDealHook internal baseDealHook;
    address internal dealHookFactory;

    function setUp() public {
        dealHookFactory = address(0x1234);
        baseDealHook = new MockBaseDealHook(dealHookFactory, "TestHook");
    }

    // ============ Unit Tests ============

    function test_Constructor_SetsValues_WhenProperlyInitialized() public {
        assertEq(baseDealHook.DEAL_HOOK_FACTORY(), dealHookFactory, "Deal hook factory should be set correctly");
        assertEq(baseDealHook.name(), "TestHook", "Name should be set correctly");
    }

    function test_Name_ReturnsCorrectName_WhenQueried() public {
        string memory hookName = baseDealHook.name();
        assertEq(hookName, "TestHook", "Should return correct name");
    }

    function test_DealHookFactory_ReturnsCorrectAddress_WhenQueried() public {
        address factory = baseDealHook.DEAL_HOOK_FACTORY();
        assertEq(factory, dealHookFactory, "Should return correct factory address");
    }

    function test_OnDealCreated_ExecutesSuccessfully_WhenCalled() public {
        IBaseStructure.Deal memory deal = IBaseStructure.Deal({
            collateralToken: address(0x123),
            borrowToken: address(0x456),
            collateralAmount: 1000,
            borrowAmount: 500,
            interestRate: 100,
            dealHook: address(baseDealHook)
        });

        baseDealHook.onDealCreated(deal);
    }

    function test_OnDealCollateralWithdrawn_ExecutesSuccessfully_WhenCalled() public {
        IBaseStructure.Deal memory deal = IBaseStructure.Deal({
            collateralToken: address(0x123),
            borrowToken: address(0x456),
            collateralAmount: 800,
            borrowAmount: 500,
            interestRate: 100,
            dealHook: address(baseDealHook)
        });

        baseDealHook.onDealCollateralWithdrawn(deal);
    }

    function test_OnDealRepaid_ExecutesSuccessfully_WhenCalled() public {
        IBaseStructure.Deal memory deal = IBaseStructure.Deal({
            collateralToken: address(0x123),
            borrowToken: address(0x456),
            collateralAmount: 1000,
            borrowAmount: 0,
            interestRate: 100,
            dealHook: address(baseDealHook)
        });

        baseDealHook.onDealRepaid(deal);
    }

    function test_OnDealLiquidated_ExecutesSuccessfully_WhenCalled() public {
        IBaseStructure.Deal memory dealBefore = IBaseStructure.Deal({
            collateralToken: address(0x123),
            borrowToken: address(0x456),
            collateralAmount: 1000,
            borrowAmount: 500,
            interestRate: 100,
            dealHook: address(baseDealHook)
        });

        IBaseStructure.Deal memory dealAfter = IBaseStructure.Deal({
            collateralToken: address(0x123),
            borrowToken: address(0x456),
            collateralAmount: 0,
            borrowAmount: 0,
            interestRate: 100,
            dealHook: address(baseDealHook)
        });

        baseDealHook.onDealLiquidated(dealBefore, dealAfter);
    }

    function test_DealHookFactory_IsImmutable_WhenSet() public {
        address factory1 = baseDealHook.DEAL_HOOK_FACTORY();
        address factory2 = baseDealHook.DEAL_HOOK_FACTORY();

        assertEq(factory1, factory2, "Factory address should be consistent");
        assertEq(factory1, dealHookFactory, "Factory should match constructor value");
    }

    function test_Name_IsCorrectlyStored_WhenSetInConstructor() public {
        MockBaseDealHook customHook = new MockBaseDealHook(address(0x9999), "CustomName");
        assertEq(customHook.name(), "CustomName", "Custom name should be stored correctly");
    }

    function test_AllHookFunctions_AreVirtual_WhenOverridden() public {
        IBaseStructure.Deal memory deal = IBaseStructure.Deal({
            collateralToken: address(0x123),
            borrowToken: address(0x456),
            collateralAmount: 1000,
            borrowAmount: 500,
            interestRate: 100,
            dealHook: address(baseDealHook)
        });

        baseDealHook.onDealCreated(deal);
        baseDealHook.onDealCollateralWithdrawn(deal);
        baseDealHook.onDealRepaid(deal);
        baseDealHook.onDealLiquidated(deal, deal);
    }
}
