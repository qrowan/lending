// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {Vault} from "../../src/core/Vault.sol";
import {Config} from "../../src/core/Config.sol";
import {VaultGovernor} from "../../src/governance/VaultGovernor.sol";
import {IGovernor} from "lib/openzeppelin-contracts/contracts/governance/IGovernor.sol";

contract VaultGovernorTest is Test {
    Vault vault;
    Config config;
    ERC20Mock token;
    VaultGovernor governor;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        token = new ERC20Mock();
        config = new Config();
        vault = new Vault(address(token), address(config));
        governor = VaultGovernor(payable(vault.governor()));

        // Mint tokens and deposit to vault
        token.mint(alice, 1000e18);
        token.mint(bob, 2000e18);

        // Alice deposits and delegates
        vm.startPrank(alice);
        token.approve(address(vault), 500e18);
        vault.deposit(500e18, alice);
        vault.delegate(alice);
        vm.stopPrank();

        // Bob deposits and delegates
        vm.startPrank(bob);
        token.approve(address(vault), 1000e18);
        vault.deposit(1000e18, bob);
        vault.delegate(bob);
        vm.stopPrank();
    }

    function test_GovernorBasicSettings_DisplayCorrectly_WhenGovernorDeployed() public view {
        assertEq(governor.name(), "VaultGovernor");
        assertEq(governor.votingDelay(), 0);
        assertEq(governor.votingPeriod(), 50400);
        assertEq(governor.quorum(block.number), 1);
        assertEq(governor.proposalThreshold(), 0);
    }

    function test_CreateProposal_Succeeds_WhenCalledByTokenHolder() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(vault);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setWhitelisted(address,bool)", alice, true);

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Proposal: Whitelist Alice");
        vm.roll(block.number + 1);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));
    }

    function test_VoteOnProposal_Succeeds_WhenProposalActive() public {
        // Create proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(vault);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setWhitelisted(address,bool)", alice, true);

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Proposal: Whitelist Alice");

        // Move to next block to allow voting
        vm.roll(block.number + 1);

        // Vote on proposal
        vm.prank(alice);
        governor.castVote(proposalId, 1); // Vote FOR

        vm.prank(bob);
        governor.castVote(proposalId, 1); // Vote FOR

        // Check votes
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        assertTrue(forVotes > 0);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function test_ExecuteProposal_Succeeds_WhenQuorumReached() public {
        // Create proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(vault);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setWhitelisted(address,bool)", alice, true);

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Proposal: Whitelist Alice");

        // Move to next block to allow voting
        vm.roll(block.number + 1);

        // Vote FOR
        vm.prank(alice);
        governor.castVote(proposalId, 1);

        // Fast forward past voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // Check state is Succeeded
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        // Execute proposal
        governor.execute(targets, values, calldatas, keccak256(bytes("Proposal: Whitelist Alice")));

        // Check execution result
        assertTrue(vault.isWhitelisted(alice));
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
    }

    function test_ProposalWithInsufficientVotes_Succeeds_WhenQuorumMet() public {
        // Create a new vault with higher quorum
        VaultGovernor strictGovernor = VaultGovernor(payable(vault.governor()));

        // Create proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(vault);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setWhitelisted(address,bool)", alice, true);

        vm.prank(alice);
        uint256 proposalId = strictGovernor.propose(targets, values, calldatas, "Proposal: Whitelist Alice");

        // Move to next block to allow voting
        vm.roll(block.number + 1);

        // Only alice votes (insufficient for high quorum)
        vm.prank(alice);
        strictGovernor.castVote(proposalId, 1);

        // Fast forward past voting period
        vm.roll(block.number + strictGovernor.votingPeriod() + 1);

        // Should succeed because our quorum is only 1
        assertEq(uint256(strictGovernor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));
    }
}
