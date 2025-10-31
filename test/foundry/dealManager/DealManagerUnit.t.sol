// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {DealManager} from "src/core/dealManager/DealManager.sol";
import {IBaseStructure} from "src/interfaces/IAggregatedInterfaces.sol";
import {InterestRate} from "src/constants/InterestRate.sol";

contract DealManagerTest is Test {
    DealManager internal dealManager;
    IBaseStructure.Deal internal baseDeal;

    function setUp() public {
        dealManager = new DealManager("Test Deal NFT", "TDN", address(this));

        baseDeal = IBaseStructure.Deal({
            collateralToken: address(0x1),
            borrowToken: address(0x2),
            collateralAmount: 100,
            borrowAmount: 200,
            interestRate: InterestRate.INTEREST_RATE_5,
            dealHook: address(0x3)
        });
    }

    function test_CreateDeal_Succeeds_WhenValidParametersProvided() public {
        address buyer = address(0x123);
        address seller = address(0x456);

        (uint256 dealNumber, uint256 buyerTokenId, uint256 sellerTokenId) =
            dealManager.createDeal(baseDeal, buyer, seller);

        assertEq(dealNumber, 1);
        assertEq(buyerTokenId, 2); // Even = buyer
        assertEq(sellerTokenId, 3); // Odd = seller

        assertEq(dealManager.ownerOf(buyerTokenId), buyer);
        assertEq(dealManager.ownerOf(sellerTokenId), seller);
    }

    function test_GetDeal_ReturnsCorrectData_WhenDealExists() public {
        address buyer = address(0x123);
        address seller = address(0x456);

        (uint256 dealNumber,,) = dealManager.createDeal(baseDeal, buyer, seller);

        IBaseStructure.Deal memory retrievedDeal = dealManager.getDeal(dealNumber);

        assertEq(retrievedDeal.collateralToken, baseDeal.collateralToken);
        assertEq(retrievedDeal.borrowToken, baseDeal.borrowToken);
        assertEq(retrievedDeal.collateralAmount, baseDeal.collateralAmount);
        assertEq(retrievedDeal.borrowAmount, baseDeal.borrowAmount);
        assertEq(retrievedDeal.interestRate, baseDeal.interestRate);
        assertEq(retrievedDeal.dealHook, baseDeal.dealHook);
    }

    function test_IsBuyerNft_ReturnsTrue_WhenTokenIdIsEven() public {
        address buyer = address(0x123);
        address seller = address(0x456);

        (, uint256 buyerTokenId, uint256 sellerTokenId) = dealManager.createDeal(baseDeal, buyer, seller);

        assertTrue(dealManager.isBuyerNft(buyerTokenId));
        assertFalse(dealManager.isBuyerNft(sellerTokenId));
    }

    function test_IsSellerNft_ReturnsTrue_WhenTokenIdIsOdd() public {
        address buyer = address(0x123);
        address seller = address(0x456);

        (, uint256 buyerTokenId, uint256 sellerTokenId) = dealManager.createDeal(baseDeal, buyer, seller);

        assertFalse(dealManager.isSellerNft(buyerTokenId));
        assertTrue(dealManager.isSellerNft(sellerTokenId));
    }

    function test_GetPairedTokenId_ReturnsCorrectPair_WhenTokenExists() public {
        address buyer = address(0x123);
        address seller = address(0x456);

        (, uint256 buyerTokenId, uint256 sellerTokenId) = dealManager.createDeal(baseDeal, buyer, seller);

        assertEq(dealManager.getPairedTokenId(buyerTokenId), sellerTokenId);
        assertEq(dealManager.getPairedTokenId(sellerTokenId), buyerTokenId);
    }
}
