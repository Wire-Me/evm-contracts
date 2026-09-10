// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "./helpers/EscrowTestBase.sol";

/// @notice Escrow lifecycle tests, organized to follow the trade narrative rather than grouped
/// by function name. Full diagram in README.md; summarized here:
///
///   Sunny day:
///     createEscrow (seller deposits)
///       -> createOfferWithExpiration (buyer offers)   } still cancellable by the seller
///       -> linkOfferToEscrow (seller commits)          <- commit point, no longer cancellable
///       -> markFundsAsReceived (seller confirms fiat)
///       -> withdrawEscrowAfterCompletion (buyer withdraws stablecoins)
///
///   Dispute (only reachable after linkOfferToEscrow commits the trade):
///     freezeEscrow (admin holds it while reviewing evidence)
///       -> markFundsAsReceivedAdmin (buyer did pay)  -> withdrawEscrowAfterCompletion
///       -> returnEscrow (buyer didn't pay)            -> withdrawEscrowAfterReturn
///
/// createEscrow / createOfferWithExpiration / linkOfferToEscrow / markFundsAsReceived happy
/// paths are covered in SmartWalletEscrow.t.sol. This file picks up everything downstream of
/// those - the pre-commit cancellation window, the sunny-day completion, and the full dispute
/// branch.
contract EscrowLifecycleTest is EscrowTestBase {
    uint internal constant AMOUNT = 100 * 10 ** 6;

    function _createEscrow() internal {
        vm.prank(admin);
        userWallet.transferFundsAndCreateEscrow(USDC, AMOUNT);
    }

    /// @dev Walks the escrow through the full sunny-day path up to (but not including)
    /// withdrawEscrowAfterCompletion - the shared precondition for every dispute-branch test,
    /// since a dispute can only be raised on a trade that already reached the commit point.
    function _createEscrowWithAcceptedOffer(uint feeBasisPoints) internal {
        vm.startPrank(admin);
        userWallet.transferFundsAndCreateEscrow(USDC, AMOUNT);
        brokerWallet.createOffer(USDC, address(userWallet), 0, feeBasisPoints);
        userWallet.linkOfferToEscrow(USDC, 0, address(brokerWallet), 0);
        userWallet.markFundsAsReceived(USDC, 0);
        vm.stopPrank();
    }

    // =====================================================================================
    // STAGE 1 - Escrow created, no offer yet: still cancellable by the seller
    // =====================================================================================
    // createEscrow itself is tested in SmartWalletEscrow.t.sol. What belongs here is what a
    // seller can still do before any offer is linked: extend the escrow's expiration, or
    // cancel it outright and withdraw their funds back.

    function test_ExtendEscrow_SetsExpiration() public {
        _createEscrow();

        uint256 expectedTimestamp = block.timestamp + escrow.defaultEscrowDuration();

        vm.prank(admin);
        userWallet.extendEscrow(USDC, 0);

        assertEq(escrow.getEscrow(USDC, address(userWallet), 0).expirationTimestamp, expectedTimestamp);
    }

    function test_WithdrawEscrowEarly_ReturnsFullAmountToUser() public {
        _createEscrow();

        uint balanceBefore = usdc.balanceOf(address(userWallet));

        vm.prank(admin);
        userWallet.withdrawEscrowEarly(USDC, 0);

        assertEq(usdc.balanceOf(address(userWallet)), balanceBefore + AMOUNT);
        assertTrue(escrow.getEscrow(USDC, address(userWallet), 0).isWithdrawn);
    }

    function test_WithdrawEscrowEarly_ReturnsNativeCurrency() public {
        uint amount = 1 ether;
        vm.deal(address(userWallet), amount);

        vm.prank(admin);
        userWallet.transferFundsAndCreateEscrow(NATIVE, amount);

        assertEq(address(escrow).balance, amount);

        vm.prank(admin);
        userWallet.withdrawEscrowEarly(NATIVE, 0);

        assertEq(address(userWallet).balance, amount);
        assertEq(address(escrow).balance, 0);
    }

    // =====================================================================================
    // STAGE 2 - Offer made (createOfferWithExpiration): still cancellable by the seller
    // =====================================================================================
    // createOfferWithExpiration itself is tested in SmartWalletEscrow.t.sol. Making an offer
    // alone doesn't commit the escrow - selectedBrokerAccount is only set by linkOfferToEscrow
    // (Stage 3) - so an escrow with an outstanding, un-linked offer is still cancellable via
    // the same withdrawEscrowEarly covered in Stage 1 above.

    // =====================================================================================
    // STAGE 3 - linkOfferToEscrow: the seller commits. No longer cancellable after this.
    // =====================================================================================
    // linkOfferToEscrow itself (happy path) is tested in SmartWalletEscrow.t.sol. The revert
    // tests below prove the lock actually takes effect once it's called - extending or
    // withdrawing early both revert as soon as an offer is linked, which is exactly the
    // boundary between Stage 2 and Stage 3.

    function test_ExtendEscrow_RevertsIfOfferAlreadySelected() public {
        vm.startPrank(admin);
        userWallet.transferFundsAndCreateEscrow(USDC, AMOUNT);
        brokerWallet.createOffer(USDC, address(userWallet), 0, 0);
        userWallet.linkOfferToEscrow(USDC, 0, address(brokerWallet), 0);

        vm.expectRevert("Escrow has already selected an offer");
        userWallet.extendEscrow(USDC, 0);
        vm.stopPrank();
    }

    function test_WithdrawEscrowEarly_RevertsIfOfferAlreadySelected() public {
        vm.startPrank(admin);
        userWallet.transferFundsAndCreateEscrow(USDC, AMOUNT);
        brokerWallet.createOffer(USDC, address(userWallet), 0, 0);
        userWallet.linkOfferToEscrow(USDC, 0, address(brokerWallet), 0);

        vm.expectRevert("Escrow has already selected an offer");
        userWallet.withdrawEscrowEarly(USDC, 0);
        vm.stopPrank();
    }

    // =====================================================================================
    // STAGE 4 - Seller marks funds as received (buyer paid the seller off-chain)
    // =====================================================================================
    // markFundsAsReceived (seller-driven) happy path is tested in SmartWalletEscrow.t.sol.
    // markFundsAsReceivedAdmin is the admin-driven equivalent - it's also the first step of
    // dispute resolution A below, when the admin confirms the buyer really did pay.

    function test_MarkFundsAsReceivedAdmin_SetsFlagAndExpiration() public {
        vm.startPrank(admin);
        userWallet.transferFundsAndCreateEscrow(USDC, AMOUNT);
        brokerWallet.createOffer(USDC, address(userWallet), 0, 0);
        userWallet.linkOfferToEscrow(USDC, 0, address(brokerWallet), 0);

        uint256 expectedTimestamp = block.timestamp + escrow.EXPIRATION_DURATION_FOR_NON_BROKERS();
        escrow.markFundsAsReceivedAdmin(USDC, address(userWallet), 0);
        vm.stopPrank();

        EscrowStructs.FXEscrow memory escrowData = escrow.getEscrow(USDC, address(userWallet), 0);
        assertTrue(escrowData.isFundsReceived);
        assertEq(escrowData.expirationTimestamp, expectedTimestamp);
    }

    function test_MarkFundsAsReceivedAdmin_RevertsIfNoOfferSelected() public {
        _createEscrow();

        vm.prank(admin);
        vm.expectRevert("No offer selected for this escrow");
        escrow.markFundsAsReceivedAdmin(USDC, address(userWallet), 0);
    }

    function test_MarkFundsAsReceivedAdmin_RevertsIfAlreadyReceived() public {
        _createEscrowWithAcceptedOffer(0);

        vm.prank(admin);
        vm.expectRevert("Funds are already marked as received");
        escrow.markFundsAsReceivedAdmin(USDC, address(userWallet), 0);
    }

    // =====================================================================================
    // STAGE 5 (sunny day) - Buyer withdraws the stablecoins from escrow after completion
    // =====================================================================================
    // Also how dispute resolution A (below) ends: markFundsAsReceivedAdmin sets the same
    // isFundsReceived flag as the seller-driven path, so the buyer withdraws the same way.

    function test_WithdrawEscrowAfterCompletion_TransfersFundsMinusFee() public {
        uint feeBasisPoints = 100; // 1%
        _createEscrowWithAcceptedOffer(feeBasisPoints);

        EscrowStructs.FXEscrow memory escrowData = escrow.getEscrow(USDC, address(userWallet), 0);
        vm.warp(escrowData.expirationTimestamp);

        uint expectedFee = (AMOUNT * feeBasisPoints) / 10000;
        uint expectedPayout = AMOUNT - expectedFee;
        uint brokerBalanceBefore = usdc.balanceOf(address(brokerWallet));

        vm.prank(admin);
        brokerWallet.withdrawEscrowAfterCompletion(USDC, address(userWallet), 0);

        assertEq(usdc.balanceOf(address(brokerWallet)), brokerBalanceBefore + expectedPayout);
        assertEq(escrow.getPlatformFeeBalance(USDC), expectedFee);
        assertTrue(escrow.getEscrow(USDC, address(userWallet), 0).isWithdrawn);
    }

    function test_WithdrawEscrowAfterCompletion_RevertsBeforeExpiration() public {
        _createEscrowWithAcceptedOffer(0);

        vm.prank(admin);
        vm.expectRevert("Escrow has not yet expired");
        brokerWallet.withdrawEscrowAfterCompletion(USDC, address(userWallet), 0);
    }

    function test_WithdrawEscrowAfterCompletion_RevertsIfNotSelectedBroker() public {
        _createEscrowWithAcceptedOffer(0);

        EscrowStructs.FXEscrow memory escrowData = escrow.getEscrow(USDC, address(userWallet), 0);
        vm.warp(escrowData.expirationTimestamp);

        // Deploy a second, unrelated broker wallet and authorize it
        vm.startPrank(admin);
        SmartWalletMulti otherImpl = new SmartWalletMulti();
        ProxySmartWalletMulti otherProxy = new ProxySmartWalletMulti(address(otherImpl), admin, address(walletConfig));
        SmartWalletMulti otherBroker = SmartWalletMulti(payable(address(otherProxy)));
        escrow.addAuthorizedBroker(address(otherBroker));

        vm.expectRevert("Only the selected broker can withdraw from the escrow");
        otherBroker.withdrawEscrowAfterCompletion(USDC, address(userWallet), 0);
        vm.stopPrank();
    }

    function test_WithdrawEscrowAfterCompletion_RevertsIfFrozen() public {
        _createEscrowWithAcceptedOffer(0);

        EscrowStructs.FXEscrow memory escrowData = escrow.getEscrow(USDC, address(userWallet), 0);
        vm.warp(escrowData.expirationTimestamp);

        vm.startPrank(admin);
        escrow.freezeEscrow(USDC, address(userWallet), 0);

        vm.expectRevert("Escrow is frozen and cannot be withdrawn by the broker");
        brokerWallet.withdrawEscrowAfterCompletion(USDC, address(userWallet), 0);
        vm.stopPrank();
    }

    function test_WithdrawEscrowAfterCompletion_RevertsIfFundsNotReceived() public {
        vm.startPrank(admin);
        userWallet.transferFundsAndCreateEscrow(USDC, AMOUNT);
        brokerWallet.createOffer(USDC, address(userWallet), 0, 0);
        userWallet.linkOfferToEscrow(USDC, 0, address(brokerWallet), 0);
        vm.stopPrank();

        // No markFundsAsReceived call, so expirationTimestamp is still 0 - warp forward anyway
        // to isolate the "funds not received" revert from the "not yet expired" one.
        vm.warp(block.timestamp + 365 days);

        vm.prank(admin);
        vm.expectRevert("Cannot withdraw from escrow before funds are marked as received");
        brokerWallet.withdrawEscrowAfterCompletion(USDC, address(userWallet), 0);
    }

    // =====================================================================================
    // DISPUTE BRANCH - only reachable after Stage 3 (linkOfferToEscrow) commits the trade.
    // Admin freezes the escrow while reviewing evidence, then resolves it one of two ways.
    // =====================================================================================
    // freezeEscrow / defrostEscrow: the admin's hold while a dispute is under review. Every
    // resolution path (markFundsAsReceivedAdmin, linkOfferToEscrow, markFundsAsReceived) also
    // auto-defrosts if the escrow was frozen, so defrostEscrow itself is only needed if the
    // admin decides to lift the hold without resolving the dispute yet.

    function test_FreezeEscrow_SetsFrozenFlag() public {
        _createEscrow();

        vm.prank(admin);
        escrow.freezeEscrow(USDC, address(userWallet), 0);

        assertTrue(escrow.getEscrow(USDC, address(userWallet), 0).isFrozen);
    }

    function test_FreezeEscrow_RevertsIfAlreadyFrozen() public {
        _createEscrow();

        vm.startPrank(admin);
        escrow.freezeEscrow(USDC, address(userWallet), 0);

        vm.expectRevert("Escrow is already frozen");
        escrow.freezeEscrow(USDC, address(userWallet), 0);
        vm.stopPrank();
    }

    /// @dev Querying an index into an empty per-account escrow array panics with an array
    /// out-of-bounds error before the "Escrow is not initialized" require is ever reached -
    /// that require is effectively unreachable for a never-created escrow, only for internal
    /// invariant violations. Documented here as the actual observed behavior.
    function test_FreezeEscrow_PanicsOnNeverCreatedEscrow() public {
        vm.prank(admin);
        vm.expectRevert(stdError.indexOOBError);
        escrow.freezeEscrow(USDC, address(userWallet), 0);
    }

    function test_DefrostEscrow_ClearsFrozenFlag() public {
        _createEscrow();

        vm.startPrank(admin);
        escrow.freezeEscrow(USDC, address(userWallet), 0);
        escrow.defrostEscrow(USDC, address(userWallet), 0);
        vm.stopPrank();

        assertFalse(escrow.getEscrow(USDC, address(userWallet), 0).isFrozen);
    }

    function test_DefrostEscrow_RevertsIfNotFrozen() public {
        _createEscrow();

        vm.prank(admin);
        vm.expectRevert("Escrow is not frozen");
        escrow.defrostEscrow(USDC, address(userWallet), 0);
    }

    // --- Resolution A: buyer really did pay -> markFundsAsReceivedAdmin, tested in Stage 4
    // above -> withdrawEscrowAfterCompletion, tested in Stage 5 above. No separate tests
    // needed here; this is the same code path, just reached after a freeze instead of
    // directly (see test_MarkFundsAsReceivedAdmin_DefrostsIfFrozen below for the freeze
    // interaction specifically).

    function test_MarkFundsAsReceivedAdmin_DefrostsIfFrozen() public {
        vm.startPrank(admin);
        userWallet.transferFundsAndCreateEscrow(USDC, AMOUNT);
        brokerWallet.createOffer(USDC, address(userWallet), 0, 0);
        userWallet.linkOfferToEscrow(USDC, 0, address(brokerWallet), 0);
        escrow.freezeEscrow(USDC, address(userWallet), 0);

        escrow.markFundsAsReceivedAdmin(USDC, address(userWallet), 0);
        vm.stopPrank();

        assertFalse(escrow.getEscrow(USDC, address(userWallet), 0).isFrozen);
    }

    // --- Resolution B: buyer didn't pay -> returnEscrow -> withdrawEscrowAfterReturn ---

    function test_ReturnEscrow_SetsReturnedFlag_AndUnfreezes() public {
        _createEscrow();

        vm.startPrank(admin);
        escrow.freezeEscrow(USDC, address(userWallet), 0);
        escrow.returnEscrow(USDC, address(userWallet), 0);
        vm.stopPrank();

        EscrowStructs.FXEscrow memory escrowData = escrow.getEscrow(USDC, address(userWallet), 0);
        assertTrue(escrowData.isReturned);
        assertFalse(escrowData.isFrozen);
    }

    function test_ReturnEscrow_RevertsIfAlreadyWithdrawn() public {
        _createEscrow();

        vm.prank(admin);
        userWallet.withdrawEscrowEarly(USDC, 0);

        vm.prank(admin);
        vm.expectRevert("Escrow is already withdrawn");
        escrow.returnEscrow(USDC, address(userWallet), 0);
    }

    function test_WithdrawEscrowAfterReturn_ReturnsFullAmountToUser() public {
        _createEscrow();

        vm.prank(admin);
        escrow.returnEscrow(USDC, address(userWallet), 0);

        uint balanceBefore = usdc.balanceOf(address(userWallet));

        vm.prank(admin);
        userWallet.withdrawEscrowAfterReturn(USDC, 0);

        assertEq(usdc.balanceOf(address(userWallet)), balanceBefore + AMOUNT);
        assertTrue(escrow.getEscrow(USDC, address(userWallet), 0).isWithdrawn);
    }

    function test_WithdrawEscrowAfterReturn_RevertsIfNotReturned() public {
        _createEscrow();

        vm.prank(admin);
        vm.expectRevert("Escrow has not been returned");
        userWallet.withdrawEscrowAfterReturn(USDC, 0);
    }

    function test_WithdrawEscrowAfterReturn_RevertsIfFrozen() public {
        _createEscrow();

        vm.startPrank(admin);
        escrow.returnEscrow(USDC, address(userWallet), 0);
        escrow.freezeEscrow(USDC, address(userWallet), 0);

        vm.expectRevert("Escrow is frozen and cannot be withdrawn");
        userWallet.withdrawEscrowAfterReturn(USDC, 0);
        vm.stopPrank();
    }
}
