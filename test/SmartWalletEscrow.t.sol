// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "./helpers/EscrowTestBase.sol";

contract SmartWalletEscrowTest is EscrowTestBase {

    function test_CreateEscrow_WithERC20() public {

        uint amount = 100 * 10 ** 6;

        vm.startPrank(admin);

        // Approve escrow from wallet
        userWallet.transferFundsAndCreateEscrow(USDC, amount);

        vm.stopPrank();

        // Verify escrow exists
        EscrowStructs.FXEscrow memory escrowData = escrow.getEscrow(USDC, address(userWallet), 0);

        assertEq(escrowData.amount, amount);
        assertEq(escrowData.token, USDC);
        assertTrue(escrowData.createdAt > 0);
        assertFalse(escrowData.isWithdrawn);

        // Ensure funds moved to escrow contract
        assertEq(usdc.balanceOf(address(escrow)), amount);
        assertEq(usdc.balanceOf(address(userWallet)), 900 * 10 ** 6);
    }

    function test_CreateOffer_WithERC20() public {

        vm.startPrank(admin);

        // -----------------
        // Create the Transaction
        // -----------------

        uint amount = 100 * 10 ** 6;
        userWallet.transferFundsAndCreateEscrow(USDC, amount);

        // Approve escrow from wallet
        brokerWallet.createOffer(USDC, address(userWallet), 0, 0);

        vm.stopPrank();

        // Verify off exists
        EscrowStructs.FXEscrowOffer memory offerData = escrow.getOffer(USDC, address(brokerWallet), 0);

        assertEq(offerData.feeBasisPoints, 0);
        assertTrue(offerData.createdAt > 0);
        assertEq(offerData.escrowAccount, address(userWallet));
        assertEq(offerData.escrowIndex, 0);
    }

    function test_CreateOfferWithExpiration_UsesCustomDuration() public {
        vm.startPrank(admin);

        uint amount = 100 * 10 ** 6;
        userWallet.transferFundsAndCreateEscrow(USDC, amount);

        uint256 customDuration = 3 hours;
        brokerWallet.createOfferWithExpiration(USDC, address(userWallet), 0, 0, customDuration);

        userWallet.linkOfferToEscrow(USDC, 0, address(brokerWallet), 0);

        uint256 expectedTimestamp = block.timestamp + customDuration;
        userWallet.markFundsAsReceived(USDC, 0);

        vm.stopPrank();

        EscrowStructs.FXEscrow memory escrowData = escrow.getEscrow(USDC, address(userWallet), 0);
        assertEq(escrowData.expirationTimestamp, expectedTimestamp);
    }

    function test_CreateOfferWithExpiration_RevertsAboveMaxDuration() public {
        vm.startPrank(admin);

        uint amount = 100 * 10 ** 6;
        userWallet.transferFundsAndCreateEscrow(USDC, amount);

        uint256 tooLong = escrow.MAX_OFFER_EXPIRATION_DURATION() + 1;

        vm.expectRevert("Expiration duration exceeds maximum allowed");
        brokerWallet.createOfferWithExpiration(USDC, address(userWallet), 0, 0, tooLong);

        vm.stopPrank();
    }

    function test_CreateOffer_WithoutExpiration_FallsBackToBrokerDepositLogic() public {
        vm.startPrank(admin);

        uint amount = 100 * 10 ** 6;
        userWallet.transferFundsAndCreateEscrow(USDC, amount);

        // Broker has no security deposit, so the non-broker fallback duration applies
        brokerWallet.createOffer(USDC, address(userWallet), 0, 0);
        userWallet.linkOfferToEscrow(USDC, 0, address(brokerWallet), 0);

        uint256 expectedTimestamp = block.timestamp + escrow.EXPIRATION_DURATION_FOR_NON_BROKERS();
        userWallet.markFundsAsReceived(USDC, 0);

        vm.stopPrank();

        EscrowStructs.FXEscrow memory escrowData = escrow.getEscrow(USDC, address(userWallet), 0);
        assertEq(escrowData.expirationTimestamp, expectedTimestamp);
    }

    function test_DepositSecurityDeposit() public {

        vm.startPrank(admin);

        // -----------------
        // Deposit the security deposit
        // -----------------

        uint amount = 500 * 10 ** 6;
        brokerWallet.depositSecurityDeposit(USDC, amount);

        vm.stopPrank();

        // Verify deposit exists
        EscrowStructs.BrokerDeposit memory brokerDeposit = escrow.getBrokerDeposit(address(brokerWallet));

        assertEq(brokerDeposit.amount, amount);
        assertTrue(brokerDeposit.createdAt > 0);

        // Verify funds moved to escrow contract
        assertEq(usdc.balanceOf(address(escrow)), amount);
        assertEq(usdc.balanceOf(address(brokerWallet)), brokerInitialBalance - amount);
    }

    function test_WithdrawSecurityDeposit() public {

        vm.startPrank(admin);

        // -----------------
        // Deposit the security deposit
        // -----------------

        uint amount = 500 * 10 ** 6;
        brokerWallet.depositSecurityDeposit(USDC, amount);

        vm.stopPrank();

        // Verify deposit exists
        EscrowStructs.BrokerDeposit memory brokerDeposit = escrow.getBrokerDeposit(address(brokerWallet));

        assertEq(brokerDeposit.amount, amount);
        assertTrue(brokerDeposit.createdAt > 0);

        // Verify funds moved to escrow contract
        assertEq(usdc.balanceOf(address(escrow)), amount);
        assertEq(usdc.balanceOf(address(brokerWallet)), brokerInitialBalance - amount);

        // -----------------
        // Withdraw the security deposit
        // -----------------

        vm.startPrank(admin);

        brokerWallet.withdrawSecurityDeposit();

        // Verify funds moved from escrow contract
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(usdc.balanceOf(address(brokerWallet)), brokerInitialBalance);

        vm.stopPrank();
    }
}
