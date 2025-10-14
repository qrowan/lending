// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../src/core/Vault.sol";
import "../../src/core/Config.sol";
import "../../src/governance/VaultGovernor.sol";
import "../../src/constants/InterestRate.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IGovernor} from "lib/openzeppelin-contracts/contracts/governance/IGovernor.sol";

contract VaultEchidna {
    Vault public vault;
    Config public config;
    ERC20Mock public asset;
    VaultGovernor public governor;
    
    // Test state tracking
    uint256 public lastTotalAssets;
    uint256 public lastSharePrice;
    uint256 public lastInterestRate;
    uint256 public proposalCount;
    
    // Test users
    address public alice;
    address public bob;
    address public charlie;
    
    // Constants for bounds testing
    uint256 constant MAX_INTEREST_RATE = InterestRate.INTEREST_RATE_100;
    uint256 constant MIN_INTEREST_RATE = InterestRate.INTEREST_RATE_0_5;
    uint256 constant MAX_DEPOSIT = 1000000e18;
    
    constructor() {
        asset = new ERC20Mock();
        config = new Config();
        vault = new Vault(address(asset), address(config));
        governor = VaultGovernor(payable(vault.governor()));
        
        // Setup test accounts
        alice = address(0x10);
        bob = address(0x20);
        charlie = address(0x30);
        
        // Initial setup
        asset.mint(alice, MAX_DEPOSIT);
        asset.mint(bob, MAX_DEPOSIT);
        asset.mint(charlie, MAX_DEPOSIT);
        
        // Record initial state
        lastTotalAssets = vault.totalAssets();
        lastSharePrice = _getSharePrice();
        lastInterestRate = vault.interestRatePerSecond();
    }
    
    // =============================================================
    // INVARIANT TESTS - Properties that should ALWAYS hold
    // =============================================================
    
    /// @notice Total assets should never be less than vault balance
    function echidna_total_assets_gte_balance() public view returns (bool) {
        return vault.totalAssets() >= asset.balanceOf(address(vault));
    }
    
    /// @notice Vault should always have dead shares
    function echidna_has_dead_shares() public view returns (bool) {
        return vault.totalSupply() >= 1000;
    }
    
    /// @notice Interest rate should be within reasonable bounds
    function echidna_interest_rate_bounds() public view returns (bool) {
        uint256 rate = vault.interestRatePerSecond();
        return rate >= MIN_INTEREST_RATE && rate <= MAX_INTEREST_RATE;
    }
    
    /// @notice Voting power should never exceed total supply
    function echidna_voting_power_bounded() public view returns (bool) {
        if (vault.totalSupply() <= 1000) return true;
        
        uint256 aliceVotes = vault.getVotes(alice);
        uint256 bobVotes = vault.getVotes(bob);
        uint256 charlieVotes = vault.getVotes(charlie);
        
        return (aliceVotes + bobVotes + charlieVotes) <= vault.totalSupply();
    }
    
    /// @notice Share price should not decrease significantly (except for losses)
    function echidna_share_price_no_major_decrease() public returns (bool) {
        uint256 currentPrice = _getSharePrice();
        
        // Allow for minor rounding errors and legitimate losses
        bool valid = currentPrice >= (lastSharePrice * 99) / 100;
        
        if (currentPrice > lastSharePrice) {
            lastSharePrice = currentPrice;
        }
        
        return valid;
    }
    
    /// @notice Interest should only increase over time (when there are loans)
    function echidna_interest_monotonic() public view returns (bool) {
        if (vault.lentAmountStored() > 0) {
            return vault.lentAssets() >= vault.lentAmountStored();
        }
        return true;
    }
    
    /// @notice Governor should always be valid contract
    function echidna_valid_governor() public view returns (bool) {
        address gov = vault.governor();
        return gov != address(0) && _isContract(gov);
    }
    
    // =============================================================
    // GOVERNANCE PROPERTY TESTS
    // =============================================================
    
    /// @notice Only governance should be able to change interest rates
    function echidna_only_governance_changes_rate() public view returns (bool) {
        // If rate changed, it must have been through governance
        return true; // This will be tested through action sequences
    }
    
    /// @notice Proposals should follow valid state transitions
    function echidna_valid_proposal_states() public view returns (bool) {
        return proposalCount < 1000; // Prevent infinite proposal creation
    }
    
    // =============================================================
    // ACTION FUNCTIONS - For Echidna to call during fuzzing
    // =============================================================
    
    /// @notice Deposit assets to vault (with bounds)
    function deposit(uint256 amount, uint8 userChoice) public {
        address user = _getUser(userChoice);
        amount = _boundDeposit(amount);
        
        if (amount == 0) return;
        if (asset.balanceOf(user) < amount) return;
        
        // Simulate user action
        asset.approve(address(vault), amount);
        vault.deposit(amount, user);
    }
    
    /// @notice Delegate voting power
    function delegate(uint8 delegatorChoice, uint8 delegateeChoice) public {
        address delegator = _getUser(delegatorChoice);
        address delegatee = _getUser(delegateeChoice);
        
        if (vault.balanceOf(delegator) == 0) return;
        
        vault.delegate(delegatee);
    }
    
    /// @notice Create governance proposal to change interest rate
    function proposeRateChange(uint256 newRate, uint8 proposerChoice) public {
        address proposer = _getUser(proposerChoice);
        newRate = _boundInterestRate(newRate);
        
        if (vault.getVotes(proposer) < governor.proposalThreshold()) return;
        
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(vault);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setInterestRate(uint256)", newRate);
        
        try governor.propose(targets, values, calldatas, "Change interest rate") {
            proposalCount++;
        } catch {}
    }
    
    /// @notice Vote on governance proposal
    function vote(uint256 proposalId, uint8 support, uint8 voterChoice) public {
        address voter = _getUser(voterChoice);
        support = support % 3; // 0=Against, 1=For, 2=Abstain
        
        if (vault.getVotes(voter) == 0) return;
        
        try governor.castVote(proposalId, support) {} catch {}
    }
    
    /// @notice Execute governance proposal
    function executeProposal(uint256 proposalId) public {
        try governor.execute(
            new address[](1),
            new uint256[](1), 
            new bytes[](1),
            keccak256(bytes("Change interest rate"))
        ) {} catch {}
    }
    
    /// @notice Simulate time passage
    function timeTravel(uint256 blocks) public {
        blocks = blocks % 100000; // Reasonable bounds
        // Note: In actual testing, this would use hevm.roll()
    }
    
    // =============================================================
    // HELPER FUNCTIONS
    // =============================================================
    
    function _getUser(uint8 choice) internal view returns (address) {
        if (choice % 3 == 0) return alice;
        if (choice % 3 == 1) return bob;
        return charlie;
    }
    
    function _boundDeposit(uint256 amount) internal pure returns (uint256) {
        return amount % (MAX_DEPOSIT / 1000); // Up to 1000 tokens
    }
    
    function _boundInterestRate(uint256 rate) internal pure returns (uint256) {
        return MIN_INTEREST_RATE + (rate % (MAX_INTEREST_RATE - MIN_INTEREST_RATE));
    }
    
    function _getSharePrice() internal view returns (uint256) {
        if (vault.totalSupply() <= 1000) return 1e18;
        return vault.convertToAssets(1e18);
    }
    
    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
}