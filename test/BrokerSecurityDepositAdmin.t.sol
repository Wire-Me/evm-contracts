// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "./helpers/EscrowTestBase.sol";

/// @notice Covers broker-security-deposit admin actions (confiscate/freeze) and the 48-hour
/// cooldown rule in canWithdrawSecurityDeposit after a broker's most recent offer.
contract BrokerSecurityDepositAdminTest is EscrowTestBase {
    uint internal constant DEPOSIT_AMOUNT = 500 * 10 ** 6;
    uint internal constant ESCROW_AMOUNT = 100 * 10 ** 6;

    function _deposit() internal {
        vm.prank(admin);
        brokerWallet.depositSecurityDeposit(USDC, DEPOSIT_AMOUNT);
    }

    // -----------------
    // confiscateBrokerSecurityDeposit
    // -----------------

    function test_ConfiscateBrokerSecurityDeposit_MovesFundsToPlatformFees() public {
        _deposit();

        vm.prank(admin);
        escrow.confiscateBrokerSecurityDeposit(address(brokerWallet));

        EscrowStructs.BrokerDeposit memory deposit = escrow.getBrokerDeposit(address(brokerWallet));
        assertEq(deposit.amount, 0);
        assertEq(escrow.getPlatformFeeBalance(USDC), DEPOSIT_AMOUNT);
    }

    function test_ConfiscateBrokerSecurityDeposit_RevertsIfNoDeposit() public {
        vm.prank(admin);
        vm.expectRevert("No security deposit to confiscate");
        escrow.confiscateBrokerSecurityDeposit(address(brokerWallet));
    }

    // -----------------
    // freezeBrokerSecurityDeposit
    // -----------------

    function test_FreezeBrokerSecurityDeposit_SetsFrozenFlag() public {
        _deposit();

        vm.prank(admin);
        escrow.freezeBrokerSecurityDeposit(address(brokerWallet));

        assertTrue(escrow.isBrokerSecurityDepositFrozen(address(brokerWallet)));
    }

    function test_FreezeBrokerSecurityDeposit_RevertsIfNoDeposit() public {
        vm.prank(admin);
        vm.expectRevert("Broker does not have a security deposit to freeze");
        escrow.freezeBrokerSecurityDeposit(address(brokerWallet));
    }

    function test_WithdrawSecurityDeposit_RevertsIfFrozen() public {
        _deposit();

        vm.startPrank(admin);
        escrow.freezeBrokerSecurityDeposit(address(brokerWallet));

        vm.expectRevert("Broker's security deposit is currently frozen");
        brokerWallet.withdrawSecurityDeposit();
        vm.stopPrank();
    }

    // -----------------
    // canWithdrawSecurityDeposit 48h cooldown
    // -----------------

    function test_CanWithdrawSecurityDeposit_FalseWithin48HoursOfLastOffer() public {
        _deposit();

        vm.startPrank(admin);
        userWallet.transferFundsAndCreateEscrow(USDC, ESCROW_AMOUNT);
        brokerWallet.createOffer(USDC, address(userWallet), 0, 0);
        vm.stopPrank();

        assertFalse(escrow.canWithdrawSecurityDeposit(address(brokerWallet)));
    }

    function test_CanWithdrawSecurityDeposit_TrueAfter48HoursOfLastOffer() public {
        _deposit();

        vm.startPrank(admin);
        userWallet.transferFundsAndCreateEscrow(USDC, ESCROW_AMOUNT);
        brokerWallet.createOffer(USDC, address(userWallet), 0, 0);
        vm.stopPrank();

        vm.warp(block.timestamp + 48 hours + 1);

        assertTrue(escrow.canWithdrawSecurityDeposit(address(brokerWallet)));
    }

    function test_WithdrawSecurityDeposit_RevertsWithin48HoursOfLastOffer() public {
        _deposit();

        vm.startPrank(admin);
        userWallet.transferFundsAndCreateEscrow(USDC, ESCROW_AMOUNT);
        brokerWallet.createOffer(USDC, address(userWallet), 0, 0);

        vm.expectRevert("Cannot withdraw security deposit yet");
        brokerWallet.withdrawSecurityDeposit();
        vm.stopPrank();
    }
}
