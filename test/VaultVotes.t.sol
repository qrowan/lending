// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {Vault} from "../src/core/Vault.sol";
import {Config} from "../src/core/Config.sol";

contract VaultVotesTest is Test {
    Vault vault;
    Config config;
    ERC20Mock token;
    
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    function setUp() public {
        token = new ERC20Mock();
        config = new Config();
        vault = new Vault(address(token), address(config));
        
        // Mint tokens to users
        token.mint(alice, 1000e18);
        token.mint(bob, 2000e18);
        token.mint(charlie, 500e18);
    }

    function test_InitialVotingState() public {
        assertEq(vault.getVotes(alice), 0);
        assertEq(vault.getVotes(bob), 0);
        assertEq(vault.delegates(alice), address(0));
    }

    function test_VotingPowerAfterDeposit() public {
        vm.startPrank(alice);
        token.approve(address(vault), 100e18);
        uint256 shares = vault.deposit(100e18, alice);
        
        // No voting power until delegation
        assertEq(vault.getVotes(alice), 0);
        assertEq(vault.balanceOf(alice), shares);
        vm.stopPrank();
    }

    function test_SelfDelegation() public {
        vm.startPrank(alice);
        token.approve(address(vault), 100e18);
        uint256 shares = vault.deposit(100e18, alice);
        
        vault.delegate(alice); // Self-delegate
        
        assertEq(vault.getVotes(alice), shares);
        assertEq(vault.delegates(alice), alice);
        vm.stopPrank();
    }

    function test_DelegateToOther() public {
        vm.startPrank(alice);
        token.approve(address(vault), 100e18);
        uint256 shares = vault.deposit(100e18, alice);
        
        vault.delegate(bob); // Delegate to bob
        vm.stopPrank();
        
        assertEq(vault.getVotes(alice), 0);
        assertEq(vault.getVotes(bob), shares);
        assertEq(vault.delegates(alice), bob);
    }

    function test_MultipleDelegators() public {
        // Alice deposits and delegates to bob
        vm.startPrank(alice);
        token.approve(address(vault), 100e18);
        uint256 aliceShares = vault.deposit(100e18, alice);
        vault.delegate(bob);
        vm.stopPrank();
        
        // Charlie deposits and delegates to bob
        vm.startPrank(charlie);
        token.approve(address(vault), 200e18);
        uint256 charlieShares = vault.deposit(200e18, charlie);
        vault.delegate(bob);
        vm.stopPrank();
        
        // Bob receives delegated votes
        assertEq(vault.getVotes(bob), aliceShares + charlieShares);
    }

    function test_VotesChangesOverTime() public {
        vm.startPrank(alice);
        token.approve(address(vault), 200e18);
        
        // First deposit
        uint256 shares1 = vault.deposit(100e18, alice);
        vault.delegate(alice);
        assertEq(vault.getVotes(alice), shares1);
        
        // Second deposit increases votes
        uint256 shares2 = vault.deposit(100e18, alice);
        assertEq(vault.getVotes(alice), shares1 + shares2);
        vm.stopPrank();
    }

    function test_ClockFunction() public {
        assertEq(vault.clock(), uint48(block.number));
        
        vm.roll(100);
        assertEq(vault.clock(), 100);
    }
}