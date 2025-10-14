// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./VaultEchidna.sol";

/// @title Vault Assertions Test - Assertion mode testing
/// @notice Tests using assert() statements that Echidna will try to violate
contract VaultAssertions is VaultEchidna {
    
    // Track historical data for temporal assertions
    uint256[] public historicalRates;
    uint256[] public historicalPrices;
    
    /// @notice Test that interest rate changes are properly recorded
    function test_interest_rate_change_recording(uint256 newRate, uint8 proposer) public {
        newRate = _boundInterestRate(newRate);
        address user = _getUser(proposer);
        
        // Setup: User needs voting power
        if (vault.balanceOf(user) == 0) {
            deposit(1000e18, proposer);
            delegate(proposer, proposer);
        }
        
        uint256 oldRate = vault.interestRatePerSecond();
        
        // Create and execute proposal (simplified for assertion testing)
        if (vault.totalSupply() <= 1000) {
            // Owner can change rate directly during initial phase
            try vault.setInterestRate(newRate) {
                assert(vault.interestRatePerSecond() == newRate);
                historicalRates.push(newRate);
            } catch {
                assert(vault.interestRatePerSecond() == oldRate);
            }
        }
    }
    
    /// @notice Test that deposits always increase user's balance
    function test_deposit_increases_balance(uint256 amount, uint8 userChoice) public {
        address user = _getUser(userChoice);
        amount = _boundDeposit(amount);
        
        if (amount == 0) return;
        if (asset.balanceOf(user) < amount) return;
        
        uint256 oldBalance = vault.balanceOf(user);
        
        asset.approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, user);
        
        uint256 newBalance = vault.balanceOf(user);
        
        // Assert that user received shares
        assert(newBalance >= oldBalance);
        assert(shares > 0);
    }
    
    /// @notice Test that total supply conservation holds
    function test_total_supply_conservation() public view {
        uint256 totalSupply = vault.totalSupply();
        
        // Dead shares should always exist
        assert(totalSupply >= 1000);
        
        // No infinite minting
        assert(totalSupply < type(uint128).max);
    }
    
    /// @notice Test voting power delegation consistency
    function test_delegation_consistency(uint8 delegatorChoice, uint8 delegateeChoice) public {
        address delegator = _getUser(delegatorChoice);
        address delegatee = _getUser(delegateeChoice);
        
        if (vault.balanceOf(delegator) == 0) {
            deposit(1000e18, delegatorChoice);
        }
        
        uint256 delegatorBalance = vault.balanceOf(delegator);
        uint256 oldDelegateeVotes = vault.getVotes(delegatee);
        uint256 oldDelegatorVotes = vault.getVotes(delegator);
        
        vault.delegate(delegatee);
        
        uint256 newDelegateeVotes = vault.getVotes(delegatee);
        uint256 newDelegatorVotes = vault.getVotes(delegator);
        
        // If delegating to someone else, delegator should lose votes
        if (delegatee != delegator) {
            assert(newDelegatorVotes <= oldDelegatorVotes);
        }
        
        // Delegatee should gain votes (unless they're the same person and already delegated)
        if (vault.delegates(delegator) != delegatee || delegatorBalance > 0) {
            assert(newDelegateeVotes >= oldDelegateeVotes);
        }
    }
    
    /// @notice Test that share price cannot be manipulated downward severely
    function test_share_price_manipulation_resistance() public {
        uint256 initialPrice = _getSharePrice();
        
        // Try various manipulation attempts
        deposit(1000e18, 0);
        delegate(0, 0);
        
        uint256 finalPrice = _getSharePrice();
        
        // Price should not drop by more than 10% without legitimate reason
        assert(finalPrice >= (initialPrice * 90) / 100);
        
        historicalPrices.push(finalPrice);
    }
    
    /// @notice Test governance cannot set invalid parameters
    function test_governance_parameter_bounds(uint256 rate) public {
        // Bound the rate to invalid ranges to test rejection
        if (rate < MIN_INTEREST_RATE || rate > MAX_INTEREST_RATE) {
            // Should fail to set invalid rate
            try vault.setInterestRate(rate) {
                assert(false); // Should not succeed with invalid rate
            } catch {
                assert(true); // Expected to fail
            }
        } else {
            // Valid rates should potentially succeed (if called by governance)
            try vault.setInterestRate(rate) {
                assert(vault.interestRatePerSecond() == rate);
            } catch {
                // May fail due to access control, which is fine
                assert(true);
            }
        }
    }
    
    /// @notice Test that interest accumulation is monotonic
    function test_interest_monotonic_growth() public view {
        if (vault.lentAmountStored() > 0) {
            uint256 storedAmount = vault.lentAmountStored();
            uint256 currentAmount = vault.lentAssets();
            
            // Current lent assets should be >= stored amount (due to interest)
            assert(currentAmount >= storedAmount);
        }
    }
    
    /// @notice Test that governance actions require proper authorization
    function test_governance_authorization(uint8 callerChoice) public {
        address caller = _getUser(callerChoice);
        address actualGovernor = vault.governor();
        address actualOwner = vault.owner();
        
        // Non-governance/non-owner should not be able to change critical parameters
        if (caller != actualGovernor && caller != actualOwner) {
            try vault.setInterestRate(InterestRate.INTEREST_RATE_10) {
                assert(false); // Should fail for unauthorized caller
            } catch {
                assert(true); // Expected to fail
            }
        }
    }
    
    /// @notice Test that vault state remains consistent after complex operations
    function test_complex_state_consistency(uint256 amount1, uint256 amount2, uint8 user1, uint8 user2) public {
        amount1 = _boundDeposit(amount1);
        amount2 = _boundDeposit(amount2);
        
        uint256 initialTotalAssets = vault.totalAssets();
        uint256 initialTotalSupply = vault.totalSupply();
        
        // Perform complex operations
        if (amount1 > 0) deposit(amount1, user1);
        if (amount2 > 0) deposit(amount2, user2);
        
        delegate(user1, user2);
        delegate(user2, user1);
        
        uint256 finalTotalAssets = vault.totalAssets();
        uint256 finalTotalSupply = vault.totalSupply();
        
        // Basic consistency checks
        assert(finalTotalSupply >= initialTotalSupply); // Supply only increases with deposits
        assert(finalTotalAssets >= initialTotalAssets); // Assets only increase (ignoring interest for simplicity)
        
        // Voting power consistency
        uint256 totalVotingPower = vault.getVotes(_getUser(user1)) + 
                                  vault.getVotes(_getUser(user2)) + 
                                  vault.getVotes(_getUser((user1 + user2 + 1) % 3));
        
        assert(totalVotingPower <= finalTotalSupply);
    }
}