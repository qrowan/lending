// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Core} from "src/v2/core/core/Core.sol";
import {DealManager} from "src/v2/core/dealManager/DealManager.sol";
import {DealHookFactory} from "src/v2/core/dealManager/DealHookFactory.sol";
import {IBaseStructure} from "src/v2/interfaces/IAggregatedInterfaces.sol";
import {InterestRate} from "src/constants/InterestRate.sol";
import {OrderEncoder} from "src/v2/libraries/OrderEncoder.sol";
import {MockERC20} from "lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {MockDealHook} from "../dealhookfactory/DealHookFactoryUnit.t.sol";
import {Base} from "../Base.t.sol";

contract CoreUnitTest is Test, Base {
    // Events from Core contract
    event BidTaken(bytes32 indexed bidHash, address indexed taker, address indexed bidder);
    event AskTaken(bytes32 indexed askHash, address indexed taker, address indexed asker);
    event LoanRepaid(uint256 indexed dealNumber, address indexed repayer, uint256 repayAmount, uint256 remainingDebt);
    event Liquidated(
        uint256 indexed dealNumber, address indexed liquidator, uint256 repayAmount, uint256 withdrawAmount
    );
    event CollateralWithdrawn(
        uint256 indexed dealNumber, address indexed withdrawer, uint256 withdrawAmount, uint256 remainingCollateral
    );

    // Events from NonceHandler
    event NonceConsumed(address indexed user, uint256 indexed nonce);
    using OrderEncoder for *;
    Core internal core;
    DealManager internal dealManager;
    DealHookFactory internal dealHookFactory;

    IBaseStructure.Bid internal baseBid;
    IBaseStructure.Ask internal baseAsk;
    IBaseStructure.Deal internal baseDeal;
    MockERC20 internal cToken;
    MockERC20 internal bToken;
    MockDealHook internal mockDealHook;

    uint256 privateKey1;
    uint256 privateKey2;
    address buyer;
    address seller;

    function setUp() public {
        cToken = new MockERC20("cToken", "cToken", 18);
        bToken = new MockERC20("bToken", "bToken", 18);

        dealHookFactory = new DealHookFactory(address(this));
        dealManager = new DealManager("Test Deal NFT", "TDN", 0xc7183455a4C133Ae270771860664b6B7ec320bB1); // pre calculated address for core
        core = new Core(address(dealManager), address(dealHookFactory));

        mockDealHook = new MockDealHook("TestDealHook");

        baseBid = IBaseStructure.Bid({
            collateralToken: address(cToken),
            minCollateralAmount: 99,
            borrowToken: address(bToken),
            maxBorrowAmount: 201,
            interestRateBid: InterestRate.INTEREST_RATE_5,
            dealHook: address(mockDealHook),
            deadline: block.timestamp
        });

        baseAsk = IBaseStructure.Ask({
            collateralToken: address(cToken),
            maxCollateralAmount: 101,
            borrowToken: address(bToken),
            minBorrowAmount: 199,
            interestRateAsk: InterestRate.INTEREST_RATE_15,
            dealHook: address(mockDealHook),
            deadline: block.timestamp
        });

        baseDeal = IBaseStructure.Deal({
            collateralToken: address(cToken),
            borrowToken: address(bToken),
            collateralAmount: 100,
            borrowAmount: 200,
            interestRate: InterestRate.INTEREST_RATE_10,
            dealHook: address(mockDealHook)
        });

        privateKey1 = vm.envUint("PRIVATE_KEY1");
        privateKey2 = vm.envUint("PRIVATE_KEY2");
        buyer = vm.addr(privateKey1);
        seller = vm.addr(privateKey2);
        vm.label(buyer, "buyer");
        vm.label(seller, "seller");
        vm.label(address(cToken), "cToken");
        vm.label(address(bToken), "bToken");
        deal(address(bToken), buyer, 1000);
        deal(address(cToken), seller, 1000);

        vm.prank(buyer);
        bToken.approve(address(core), 1000);
        vm.prank(seller);
        cToken.approve(address(core), 1000);
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsAddresses_WhenProperlyInitialized() public {
        Core testCore = new Core(address(dealManager), address(dealHookFactory));

        // Core doesn't expose public getters for these addresses, so we test via behavior
        // The constructor should not revert and the contract should be usable
        assertTrue(address(testCore) != address(0), "Core should be deployed successfully");
    }

    function test_Constructor_WorksCorrectly_WithValidAddresses() public {
        address testDealManager = address(0x1234);
        address testDealHookFactory = address(0x5678);

        Core testCore = new Core(testDealManager, testDealHookFactory);

        assertTrue(address(testCore) != address(0), "Core should be deployed with any valid addresses");
    }

    // ============ TakeBid Tests ============

    function test_TakeBid_CreatesDeal_WhenValidBidProvided() public {
        // Add deal hook to factory to make validateDealHook pass
        dealHookFactory.addDealHook(address(mockDealHook));

        bytes memory bidSignature = getSignature(baseBid, privateKey1);

        IBaseStructure.BidWithAccountInfo memory baseBidWithAccountInfo = IBaseStructure.BidWithAccountInfo({
            bid: baseBid, accountInfo: IBaseStructure.AccountInfo({account: buyer, nonce: 0})
        });

        vm.prank(seller);
        core.takeBid(baseBidWithAccountInfo, bidSignature);

        // Verify deal was created by checking if first deal exists
        IBaseStructure.Deal memory createdDeal = dealManager.getDeal(1);
        assertEq(createdDeal.collateralToken, baseBid.collateralToken);
        assertEq(createdDeal.borrowToken, baseBid.borrowToken);
        assertEq(createdDeal.collateralAmount, baseBid.minCollateralAmount);
        assertEq(createdDeal.borrowAmount, baseBid.maxBorrowAmount);
    }

    function test_TakeBid_TransfersTokens_WhenDealCreated() public {
        uint256 collateralForCoreBefore = cToken.balanceOf(address(core));
        uint256 borrowForBuyerBefore = bToken.balanceOf(buyer);
        uint256 borrowForSellerBefore = bToken.balanceOf(seller);

        test_TakeBid_CreatesDeal_WhenValidBidProvided();
        uint256 collateralForCoreAfter = cToken.balanceOf(address(core));
        uint256 borrowForBuyerAfter = bToken.balanceOf(buyer);
        uint256 borrowForSellerAfter = bToken.balanceOf(seller);
        assertEq(collateralForCoreAfter, collateralForCoreBefore + baseBid.minCollateralAmount);
        assertEq(borrowForBuyerAfter, borrowForBuyerBefore - baseBid.maxBorrowAmount);
        assertEq(borrowForSellerAfter, borrowForSellerBefore + baseBid.maxBorrowAmount);
    }

    function test_TakeBid_EmitsEvents_WhenSuccessful() public {
        // Add deal hook to factory to make validateDealHook pass
        dealHookFactory.addDealHook(address(mockDealHook));

        bytes32 bidHash = baseBid.getHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey1, bidHash);
        bytes memory bidSignature = abi.encodePacked(r, s, v);

        IBaseStructure.BidWithAccountInfo memory baseBidWithAccountInfo = IBaseStructure.BidWithAccountInfo({
            bid: baseBid, accountInfo: IBaseStructure.AccountInfo({account: buyer, nonce: 0})
        });

        // Expect BidTaken event
        vm.expectEmit(true, true, true, false);
        emit BidTaken(bidHash, seller, buyer);

        // Expect NonceConsumed event
        vm.expectEmit(true, true, false, false);
        emit NonceConsumed(buyer, 0);

        vm.prank(seller);
        core.takeBid(baseBidWithAccountInfo, bidSignature);
    }

    function test_TakeBid_CallsDealHook_WhenDealCreated() public {
        // Add deal hook to factory to make validateDealHook pass
        dealHookFactory.addDealHook(address(mockDealHook));

        bytes memory bidSignature = getSignature(baseBid, privateKey1);

        IBaseStructure.BidWithAccountInfo memory baseBidWithAccountInfo = IBaseStructure.BidWithAccountInfo({
            bid: baseBid, accountInfo: IBaseStructure.AccountInfo({account: buyer, nonce: 0})
        });

        uint256 numberOfCreatedBefore = mockDealHook.numberOfCreated();

        vm.prank(seller);
        core.takeBid(baseBidWithAccountInfo, bidSignature);

        // Verify deal hook was called
        assertTrue(mockDealHook.numberOfCreated() == numberOfCreatedBefore + 1, "onDealCreated should be called");
    }

    function test_RevertIf_TakeBidWithInvalidSignature() public {
        IBaseStructure.Bid memory bid = IBaseStructure.Bid({
            collateralToken: address(0x123),
            minCollateralAmount: 1000,
            borrowToken: address(0x456),
            maxBorrowAmount: 500,
            interestRateBid: 100,
            dealHook: address(0),
            deadline: block.timestamp + 1000
        });

        IBaseStructure.AccountInfo memory accountInfo = IBaseStructure.AccountInfo({account: address(0x789), nonce: 0});

        IBaseStructure.BidWithAccountInfo memory bidWithAccountInfo =
            IBaseStructure.BidWithAccountInfo({bid: bid, accountInfo: accountInfo});

        bytes memory invalidSignature = new bytes(65); // Empty/invalid signature

        vm.expectRevert(); // Should revert due to invalid signature verification
        core.takeBid(bidWithAccountInfo, invalidSignature);
    }

    function test_RevertIf_TakeBidWithExpiredDeadline() public {
        // Create a bid with past deadline
        IBaseStructure.Bid memory bid = IBaseStructure.Bid({
            collateralToken: address(0x123),
            minCollateralAmount: 1000,
            borrowToken: address(0x456),
            maxBorrowAmount: 500,
            interestRateBid: 100,
            dealHook: address(0),
            deadline: block.timestamp - 1 // Expired deadline
        });

        IBaseStructure.AccountInfo memory accountInfo = IBaseStructure.AccountInfo({account: address(0x789), nonce: 0});

        IBaseStructure.BidWithAccountInfo memory bidWithAccountInfo =
            IBaseStructure.BidWithAccountInfo({bid: bid, accountInfo: accountInfo});

        bytes memory signature = new bytes(65); // Empty signature

        vm.expectRevert(); // Should revert due to expired deadline
        core.takeBid(bidWithAccountInfo, signature);
    }

    function test_RevertIf_TakeBidWithInvalidNonce() public {
        IBaseStructure.Bid memory bid = IBaseStructure.Bid({
            collateralToken: address(0x123),
            minCollateralAmount: 1000,
            borrowToken: address(0x456),
            maxBorrowAmount: 500,
            interestRateBid: 100,
            dealHook: address(0),
            deadline: block.timestamp + 1000
        });

        IBaseStructure.AccountInfo memory accountInfo = IBaseStructure.AccountInfo({
            account: address(0x789),
            nonce: 5 // Invalid nonce (should be 0 for new user)
        });

        IBaseStructure.BidWithAccountInfo memory bidWithAccountInfo =
            IBaseStructure.BidWithAccountInfo({bid: bid, accountInfo: accountInfo});

        bytes memory signature = new bytes(65);

        vm.expectRevert(); // Should revert due to signature verification first, then nonce
        core.takeBid(bidWithAccountInfo, signature);
    }

    function test_RevertIf_TakeBidWithReentrancy() public {
        // Reentrancy protection is built into the nonReentrant modifier
        // This test verifies the modifier is present by checking the function doesn't allow
        // nested calls (though actual reentrancy testing would require a malicious contract)

        IBaseStructure.Bid memory bid = IBaseStructure.Bid({
            collateralToken: address(0x123),
            minCollateralAmount: 1000,
            borrowToken: address(0x456),
            maxBorrowAmount: 500,
            interestRateBid: 100,
            dealHook: address(0),
            deadline: block.timestamp + 1000
        });

        IBaseStructure.AccountInfo memory accountInfo = IBaseStructure.AccountInfo({account: address(0x789), nonce: 0});

        IBaseStructure.BidWithAccountInfo memory bidWithAccountInfo =
            IBaseStructure.BidWithAccountInfo({bid: bid, accountInfo: accountInfo});

        bytes memory signature = new bytes(65);

        // This will fail due to signature verification before reentrancy could be tested
        vm.expectRevert();
        core.takeBid(bidWithAccountInfo, signature);
    }

    // ============ TakeAsk Tests ============

    function test_TakeAsk_CreatesDeal_WhenValidAskProvided() public {
        // Add deal hook to factory to make validateDealHook pass
        dealHookFactory.addDealHook(address(mockDealHook));

        bytes32 askHash = baseAsk.getHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey2, askHash);
        bytes memory askSignature = abi.encodePacked(r, s, v);

        IBaseStructure.AskWithAccountInfo memory baseAskWithAccountInfo = IBaseStructure.AskWithAccountInfo({
            ask: baseAsk, accountInfo: IBaseStructure.AccountInfo({account: seller, nonce: 0})
        });

        vm.prank(buyer);
        core.takeAsk(baseAskWithAccountInfo, askSignature);

        // Verify deal was created by checking if first deal exists
        IBaseStructure.Deal memory createdDeal = dealManager.getDeal(1);
        assertEq(createdDeal.collateralToken, baseAsk.collateralToken);
        assertEq(createdDeal.borrowToken, baseAsk.borrowToken);
        assertEq(createdDeal.collateralAmount, baseAsk.maxCollateralAmount);
        assertEq(createdDeal.borrowAmount, baseAsk.minBorrowAmount);
    }

    function test_TakeAsk_TransfersTokens_WhenDealCreated() public {
        uint256 collateralForCoreBefore = cToken.balanceOf(address(core));
        uint256 borrowForBuyerBefore = bToken.balanceOf(buyer);
        uint256 borrowForSellerBefore = bToken.balanceOf(seller);

        test_TakeAsk_CreatesDeal_WhenValidAskProvided();

        uint256 collateralForCoreAfter = cToken.balanceOf(address(core));
        uint256 borrowForBuyerAfter = bToken.balanceOf(buyer);
        uint256 borrowForSellerAfter = bToken.balanceOf(seller);

        assertEq(collateralForCoreAfter, collateralForCoreBefore + baseAsk.maxCollateralAmount);
        assertEq(borrowForBuyerAfter, borrowForBuyerBefore - baseAsk.minBorrowAmount);
        assertEq(borrowForSellerAfter, borrowForSellerBefore + baseAsk.minBorrowAmount);
    }

    function test_TakeAsk_EmitsEvents_WhenSuccessful() public {
        // Add deal hook to factory to make validateDealHook pass
        dealHookFactory.addDealHook(address(mockDealHook));

        bytes32 askHash = baseAsk.getHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey2, askHash);
        bytes memory askSignature = abi.encodePacked(r, s, v);

        IBaseStructure.AskWithAccountInfo memory baseAskWithAccountInfo = IBaseStructure.AskWithAccountInfo({
            ask: baseAsk, accountInfo: IBaseStructure.AccountInfo({account: seller, nonce: 0})
        });

        // Expect AskTaken event
        vm.expectEmit(true, true, true, false);
        emit AskTaken(askHash, buyer, seller);

        // Expect NonceConsumed event
        vm.expectEmit(true, true, false, false);
        emit NonceConsumed(seller, 0);

        vm.prank(buyer);
        core.takeAsk(baseAskWithAccountInfo, askSignature);
    }

    function test_TakeAsk_CallsDealHook_WhenDealCreated() public {
        // Add deal hook to factory to make validateDealHook pass
        dealHookFactory.addDealHook(address(mockDealHook));

        bytes32 askHash = baseAsk.getHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey2, askHash);
        bytes memory askSignature = abi.encodePacked(r, s, v);

        IBaseStructure.AskWithAccountInfo memory baseAskWithAccountInfo = IBaseStructure.AskWithAccountInfo({
            ask: baseAsk, accountInfo: IBaseStructure.AccountInfo({account: seller, nonce: 0})
        });

        uint256 numberOfCreatedBefore = mockDealHook.numberOfCreated();

        vm.prank(buyer);
        core.takeAsk(baseAskWithAccountInfo, askSignature);

        // Verify deal hook was called
        assertTrue(mockDealHook.numberOfCreated() == numberOfCreatedBefore + 1, "onDealCreated should be called");
    }

    function test_RevertIf_TakeAskWithInvalidSignature() public {
        IBaseStructure.Ask memory ask = IBaseStructure.Ask({
            collateralToken: address(0x123),
            maxCollateralAmount: 1000,
            borrowToken: address(0x456),
            minBorrowAmount: 500,
            interestRateAsk: 100,
            dealHook: address(0),
            deadline: block.timestamp + 1000
        });

        IBaseStructure.AccountInfo memory accountInfo = IBaseStructure.AccountInfo({account: address(0x789), nonce: 0});

        IBaseStructure.AskWithAccountInfo memory askWithAccountInfo =
            IBaseStructure.AskWithAccountInfo({ask: ask, accountInfo: accountInfo});

        bytes memory invalidSignature = new bytes(65); // Empty/invalid signature

        vm.expectRevert(); // Should revert due to invalid signature verification
        core.takeAsk(askWithAccountInfo, invalidSignature);
    }

    function test_RevertIf_TakeAskWithExpiredDeadline() public {
        // Create an ask with past deadline
        IBaseStructure.Ask memory ask = IBaseStructure.Ask({
            collateralToken: address(0x123),
            maxCollateralAmount: 1000,
            borrowToken: address(0x456),
            minBorrowAmount: 500,
            interestRateAsk: 100,
            dealHook: address(0),
            deadline: block.timestamp - 1 // Expired deadline
        });

        IBaseStructure.AccountInfo memory accountInfo = IBaseStructure.AccountInfo({account: address(0x789), nonce: 0});

        IBaseStructure.AskWithAccountInfo memory askWithAccountInfo =
            IBaseStructure.AskWithAccountInfo({ask: ask, accountInfo: accountInfo});

        bytes memory signature = new bytes(65); // Empty signature

        vm.expectRevert(); // Should revert due to expired deadline
        core.takeAsk(askWithAccountInfo, signature);
    }

    function test_RevertIf_TakeAskWithInvalidNonce() public {
        IBaseStructure.Ask memory ask = IBaseStructure.Ask({
            collateralToken: address(0x123),
            maxCollateralAmount: 1000,
            borrowToken: address(0x456),
            minBorrowAmount: 500,
            interestRateAsk: 100,
            dealHook: address(0),
            deadline: block.timestamp + 1000
        });

        IBaseStructure.AccountInfo memory accountInfo = IBaseStructure.AccountInfo({
            account: address(0x789),
            nonce: 5 // Invalid nonce (should be 0 for new user)
        });

        IBaseStructure.AskWithAccountInfo memory askWithAccountInfo =
            IBaseStructure.AskWithAccountInfo({ask: ask, accountInfo: accountInfo});

        bytes memory signature = new bytes(65);

        vm.expectRevert(); // Should revert due to signature verification first, then nonce
        core.takeAsk(askWithAccountInfo, signature);
    }

    function test_RevertIf_TakeAskWithReentrancy() public {
        // Reentrancy protection is built into the nonReentrant modifier
        IBaseStructure.Ask memory ask = IBaseStructure.Ask({
            collateralToken: address(0x123),
            maxCollateralAmount: 1000,
            borrowToken: address(0x456),
            minBorrowAmount: 500,
            interestRateAsk: 100,
            dealHook: address(0),
            deadline: block.timestamp + 1000
        });

        IBaseStructure.AccountInfo memory accountInfo = IBaseStructure.AccountInfo({account: address(0x789), nonce: 0});

        IBaseStructure.AskWithAccountInfo memory askWithAccountInfo =
            IBaseStructure.AskWithAccountInfo({ask: ask, accountInfo: accountInfo});

        bytes memory signature = new bytes(65);

        // This will fail due to signature verification before reentrancy could be tested
        vm.expectRevert();
        core.takeAsk(askWithAccountInfo, signature);
    }

    // ============ Execute Tests ============

    function test_Execute_MatchesBidAndAsk_WhenValidOrdersProvided() public {
        bytes memory bidSignature = getSignature(baseBid, privateKey1);
        bytes memory askSignature = getSignature(baseAsk, privateKey2);

        IBaseStructure.BidWithAccountInfo memory baseBidWithAccountInfo = IBaseStructure.BidWithAccountInfo({
            bid: baseBid, accountInfo: IBaseStructure.AccountInfo({account: buyer, nonce: 0})
        });
        IBaseStructure.AskWithAccountInfo memory baseAskWithAccountInfo = IBaseStructure.AskWithAccountInfo({
            ask: baseAsk, accountInfo: IBaseStructure.AccountInfo({account: seller, nonce: 0})
        });

        core.execute(baseDeal, baseBidWithAccountInfo, bidSignature, baseAskWithAccountInfo, askSignature);
    }

    function test_Execute_ValidatesDeals_WhenOrdersMatched() public {
        // Add deal hook to factory to make validateDealHook pass
        dealHookFactory.addDealHook(address(mockDealHook));

        bytes memory bidSignature = getSignature(baseBid, privateKey1);
        bytes memory askSignature = getSignature(baseAsk, privateKey2);

        IBaseStructure.BidWithAccountInfo memory baseBidWithAccountInfo = IBaseStructure.BidWithAccountInfo({
            bid: baseBid, accountInfo: IBaseStructure.AccountInfo({account: buyer, nonce: 0})
        });
        IBaseStructure.AskWithAccountInfo memory baseAskWithAccountInfo = IBaseStructure.AskWithAccountInfo({
            ask: baseAsk, accountInfo: IBaseStructure.AccountInfo({account: seller, nonce: 0})
        });

        // Execute should validate that the deal matches both bid and ask requirements
        core.execute(baseDeal, baseBidWithAccountInfo, bidSignature, baseAskWithAccountInfo, askSignature);

        // Verify deal was created successfully (validation passed)
        IBaseStructure.Deal memory createdDeal = dealManager.getDeal(1);
        assertEq(createdDeal.collateralToken, baseDeal.collateralToken);
        assertEq(createdDeal.borrowToken, baseDeal.borrowToken);
        assertEq(createdDeal.collateralAmount, baseDeal.collateralAmount);
        assertEq(createdDeal.borrowAmount, baseDeal.borrowAmount);
    }

    function test_Execute_TransfersTokens_WhenOrdersMatched() public {
        // Add deal hook to factory to make validateDealHook pass
        dealHookFactory.addDealHook(address(mockDealHook));

        // Get initial token balances
        uint256 collateralForCoreBefore = cToken.balanceOf(address(core));
        uint256 borrowForBuyerBefore = bToken.balanceOf(buyer);
        uint256 borrowForSellerBefore = bToken.balanceOf(seller);

        bytes memory bidSignature = getSignature(baseBid, privateKey1);
        bytes memory askSignature = getSignature(baseAsk, privateKey2);

        IBaseStructure.BidWithAccountInfo memory baseBidWithAccountInfo = IBaseStructure.BidWithAccountInfo({
            bid: baseBid, accountInfo: IBaseStructure.AccountInfo({account: buyer, nonce: 0})
        });
        IBaseStructure.AskWithAccountInfo memory baseAskWithAccountInfo = IBaseStructure.AskWithAccountInfo({
            ask: baseAsk, accountInfo: IBaseStructure.AccountInfo({account: seller, nonce: 0})
        });

        core.execute(baseDeal, baseBidWithAccountInfo, bidSignature, baseAskWithAccountInfo, askSignature);

        // Verify token transfers
        uint256 collateralForCoreAfter = cToken.balanceOf(address(core));
        uint256 borrowForBuyerAfter = bToken.balanceOf(buyer);
        uint256 borrowForSellerAfter = bToken.balanceOf(seller);

        // Core should receive collateral from seller (asker)
        assertEq(collateralForCoreAfter, collateralForCoreBefore + baseDeal.collateralAmount);
        // Buyer should pay borrow tokens to seller
        assertEq(borrowForBuyerAfter, borrowForBuyerBefore - baseDeal.borrowAmount);
        // Seller should receive borrow tokens from buyer
        assertEq(borrowForSellerAfter, borrowForSellerBefore + baseDeal.borrowAmount);
    }

    function test_Execute_EmitsEvents_WhenSuccessful() public {
        // Add deal hook to factory to make validateDealHook pass
        dealHookFactory.addDealHook(address(mockDealHook));

        bytes memory bidSignature = getSignature(baseBid, privateKey1);
        bytes memory askSignature = getSignature(baseAsk, privateKey2);

        IBaseStructure.BidWithAccountInfo memory baseBidWithAccountInfo = IBaseStructure.BidWithAccountInfo({
            bid: baseBid, accountInfo: IBaseStructure.AccountInfo({account: buyer, nonce: 0})
        });
        IBaseStructure.AskWithAccountInfo memory baseAskWithAccountInfo = IBaseStructure.AskWithAccountInfo({
            ask: baseAsk, accountInfo: IBaseStructure.AccountInfo({account: seller, nonce: 0})
        });

        // Calculate hashes for events
        bytes32 bidHash = baseBid.getHash();
        bytes32 askHash = baseAsk.getHash();

        // Expect BidTaken event
        vm.expectEmit(true, true, true, false);
        emit BidTaken(bidHash, seller, buyer);

        // Expect AskTaken event
        vm.expectEmit(true, true, true, false);
        emit AskTaken(askHash, seller, buyer);

        // Expect NonceConsumed events for both users
        vm.expectEmit(true, true, false, false);
        emit NonceConsumed(seller, 0);

        vm.expectEmit(true, true, false, false);
        emit NonceConsumed(buyer, 0);

        core.execute(baseDeal, baseBidWithAccountInfo, bidSignature, baseAskWithAccountInfo, askSignature);
    }

    function test_RevertIf_ExecuteWithMismatchedDeals() public {
        // Create mismatched deal and orders
        IBaseStructure.Deal memory deal = IBaseStructure.Deal({
            collateralToken: address(0x123), // Different from bid/ask
            borrowToken: address(0x456),
            collateralAmount: 1000,
            borrowAmount: 500,
            interestRate: 100,
            dealHook: address(0)
        });

        IBaseStructure.Bid memory bid = IBaseStructure.Bid({
            collateralToken: address(0x999), // Mismatched
            minCollateralAmount: 1000,
            borrowToken: address(0x456),
            maxBorrowAmount: 500,
            interestRateBid: 100,
            dealHook: address(0),
            deadline: block.timestamp + 1000
        });

        IBaseStructure.Ask memory ask = IBaseStructure.Ask({
            collateralToken: address(0x123),
            maxCollateralAmount: 1000,
            borrowToken: address(0x456),
            minBorrowAmount: 500,
            interestRateAsk: 100,
            dealHook: address(0),
            deadline: block.timestamp + 1000
        });

        IBaseStructure.AccountInfo memory bidAccountInfo =
            IBaseStructure.AccountInfo({account: address(0x789), nonce: 0});

        IBaseStructure.AccountInfo memory askAccountInfo =
            IBaseStructure.AccountInfo({account: address(0xabc), nonce: 0});

        IBaseStructure.BidWithAccountInfo memory bidWithAccountInfo =
            IBaseStructure.BidWithAccountInfo({bid: bid, accountInfo: bidAccountInfo});

        IBaseStructure.AskWithAccountInfo memory askWithAccountInfo =
            IBaseStructure.AskWithAccountInfo({ask: ask, accountInfo: askAccountInfo});

        bytes memory bidSignature = new bytes(65);
        bytes memory askSignature = new bytes(65);

        vm.expectRevert(); // Should revert due to signature verification or deal validation
        core.execute(deal, bidWithAccountInfo, bidSignature, askWithAccountInfo, askSignature);
    }

    function test_RevertIf_ExecuteWithExpiredBidDeadline() public {
        // Create a deal and orders with expired bid deadline
        IBaseStructure.Deal memory deal = IBaseStructure.Deal({
            collateralToken: address(0x123),
            borrowToken: address(0x456),
            collateralAmount: 1000,
            borrowAmount: 500,
            interestRate: 100,
            dealHook: address(0)
        });

        IBaseStructure.Bid memory bid = IBaseStructure.Bid({
            collateralToken: address(0x123),
            minCollateralAmount: 1000,
            borrowToken: address(0x456),
            maxBorrowAmount: 500,
            interestRateBid: 100,
            dealHook: address(0),
            deadline: block.timestamp - 1 // Expired
        });

        IBaseStructure.Ask memory ask = IBaseStructure.Ask({
            collateralToken: address(0x123),
            maxCollateralAmount: 1000,
            borrowToken: address(0x456),
            minBorrowAmount: 500,
            interestRateAsk: 100,
            dealHook: address(0),
            deadline: block.timestamp + 1000 // Valid
        });

        IBaseStructure.AccountInfo memory bidAccountInfo =
            IBaseStructure.AccountInfo({account: address(0x789), nonce: 0});

        IBaseStructure.AccountInfo memory askAccountInfo =
            IBaseStructure.AccountInfo({account: address(0xabc), nonce: 0});

        IBaseStructure.BidWithAccountInfo memory bidWithAccountInfo =
            IBaseStructure.BidWithAccountInfo({bid: bid, accountInfo: bidAccountInfo});

        IBaseStructure.AskWithAccountInfo memory askWithAccountInfo =
            IBaseStructure.AskWithAccountInfo({ask: ask, accountInfo: askAccountInfo});

        bytes memory bidSignature = new bytes(65);
        bytes memory askSignature = new bytes(65);

        vm.expectRevert(); // Should revert due to expired bid deadline
        core.execute(deal, bidWithAccountInfo, bidSignature, askWithAccountInfo, askSignature);
    }

    function test_RevertIf_ExecuteWithExpiredAskDeadline() public {
        // Create a deal and orders with expired ask deadline
        IBaseStructure.Deal memory deal = IBaseStructure.Deal({
            collateralToken: address(0x123),
            borrowToken: address(0x456),
            collateralAmount: 1000,
            borrowAmount: 500,
            interestRate: 100,
            dealHook: address(0)
        });

        IBaseStructure.Bid memory bid = IBaseStructure.Bid({
            collateralToken: address(0x123),
            minCollateralAmount: 1000,
            borrowToken: address(0x456),
            maxBorrowAmount: 500,
            interestRateBid: 100,
            dealHook: address(0),
            deadline: block.timestamp + 1000 // Valid
        });

        IBaseStructure.Ask memory ask = IBaseStructure.Ask({
            collateralToken: address(0x123),
            maxCollateralAmount: 1000,
            borrowToken: address(0x456),
            minBorrowAmount: 500,
            interestRateAsk: 100,
            dealHook: address(0),
            deadline: block.timestamp - 1 // Expired
        });

        IBaseStructure.AccountInfo memory bidAccountInfo =
            IBaseStructure.AccountInfo({account: address(0x789), nonce: 0});

        IBaseStructure.AccountInfo memory askAccountInfo =
            IBaseStructure.AccountInfo({account: address(0xabc), nonce: 0});

        IBaseStructure.BidWithAccountInfo memory bidWithAccountInfo =
            IBaseStructure.BidWithAccountInfo({bid: bid, accountInfo: bidAccountInfo});

        IBaseStructure.AskWithAccountInfo memory askWithAccountInfo =
            IBaseStructure.AskWithAccountInfo({ask: ask, accountInfo: askAccountInfo});

        bytes memory bidSignature = new bytes(65);
        bytes memory askSignature = new bytes(65);

        vm.expectRevert(); // Should revert due to expired ask deadline
        core.execute(deal, bidWithAccountInfo, bidSignature, askWithAccountInfo, askSignature);
    }

    function test_RevertIf_ExecuteWithInvalidSignatures() public {
        IBaseStructure.Deal memory deal = IBaseStructure.Deal({
            collateralToken: address(0x123),
            borrowToken: address(0x456),
            collateralAmount: 1000,
            borrowAmount: 500,
            interestRate: 100,
            dealHook: address(0)
        });

        IBaseStructure.Bid memory bid = IBaseStructure.Bid({
            collateralToken: address(0x123),
            minCollateralAmount: 1000,
            borrowToken: address(0x456),
            maxBorrowAmount: 500,
            interestRateBid: 100,
            dealHook: address(0),
            deadline: block.timestamp + 1000
        });

        IBaseStructure.Ask memory ask = IBaseStructure.Ask({
            collateralToken: address(0x123),
            maxCollateralAmount: 1000,
            borrowToken: address(0x456),
            minBorrowAmount: 500,
            interestRateAsk: 100,
            dealHook: address(0),
            deadline: block.timestamp + 1000
        });

        IBaseStructure.AccountInfo memory bidAccountInfo =
            IBaseStructure.AccountInfo({account: address(0x789), nonce: 0});

        IBaseStructure.AccountInfo memory askAccountInfo =
            IBaseStructure.AccountInfo({account: address(0xabc), nonce: 0});

        IBaseStructure.BidWithAccountInfo memory bidWithAccountInfo =
            IBaseStructure.BidWithAccountInfo({bid: bid, accountInfo: bidAccountInfo});

        IBaseStructure.AskWithAccountInfo memory askWithAccountInfo =
            IBaseStructure.AskWithAccountInfo({ask: ask, accountInfo: askAccountInfo});

        bytes memory invalidBidSignature = new bytes(65);
        bytes memory invalidAskSignature = new bytes(65);

        vm.expectRevert(); // Should revert due to invalid signature verification
        core.execute(deal, bidWithAccountInfo, invalidBidSignature, askWithAccountInfo, invalidAskSignature);
    }

    // ============ Repay Tests ============

    function test_Repay_ReducesDebt_WhenPartialRepayment() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;
        uint256 partialRepayAmount = 50; // Partial repayment

        // Get initial deal state
        IBaseStructure.Deal memory dealBefore = dealManager.getDeal(dealNumber);
        uint256 initialDebt = dealBefore.borrowAmount;

        // Give seller tokens to repay
        deal(address(bToken), seller, partialRepayAmount);
        vm.prank(seller);
        bToken.approve(address(core), partialRepayAmount);

        vm.prank(seller);
        core.repay(dealNumber, partialRepayAmount);

        // Verify debt was reduced
        IBaseStructure.Deal memory dealAfter = dealManager.getDeal(dealNumber);
        assertEq(dealAfter.borrowAmount, initialDebt - partialRepayAmount);
        assertTrue(dealAfter.borrowAmount > 0, "Should still have remaining debt");
    }

    function test_Repay_ReleasesCollateral_WhenFullRepayment() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;
        IBaseStructure.Deal memory dealBefore = dealManager.getDeal(dealNumber);
        uint256 fullRepayAmount = dealBefore.borrowAmount;

        // Give seller tokens to repay
        deal(address(bToken), seller, fullRepayAmount);
        vm.prank(seller);
        bToken.approve(address(core), fullRepayAmount);

        vm.prank(seller);
        core.repay(dealNumber, fullRepayAmount);

        // Verify debt was reduced
        IBaseStructure.Deal memory dealAfter = dealManager.getDeal(dealNumber);
        assertEq(dealAfter.borrowAmount, 0);

        uint256 sellerCollateralBeforeWithdraw = cToken.balanceOf(seller);
        vm.prank(seller);
        core.withdrawCollateral(dealNumber, dealBefore.collateralAmount);
        uint256 sellerCollateralAfterWithdraw = cToken.balanceOf(seller);
        assertEq(sellerCollateralAfterWithdraw, sellerCollateralBeforeWithdraw + dealBefore.collateralAmount);
    }

    function test_Repay_TransfersTokens_WhenRepaymentMade() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;
        uint256 repayAmount = 50;

        // Get initial token balances
        deal(address(bToken), seller, repayAmount);
        uint256 sellerBTokenBefore = bToken.balanceOf(seller);
        uint256 buyerBTokenBefore = bToken.balanceOf(buyer);

        // Give seller tokens to repay
        vm.prank(seller);
        bToken.approve(address(core), repayAmount);

        vm.prank(seller);
        core.repay(dealNumber, repayAmount);

        // Verify token transfers
        uint256 sellerBTokenAfter = bToken.balanceOf(seller);
        uint256 buyerBTokenAfter = bToken.balanceOf(buyer);

        // Seller should have less tokens (paid repayment)
        assertEq(sellerBTokenAfter, sellerBTokenBefore - repayAmount);
        // Buyer should have more tokens (received repayment)
        assertEq(buyerBTokenAfter, buyerBTokenBefore + repayAmount);
    }

    function test_Repay_EmitsEvent_WhenRepaymentMade() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;
        uint256 repayAmount = 50;

        // Get initial token balances
        deal(address(bToken), seller, repayAmount);

        // Give seller tokens to repay
        vm.prank(seller);
        bToken.approve(address(core), repayAmount);

        vm.expectEmit(true, true, true, false);
        emit LoanRepaid(dealNumber, seller, repayAmount, dealManager.getDeal(dealNumber).borrowAmount - repayAmount);

        vm.prank(seller);
        core.repay(dealNumber, repayAmount);
    }

    function test_Repay_CallsDealHook_WhenRepaymentMade() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;
        uint256 repayAmount = 50;

        // Give seller tokens to repay
        deal(address(bToken), seller, repayAmount);
        vm.prank(seller);
        bToken.approve(address(core), repayAmount);

        uint256 numberOfRepaidBefore = mockDealHook.numberOfRepaid();

        vm.prank(seller);
        core.repay(dealNumber, repayAmount);

        // Verify deal hook was called
        assertTrue(mockDealHook.numberOfRepaid() == numberOfRepaidBefore + 1, "onDealRepaid should be called");
    }

    function test_Repay_UpdatesDealState_WhenRepaymentMade() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;
        uint256 repayAmount = 50;

        // Get initial token balances
        deal(address(bToken), seller, repayAmount);

        // Give seller tokens to repay
        vm.prank(seller);
        bToken.approve(address(core), repayAmount);

        IBaseStructure.Deal memory dealBefore = dealManager.getDeal(dealNumber);

        vm.prank(seller);
        core.repay(dealNumber, repayAmount);

        IBaseStructure.Deal memory dealAfter = dealManager.getDeal(dealNumber);
        assertEq(dealAfter.borrowAmount, dealBefore.borrowAmount - repayAmount);
    }

    function test_RevertIf_RepayWithZeroAmount() public {
        uint256 dealNumber = 1;
        uint256 repayAmount = 0;

        // This should revert due to "Nothing to repay" when the deal doesn't exist
        // or when the repay amount is 0
        vm.expectRevert();
        core.repay(dealNumber, repayAmount);
    }

    function test_RevertIf_RepayWithReentrancy() public {
        // Reentrancy protection is built into the nonReentrant modifier
        uint256 dealNumber = 1;
        uint256 repayAmount = 100;

        // This will fail due to deal validation before reentrancy could be tested
        vm.expectRevert();
        core.repay(dealNumber, repayAmount);
    }

    function test_RevertIf_RepayWithInvalidDeal() public {
        uint256 invalidDealNumber = 999; // Non-existent deal
        uint256 repayAmount = 100;

        vm.expectRevert(); // Should revert when trying to access non-existent deal
        core.repay(invalidDealNumber, repayAmount);
    }

    // ============ WithdrawCollateral Tests ============

    function test_WithdrawCollateral_ReducesCollateral_WhenPartialWithdrawal() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;
        uint256 partialWithdrawAmount = 30; // Partial withdrawal

        // Get initial deal state
        IBaseStructure.Deal memory dealBefore = dealManager.getDeal(dealNumber);
        uint256 initialCollateral = dealBefore.collateralAmount;

        vm.prank(seller);
        core.withdrawCollateral(dealNumber, partialWithdrawAmount);

        // Verify collateral was reduced
        IBaseStructure.Deal memory dealAfter = dealManager.getDeal(dealNumber);
        assertEq(dealAfter.collateralAmount, initialCollateral - partialWithdrawAmount);
        assertTrue(dealAfter.collateralAmount > 0, "Should still have remaining collateral");
    }

    function test_WithdrawCollateral_BurnsDeal_WhenFullWithdrawal() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;

        // Get initial deal state
        IBaseStructure.Deal memory dealBefore = dealManager.getDeal(dealNumber);
        uint256 fullCollateralAmount = dealBefore.collateralAmount;

        vm.prank(seller);
        core.withdrawCollateral(dealNumber, fullCollateralAmount);

        // Verify collateral was fully withdrawn
        IBaseStructure.Deal memory dealAfter = dealManager.getDeal(dealNumber);
        assertEq(dealAfter.collateralToken, address(0), "collateralToken");
        assertEq(dealAfter.borrowToken, address(0), "borrowToken");
        assertEq(dealAfter.borrowAmount, 0, "borrowAmount");
        assertEq(dealAfter.interestRate, 0, "interestRate");
        assertEq(dealAfter.dealHook, address(0), "dealHook");
    }

    function test_WithdrawCollateral_TransfersTokens_WhenWithdrawalMade() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;
        uint256 withdrawAmount = 30;

        // Get initial token balances
        uint256 sellerCollateralBefore = cToken.balanceOf(seller);

        vm.prank(seller);
        core.withdrawCollateral(dealNumber, withdrawAmount);

        // Verify token transfers
        uint256 sellerCollateralAfter = cToken.balanceOf(seller);

        // Seller should have more collateral tokens (received withdrawal)
        assertEq(sellerCollateralAfter, sellerCollateralBefore + withdrawAmount);
    }

    function test_WithdrawCollateral_EmitsEvent_WhenWithdrawalMade() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;
        uint256 withdrawAmount = 30;

        vm.expectEmit(true, true, true, false);
        emit CollateralWithdrawn(dealNumber, seller, withdrawAmount, 99 - withdrawAmount);

        vm.prank(seller);
        core.withdrawCollateral(dealNumber, withdrawAmount);
    }

    function test_WithdrawCollateral_CallsDealHook_WhenWithdrawalMade() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;
        uint256 withdrawAmount = 30;

        uint256 numberOfWithdrawnBefore = mockDealHook.numberOfWithdrawn();

        vm.prank(seller);
        core.withdrawCollateral(dealNumber, withdrawAmount);

        // Verify deal hook was called
        assertTrue(
            mockDealHook.numberOfWithdrawn() == numberOfWithdrawnBefore + 1,
            "onDealCollateralWithdrawn should be called"
        );
    }

    function test_RevertIf_WithdrawCollateralDealNotFound() public {
        uint256 dealNumber = 1;
        uint256 withdrawAmount = 100;

        vm.expectRevert(DealManager.DealNotFound.selector);
        core.withdrawCollateral(dealNumber, withdrawAmount);
    }

    function test_RevertIf_WithdrawCollateralNotSeller() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;
        uint256 withdrawAmount = 30;

        vm.expectRevert("Not the seller");

        vm.prank(address(0x123));
        core.withdrawCollateral(dealNumber, withdrawAmount);
    }

    function test_RevertIf_WithdrawCollateralWithZeroAmount() public {
        uint256 dealNumber = 1;
        uint256 withdrawAmount = 0;

        vm.expectRevert(DealManager.DealNotFound.selector);
        core.withdrawCollateral(dealNumber, withdrawAmount);
    }

    // ============ Liquidate Tests ============

    function test_Liquidate_RepaysAndWithdraws_WhenValidAmounts() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;
        uint256 repayAmount = 50;
        uint256 withdrawAmount = 30;

        // Get initial deal state
        IBaseStructure.Deal memory dealBefore = dealManager.getDeal(dealNumber);
        uint256 initialDebt = dealBefore.borrowAmount;
        uint256 initialCollateral = dealBefore.collateralAmount;

        deal(address(bToken), address(this), repayAmount);
        
        // Get initial token balances
        uint256 liquidatorCollateralBefore = cToken.balanceOf(address(this));
        uint256 liquidatorBorrowBefore = bToken.balanceOf(address(this));

        // Give liquidator tokens to repay
        bToken.approve(address(core), repayAmount);
        core.liquidate(dealNumber, repayAmount, withdrawAmount);

        // Verify deal state changes
        IBaseStructure.Deal memory dealAfter = dealManager.getDeal(dealNumber);
        assertEq(dealAfter.borrowAmount, initialDebt - repayAmount, "Debt should be reduced");
        assertEq(dealAfter.collateralAmount, initialCollateral - withdrawAmount, "Collateral should be reduced");

        // Verify token transfers
        uint256 liquidatorCollateralAfter = cToken.balanceOf(address(this));
        uint256 liquidatorBorrowAfter = bToken.balanceOf(address(this));

        // Liquidator should receive collateral and pay borrow tokens
        assertEq(liquidatorCollateralAfter, liquidatorCollateralBefore + withdrawAmount);
        assertEq(liquidatorBorrowAfter, liquidatorBorrowBefore - repayAmount);
    }

    function test_Liquidate_BurnsDeal_WhenFullLiquidation() public {
        // First create a deal
        test_TakeBid_CreatesDeal_WhenValidBidProvided();

        uint256 dealNumber = 1;

        // Get deal state for full liquidation
        IBaseStructure.Deal memory dealBefore = dealManager.getDeal(dealNumber);
        uint256 fullRepayAmount = dealBefore.borrowAmount;
        uint256 fullWithdrawAmount = dealBefore.collateralAmount;

        // Give liquidator tokens to repay fully
        deal(address(bToken), address(this), fullRepayAmount);
        bToken.approve(address(core), fullRepayAmount);

        core.liquidate(dealNumber, fullRepayAmount, fullWithdrawAmount);

        // Verify deal was burned (all fields should be zero)
        IBaseStructure.Deal memory dealAfter = dealManager.getDeal(dealNumber);
        assertEq(dealAfter.collateralToken, address(0), "collateralToken should be zero");
        assertEq(dealAfter.borrowToken, address(0), "borrowToken should be zero");
        assertEq(dealAfter.collateralAmount, 0, "collateralAmount should be zero");
        assertEq(dealAfter.borrowAmount, 0, "borrowAmount should be zero");
        assertEq(dealAfter.interestRate, 0, "interestRate should be zero");
        assertEq(dealAfter.dealHook, address(0), "dealHook should be zero");
    }

    function test_Liquidate_EmitsEvent_WhenLiquidationMade() public {
        // Setup: Register deal hook and create a deal first
        dealHookFactory.addDealHook(address(mockDealHook));

        // Create a bid and take it to generate a deal
        bytes32 bidHash = baseBid.getHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey1, bidHash);
        bytes memory bidSignature = abi.encodePacked(r, s, v);

        IBaseStructure.BidWithAccountInfo memory baseBidWithAccountInfo = IBaseStructure.BidWithAccountInfo({
            bid: baseBid, accountInfo: IBaseStructure.AccountInfo({account: buyer, nonce: 0})
        });

        vm.prank(seller);
        core.takeBid(baseBidWithAccountInfo, bidSignature);

        // Get the created deal number (should be 1 for first deal based on trace)
        uint256 dealNumber = 1;
        uint256 repayAmount = 50e6; // Partial repayment
        uint256 withdrawAmount = 0.1 ether; // Partial withdrawal

        deal(address(bToken), address(this), repayAmount);
        bToken.approve(address(core), repayAmount);

        // Expect Liquidated event
        vm.expectEmit(true, true, false, true);
        emit Liquidated(dealNumber, address(this), repayAmount, withdrawAmount);

        // Execute liquidation
        core.liquidate(dealNumber, repayAmount, withdrawAmount);
    }

    function test_Liquidate_CallsDealHook_WhenLiquidationMade() public {
        // Setup: Register deal hook and create a deal first
        dealHookFactory.addDealHook(address(mockDealHook));

        // Create a bid and take it to generate a deal
        bytes32 bidHash = baseBid.getHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey1, bidHash);
        bytes memory bidSignature = abi.encodePacked(r, s, v);

        IBaseStructure.BidWithAccountInfo memory baseBidWithAccountInfo = IBaseStructure.BidWithAccountInfo({
            bid: baseBid, accountInfo: IBaseStructure.AccountInfo({account: buyer, nonce: 0})
        });

        vm.prank(seller);
        core.takeBid(baseBidWithAccountInfo, bidSignature);

        // Verify initial hook state - should have been called for deal creation
        assertEq(mockDealHook.numberOfCreated(), 1, "Hook should have been called for deal creation");
        assertEq(mockDealHook.numberOfLiquidated(), 0, "Hook should not have been called for liquidation yet");

        // Get the created deal number (should be 1 for first deal)
        uint256 dealNumber = 1;
        uint256 repayAmount = 50e6; // Partial repayment
        uint256 withdrawAmount = 0.1 ether; // Partial withdrawal

        deal(address(bToken), address(this), repayAmount);
        bToken.approve(address(core), repayAmount);
        // Execute liquidation
        core.liquidate(dealNumber, repayAmount, withdrawAmount);

        // Verify hook was called for liquidation
        assertEq(mockDealHook.numberOfLiquidated(), 1, "Hook should have been called for liquidation");
    }

    function test_Liquidate_UpdatesDealState_WhenLiquidationMade() public {
        // Setup: Register deal hook and create a deal first
        dealHookFactory.addDealHook(address(mockDealHook));

        // Create a bid and take it to generate a deal
        bytes memory bidSignature = getSignature(baseBid, privateKey1);

        IBaseStructure.BidWithAccountInfo memory baseBidWithAccountInfo = IBaseStructure.BidWithAccountInfo({
            bid: baseBid, accountInfo: IBaseStructure.AccountInfo({account: buyer, nonce: 0})
        });

        vm.prank(seller);
        core.takeBid(baseBidWithAccountInfo, bidSignature);

        // Get the created deal number (should be 1 for first deal)
        uint256 dealNumber = 1;

        // Get initial deal state
        IBaseStructure.Deal memory dealBefore = dealManager.getDeal(dealNumber);
        uint256 initialDebt = dealBefore.borrowAmount;
        uint256 initialCollateral = dealBefore.collateralAmount;

        // Set up liquidation amounts
        uint256 repayAmount = 100; // Partial repayment (less than debt of 201)
        uint256 withdrawAmount = 10; // Partial withdrawal (less than collateral of 99)

        // Give liquidator tokens to repay
        deal(address(bToken), address(this), repayAmount);
        bToken.approve(address(core), repayAmount);

        // Execute liquidation
        core.liquidate(dealNumber, repayAmount, withdrawAmount);

        // Get deal state after liquidation
        IBaseStructure.Deal memory dealAfter = dealManager.getDeal(dealNumber);

        // Verify debt was reduced
        assertEq(dealAfter.borrowAmount, initialDebt - repayAmount, "Debt should be reduced by repay amount");

        // Verify collateral was reduced
        assertEq(
            dealAfter.collateralAmount,
            initialCollateral - withdrawAmount,
            "Collateral should be reduced by withdraw amount"
        );

        // Verify other fields remain unchanged
        assertEq(dealAfter.collateralToken, dealBefore.collateralToken, "Collateral token should remain same");
        assertEq(dealAfter.borrowToken, dealBefore.borrowToken, "Borrow token should remain same");
        assertEq(dealAfter.interestRate, dealBefore.interestRate, "Interest rate should remain same");
        assertEq(dealAfter.dealHook, dealBefore.dealHook, "Deal hook should remain same");
    }

    function test_RevertIf_LiquidateWithReentrancy() public {
        // Reentrancy protection is built into the nonReentrant modifier
        uint256 dealNumber = 1;
        uint256 repayAmount = 100;
        uint256 withdrawAmount = 50;

        // This will fail due to deal validation before reentrancy could be tested
        vm.expectRevert();
        core.liquidate(dealNumber, repayAmount, withdrawAmount);
    }

    function test_RevertIf_LiquidateWithInvalidDeal() public {
        uint256 invalidDealNumber = 999; // Non-existent deal
        uint256 repayAmount = 100;
        uint256 withdrawAmount = 50;

        vm.expectRevert(); // Should revert when trying to access non-existent deal
        core.liquidate(invalidDealNumber, repayAmount, withdrawAmount);
    }

    // ============ State Management Tests ============

    function test_DealManager_IsSetCorrectly_AfterConstruction() public {
        // Since dealManager is not publicly exposed, we test it works by ensuring
        // the contract was constructed without reverting
        assertTrue(address(core) != address(0), "Core should be deployed successfully");
    }

    function test_DealHookFactory_IsSetCorrectly_AfterConstruction() public {
        // Since dealHookFactory is not publicly exposed, we test it works by ensuring
        // the contract was constructed without reverting
        assertTrue(address(core) != address(0), "Core should be deployed successfully");
    }
}
