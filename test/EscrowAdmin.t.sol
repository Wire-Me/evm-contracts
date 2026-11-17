// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "./helpers/EscrowTestBase.sol";

/// @notice Covers escrow admin functions: authorization list management, fee withdrawal,
/// ongoing-offer removal, and swapping the config contract.
contract EscrowAdminTest is EscrowTestBase {
    uint internal constant AMOUNT = 100 * 10 ** 6;

    // -----------------
    // Authorized users
    // -----------------

    function test_IsAuthorizedUser_ReflectsAddAndRemove() public {
        address someUser = address(0xABCD);
        assertFalse(escrow.isAuthorizedUser(someUser));

        vm.prank(admin);
        escrow.addAuthorizedUser(someUser);
        assertTrue(escrow.isAuthorizedUser(someUser));

        vm.prank(admin);
        escrow.removeAuthorizedUser(someUser);
        assertFalse(escrow.isAuthorizedUser(someUser));
    }

    function test_AddAuthorizedUser_RevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("User address cannot be zero");
        escrow.addAuthorizedUser(address(0));
    }

    function test_RemoveAuthorizedUser_RevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("User address cannot be zero");
        escrow.removeAuthorizedUser(address(0));
    }

    function test_RemovedUser_CannotCreateEscrow() public {
        vm.prank(admin);
        escrow.removeAuthorizedUser(address(userWallet));

        vm.prank(admin);
        vm.expectRevert("Sender is not an authorized user wallet");
        userWallet.transferFundsAndCreateEscrow(USDC, AMOUNT);
    }

    // -----------------
    // Authorized brokers
    // -----------------

    function test_IsAuthorizedBroker_ReflectsAddAndRemove() public {
        address someBroker = address(0xBEEF);
        assertFalse(escrow.isAuthorizedBroker(someBroker));

        vm.prank(admin);
        escrow.addAuthorizedBroker(someBroker);
        assertTrue(escrow.isAuthorizedBroker(someBroker));

        vm.prank(admin);
        escrow.removeAuthorizedBroker(someBroker);
        assertFalse(escrow.isAuthorizedBroker(someBroker));
    }

    function test_AddAuthorizedBroker_RevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Broker address cannot be zero");
        escrow.addAuthorizedBroker(address(0));
    }

    function test_RemoveAuthorizedBroker_RevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Broker address cannot be zero");
        escrow.removeAuthorizedBroker(address(0));
    }

    function test_RemovedBroker_CannotCreateOffer() public {
        vm.startPrank(admin);
        userWallet.transferFundsAndCreateEscrow(USDC, AMOUNT);
        escrow.removeAuthorizedBroker(address(brokerWallet));

        vm.expectRevert("Sender is not an authorized broker wallet");
        brokerWallet.createOffer(USDC, address(userWallet), 0, 0);
        vm.stopPrank();
    }

    // -----------------
    // withdrawFees
    // -----------------

    function test_WithdrawFees_TransfersAccumulatedFeesAndResetsBalance() public {
        uint feeBasisPoints = 100; // 1%

        vm.startPrank(admin);
        userWallet.transferFundsAndCreateEscrow(USDC, AMOUNT);
        brokerWallet.createOffer(USDC, address(userWallet), 0, feeBasisPoints);
        userWallet.linkOfferToEscrow(USDC, 0, address(brokerWallet), 0);
        userWallet.markFundsAsReceived(USDC, 0);
        vm.stopPrank();

        EscrowStructs.FXEscrow memory escrowData = escrow.getEscrow(USDC, address(userWallet), 0);
        vm.warp(escrowData.expirationTimestamp);

        vm.prank(admin);
        brokerWallet.withdrawEscrowAfterCompletion(USDC, address(userWallet), 0);

        uint expectedFee = (AMOUNT * feeBasisPoints) / 10000;
        assertEq(escrow.getPlatformFeeBalance(USDC), expectedFee);

        address payable treasury = payable(address(0xFEE5));
        vm.prank(admin);
        escrow.withdrawFees(USDC, treasury);

        assertEq(usdc.balanceOf(treasury), expectedFee);
        assertEq(escrow.getPlatformFeeBalance(USDC), 0);
    }

    function test_WithdrawFees_RevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Cannot withdraw to zero address");
        escrow.withdrawFees(USDC, payable(address(0)));
    }

    // -----------------
    // removeOngoingBrokerOffers
    // -----------------

    function test_RemoveOngoingBrokerOffers_RemovesEntry() public {
        vm.startPrank(admin);
        userWallet.transferFundsAndCreateEscrow(USDC, AMOUNT);
        brokerWallet.createOffer(USDC, address(userWallet), 0, 0);
        vm.stopPrank();

        assertEq(escrow.getOngoingBrokerOffers(address(brokerWallet)).length, 1);

        EscrowStructs.RemoveOngoingBrokerOfferParam[] memory toRemove = new EscrowStructs.RemoveOngoingBrokerOfferParam[](1);
        toRemove[0] = EscrowStructs.RemoveOngoingBrokerOfferParam({
            brokerAccount: address(brokerWallet),
            offerIndex: 0,
            token: USDC
        });

        vm.prank(admin);
        escrow.removeOngoingBrokerOffers(toRemove);

        assertEq(escrow.getOngoingBrokerOffers(address(brokerWallet)).length, 0);
    }

    // -----------------
    // setConfigAddress
    // -----------------

    function test_SetConfigAddress_UpdatesConfig() public {
        TestStablecoin otherToken = newTestUsdc();
        EscrowConfig newConfig = new EscrowConfig(address(otherToken), address(otherToken));

        vm.prank(admin);
        escrow.setConfigAddress(address(newConfig));

        assertEq(escrow.getErc20ContractAddress(USDC), address(otherToken));
    }

    function test_SetConfigAddress_RevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("New config address cannot be zero");
        escrow.setConfigAddress(address(0));
    }
}
