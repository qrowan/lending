// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {BaseDealHook} from "src/core/dealManager/BaseDealHook.sol";
import {IBaseStructure} from "src/interfaces/IAggregatedInterfaces.sol";

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

contract BaseDealHookFuzzTest is Test {
    // ============ Fuzz Tests ============

    function testFuzz_Constructor_WorksCorrectly_WithRandomInputs(address factoryAddress, string memory hookName)
        public
    {
        vm.assume(bytes(hookName).length > 0);

        MockBaseDealHook hook = new MockBaseDealHook(factoryAddress, hookName);

        assertEq(hook.DEAL_HOOK_FACTORY(), factoryAddress, "Factory should be set correctly");
        assertEq(hook.name(), hookName, "Name should be set correctly");
    }

    function testFuzz_Name_AlwaysReturnsSetValue_WithVariousStrings(string memory hookName) public {
        vm.assume(bytes(hookName).length > 0);

        MockBaseDealHook hook = new MockBaseDealHook(address(0x123), hookName);

        assertEq(hook.name(), hookName, "Name should always return the set value");
    }

    function testFuzz_DealHookFactory_AlwaysReturnsSetAddress_WithVariousAddresses(address factoryAddress) public {
        MockBaseDealHook hook = new MockBaseDealHook(factoryAddress, "TestHook");

        assertEq(hook.DEAL_HOOK_FACTORY(), factoryAddress, "Factory should always return the set address");
    }

    function testFuzz_OnDealCreated_HandlesVariousDeals_WithoutReverting(
        address collateralToken,
        address borrowToken,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 interestRate,
        address dealHook
    ) public {
        MockBaseDealHook hook = new MockBaseDealHook(address(0x123), "TestHook");

        IBaseStructure.Deal memory deal = IBaseStructure.Deal({
            collateralToken: collateralToken,
            borrowToken: borrowToken,
            collateralAmount: collateralAmount,
            borrowAmount: borrowAmount,
            interestRate: interestRate,
            dealHook: dealHook
        });

        hook.onDealCreated(deal);
    }

    function testFuzz_OnDealCollateralWithdrawn_HandlesVariousDeals_WithoutReverting(
        address collateralToken,
        address borrowToken,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 interestRate,
        address dealHook
    ) public {
        MockBaseDealHook hook = new MockBaseDealHook(address(0x123), "TestHook");

        IBaseStructure.Deal memory deal = IBaseStructure.Deal({
            collateralToken: collateralToken,
            borrowToken: borrowToken,
            collateralAmount: collateralAmount,
            borrowAmount: borrowAmount,
            interestRate: interestRate,
            dealHook: dealHook
        });

        hook.onDealCollateralWithdrawn(deal);
    }

    function testFuzz_OnDealRepaid_HandlesVariousDeals_WithoutReverting(
        address collateralToken,
        address borrowToken,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 interestRate,
        address dealHook
    ) public {
        MockBaseDealHook hook = new MockBaseDealHook(address(0x123), "TestHook");

        IBaseStructure.Deal memory deal = IBaseStructure.Deal({
            collateralToken: collateralToken,
            borrowToken: borrowToken,
            collateralAmount: collateralAmount,
            borrowAmount: borrowAmount,
            interestRate: interestRate,
            dealHook: dealHook
        });

        hook.onDealRepaid(deal);
    }

    function testFuzz_OnDealLiquidated_HandlesVariousDeals_WithoutReverting(
        address collateralToken1,
        address borrowToken1,
        uint256 collateralAmount1,
        uint256 borrowAmount1,
        uint256 interestRate1,
        address dealHook1,
        address collateralToken2,
        address borrowToken2,
        uint256 collateralAmount2,
        uint256 borrowAmount2,
        uint256 interestRate2,
        address dealHook2
    ) public {
        MockBaseDealHook hook = new MockBaseDealHook(address(0x123), "TestHook");

        IBaseStructure.Deal memory dealBefore = IBaseStructure.Deal({
            collateralToken: collateralToken1,
            borrowToken: borrowToken1,
            collateralAmount: collateralAmount1,
            borrowAmount: borrowAmount1,
            interestRate: interestRate1,
            dealHook: dealHook1
        });

        IBaseStructure.Deal memory dealAfter = IBaseStructure.Deal({
            collateralToken: collateralToken2,
            borrowToken: borrowToken2,
            collateralAmount: collateralAmount2,
            borrowAmount: borrowAmount2,
            interestRate: interestRate2,
            dealHook: dealHook2
        });

        hook.onDealLiquidated(dealBefore, dealAfter);
    }

    function testFuzz_MultipleHooks_IndependentBehavior_WithDifferentFactories(
        address factory1,
        address factory2,
        string memory name1,
        string memory name2
    ) public {
        vm.assume(bytes(name1).length > 0);
        vm.assume(bytes(name2).length > 0);
        vm.assume(factory1 != factory2);

        MockBaseDealHook hook1 = new MockBaseDealHook(factory1, name1);
        MockBaseDealHook hook2 = new MockBaseDealHook(factory2, name2);

        assertEq(hook1.DEAL_HOOK_FACTORY(), factory1, "Hook1 should have factory1");
        assertEq(hook2.DEAL_HOOK_FACTORY(), factory2, "Hook2 should have factory2");
        assertEq(hook1.name(), name1, "Hook1 should have name1");
        assertEq(hook2.name(), name2, "Hook2 should have name2");

        assertTrue(hook1.DEAL_HOOK_FACTORY() != hook2.DEAL_HOOK_FACTORY(), "Hooks should have different factories");
    }

    function testFuzz_AllHookFunctions_ConsistentBehavior_WithSameDeal(
        address collateralToken,
        address borrowToken,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 interestRate,
        address dealHookAddress
    ) public {
        MockBaseDealHook hook = new MockBaseDealHook(address(0x123), "TestHook");

        IBaseStructure.Deal memory deal = IBaseStructure.Deal({
            collateralToken: collateralToken,
            borrowToken: borrowToken,
            collateralAmount: collateralAmount,
            borrowAmount: borrowAmount,
            interestRate: interestRate,
            dealHook: dealHookAddress
        });

        hook.onDealCreated(deal);
        hook.onDealCollateralWithdrawn(deal);
        hook.onDealRepaid(deal);
        hook.onDealLiquidated(deal, deal);
    }

    function testFuzz_HookCreation_WorksWithEdgeCases_ForFactoryAndName(address factory, bytes memory nameBytes)
        public
    {
        nameBytes = abi.encodePacked(nameBytes);
        vm.assume(nameBytes.length > 0 && nameBytes.length <= 1000);

        string memory hookName = string(nameBytes);

        MockBaseDealHook hook = new MockBaseDealHook(factory, hookName);

        assertEq(hook.DEAL_HOOK_FACTORY(), factory, "Factory should be set regardless of value");
        assertEq(hook.name(), hookName, "Name should be set regardless of content");
    }
}
