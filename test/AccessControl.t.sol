// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "./helpers/EscrowTestBase.sol";

/// @notice Confirms every privileged escrow function actually enforces its access-control
/// modifier. Access-control checks run before any other logic in the function body, so these
/// calls don't need real escrow/offer state set up first - an unauthorized caller should be
/// rejected regardless of arguments.
contract AccessControlTest is EscrowTestBase {
    address internal randomAddress = address(0xD00D);

    // -----------------
    // onlyAdmin (escrow)
    // -----------------

    function test_AddAuthorizedUser_RevertsIfNotAdmin() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.addAuthorizedUser(randomAddress);
    }

    function test_RemoveAuthorizedUser_RevertsIfNotAdmin() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.removeAuthorizedUser(randomAddress);
    }

    function test_AddAuthorizedBroker_RevertsIfNotAdmin() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.addAuthorizedBroker(randomAddress);
    }

    function test_RemoveAuthorizedBroker_RevertsIfNotAdmin() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.removeAuthorizedBroker(randomAddress);
    }

    function test_MarkFundsAsReceivedAdmin_RevertsIfNotAdmin() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.markFundsAsReceivedAdmin(USDC, address(userWallet), 0);
    }

    function test_FreezeEscrow_RevertsIfNotAdmin() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.freezeEscrow(USDC, address(userWallet), 0);
    }

    function test_DefrostEscrow_RevertsIfNotAdmin() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.defrostEscrow(USDC, address(userWallet), 0);
    }

    function test_ReturnEscrow_RevertsIfNotAdmin() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.returnEscrow(USDC, address(userWallet), 0);
    }

    function test_WithdrawFees_RevertsIfNotAdmin() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.withdrawFees(USDC, payable(randomAddress));
    }

    function test_RemoveOngoingBrokerOffers_RevertsIfNotAdmin() public {
        EscrowStructs.RemoveOngoingBrokerOfferParam[] memory params = new EscrowStructs.RemoveOngoingBrokerOfferParam[](0);

        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.removeOngoingBrokerOffers(params);
    }

    function test_ConfiscateBrokerSecurityDeposit_RevertsIfNotAdmin() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.confiscateBrokerSecurityDeposit(address(brokerWallet));
    }

    function test_FreezeBrokerSecurityDeposit_RevertsIfNotAdmin() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.freezeBrokerSecurityDeposit(address(brokerWallet));
    }

    function test_SetConfigAddress_RevertsIfNotAdmin() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.setConfigAddress(address(escrowConfig));
    }

    // -----------------
    // onlyAuthorizedUsers (escrow)
    // -----------------

    function test_CreateEscrow_RevertsIfNotAuthorizedUser() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized user wallet");
        escrow.createEscrow(USDC, 1);
    }

    function test_LinkOfferToEscrow_RevertsIfNotAuthorizedUser() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized user wallet");
        escrow.linkOfferToEscrow(USDC, 0, address(brokerWallet), 0);
    }

    function test_MarkFundsAsReceived_RevertsIfNotAuthorizedUser() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized user wallet");
        escrow.markFundsAsReceived(USDC, 0);
    }

    function test_ExtendEscrow_RevertsIfNotAuthorizedUser() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized user wallet");
        escrow.extendEscrow(USDC, 0);
    }

    function test_WithdrawEscrowEarly_RevertsIfNotAuthorizedUser() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized user wallet");
        escrow.withdrawEscrowEarly(USDC, 0);
    }

    function test_WithdrawEscrowAfterReturn_RevertsIfNotAuthorizedUser() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized user wallet");
        escrow.withdrawEscrowAfterReturn(USDC, 0);
    }

    // -----------------
    // onlyAuthorizedBrokers (escrow)
    // -----------------

    function test_CreateOffer_RevertsIfNotAuthorizedBroker() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized broker wallet");
        escrow.createOffer(USDC, address(userWallet), 0, 0);
    }

    function test_CreateOfferWithExpiration_RevertsIfNotAuthorizedBroker() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized broker wallet");
        escrow.createOfferWithExpiration(USDC, address(userWallet), 0, 0, 1 hours);
    }

    function test_WithdrawEscrowAfterCompletion_RevertsIfNotAuthorizedBroker() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized broker wallet");
        escrow.withdrawEscrowAfterCompletion(USDC, address(userWallet), 0);
    }

    function test_UpsertSecurityDeposit_RevertsIfNotAuthorizedBroker() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized broker wallet");
        escrow.upsertSecurityDeposit(USDC, 1);
    }

    function test_WithdrawSecurityDeposit_RevertsIfNotAuthorizedBroker() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized broker wallet");
        escrow.withdrawSecurityDeposit();
    }
}
