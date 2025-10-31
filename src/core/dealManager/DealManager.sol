// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IDealManager} from "src/interfaces/IAggregatedInterfaces.sol";
import {InterestRate} from "src/constants/InterestRate.sol";

contract DealManager is IDealManager, ERC721 {
    // State variables
    uint256 private _nextTokenId = 2; // Start at 2 to ensure first pair is (2,3)

    // Mappings
    mapping(uint256 => DealWithState) private _dealWithStates; // dealNumber => DealWithState
    address public core; // only core can create deals

    // Events
    event DealCreated(uint256 indexed dealNumber, address indexed buyer, address indexed seller);
    event DealBurned(uint256 indexed dealNumber, address indexed borrowToken, uint256 badDebt);

    // Errors
    error OnlyCore();
    error DealNotFound();
    error TokenNotFound();

    constructor(string memory name, string memory symbol, address _core) ERC721(name, symbol) {
        core = _core;
    }

    // Modifiers
    modifier onlyCore() {
        _onlyCore();
        _;
    }

    function _onlyCore() internal view {
        if (msg.sender != core) {
            revert OnlyCore();
        }
    }

    modifier onlyDealExists(uint256 dealNumber) {
        _onlyDealExists(dealNumber);
        _;
    }

    function _onlyDealExists(uint256 dealNumber) internal view {
        if (!dealExists(dealNumber)) {
            revert DealNotFound();
        }
    }

    modifier onlyTokenExists(uint256 tokenId) {
        _onlyTokenExists(tokenId);
        _;
    }

    function _onlyTokenExists(uint256 tokenId) internal view {
        if (!tokenExists(tokenId)) {
            revert TokenNotFound();
        }
    }

    // Deal creation function
    function createDeal(Deal memory deal, address buyer, address seller)
        external
        onlyCore
        returns (uint256 dealNumber, uint256 buyerTokenId, uint256 sellerTokenId)
    {
        buyerTokenId = _nextTokenId; // Even number (buyer)
        sellerTokenId = _nextTokenId + 1; // Odd number (seller)
        dealNumber = _nextTokenId / 2; // Deal number derived from token ID

        _nextTokenId += 2; // Increment by 2 for next pair

        DealWithState memory dealWithState =
            DealWithState({deal: deal, state: DealState({buyer: buyer, seller: seller, lastUpdated: block.timestamp})});
        _dealWithStates[dealNumber] = dealWithState;

        // Mint NFTs
        _mint(buyer, buyerTokenId);
        _mint(seller, sellerTokenId);

        emit DealCreated(dealNumber, buyer, seller);
    }

    // View functions
    function getDeal(uint256 dealNumber) external view onlyDealExists(dealNumber) returns (Deal memory) {
        return _dealWithStates[dealNumber].deal;
    }

    function getDealWithState(uint256 dealNumber)
        external
        view
        onlyDealExists(dealNumber)
        returns (DealWithState memory)
    {
        return _dealWithStates[dealNumber];
    }

    function getDealWithTokenId(uint256 tokenId) external view onlyTokenExists(tokenId) returns (Deal memory) {
        uint256 dealNumber = tokenId / 2;
        return _dealWithStates[dealNumber].deal;
    }

    function getDealWithTokenIdWithAccounts(uint256 tokenId)
        external
        view
        onlyTokenExists(tokenId)
        returns (DealWithState memory)
    {
        uint256 dealNumber = tokenId / 2;
        return _dealWithStates[dealNumber];
    }

    function isBuyerNft(uint256 tokenId) external view onlyTokenExists(tokenId) returns (bool) {
        return tokenId % 2 == 0; // Even tokenIds are buyer NFTs
    }

    function isSellerNft(uint256 tokenId) external view onlyTokenExists(tokenId) returns (bool) {
        return tokenId % 2 == 1; // Odd tokenIds are seller NFTs
    }

    function getPairedTokenId(uint256 tokenId) external view onlyTokenExists(tokenId) returns (uint256) {
        // If even, return odd pair (tokenId + 1)
        // If odd, return even pair (tokenId - 1)
        return tokenId % 2 == 0 ? tokenId + 1 : tokenId - 1;
    }

    function getDealNumber(uint256 tokenId) external view onlyTokenExists(tokenId) returns (uint256) {
        return tokenId / 2;
    }

    function getSellerTokenId(uint256 dealNumber) public view onlyDealExists(dealNumber) returns (uint256) {
        return dealNumber * 2 + 1;
    }

    function getBuyerTokenId(uint256 dealNumber) public view onlyDealExists(dealNumber) returns (uint256) {
        return dealNumber * 2;
    }

    // Internal functions
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        // This is called before any token transfer
        // You can add custom logic here if needed (e.g., transfer restrictions)
        return super._update(to, tokenId, auth);
    }

    // Additional utility functions
    function totalDeals() public view returns (uint256) {
        return (_nextTokenId - 2) / 2; // Total pairs created
    }

    function totalTokens() external view returns (uint256) {
        return _nextTokenId - 2; // Total tokens minted
    }

    function dealExists(uint256 dealNumber) public view returns (bool) {
        return dealNumber > 0 && dealNumber <= totalDeals();
    }

    function tokenExists(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function updateDealState(uint256 dealNumber) public onlyDealExists(dealNumber) returns (DealWithState memory) {
        DealWithState storage dealState = _dealWithStates[dealNumber];
        uint256 currentTime = block.timestamp;
        uint256 timePassed = currentTime - dealState.state.lastUpdated;

        if (timePassed == 0) return dealState;

        uint256 principal = dealState.deal.borrowAmount;
        uint256 interest = InterestRate.calculateInterest(principal, dealState.deal.interestRate, timePassed);

        dealState.state.lastUpdated = currentTime;

        unchecked {
            dealState.deal.borrowAmount = principal + interest;
        }

        return dealState;
    }

    function updateBorrowAmount(uint256 dealNumber, uint256 newBorrowAmount)
        external
        onlyCore
        onlyDealExists(dealNumber)
        returns (DealWithState memory)
    {
        _dealWithStates[dealNumber].deal.borrowAmount = newBorrowAmount;

        return _dealWithStates[dealNumber];
    }

    function updateCollateralAmount(uint256 dealNumber, uint256 newCollateralAmount)
        external
        onlyCore
        onlyDealExists(dealNumber)
        returns (DealWithState memory)
    {
        _dealWithStates[dealNumber].deal.collateralAmount = newCollateralAmount;

        return _dealWithStates[dealNumber];
    }

    function burnDeal(uint256 dealNumber) external onlyCore onlyDealExists(dealNumber) {
        _burn(getSellerTokenId(dealNumber));
        _burn(getBuyerTokenId(dealNumber));
        address borrowToken = _dealWithStates[dealNumber].deal.borrowToken;
        uint256 badDebt = _dealWithStates[dealNumber].deal.borrowAmount;
        // TODO: create fund to cover the bad debt

        delete _dealWithStates[dealNumber];

        emit DealBurned(dealNumber, borrowToken, badDebt);
    }
}
