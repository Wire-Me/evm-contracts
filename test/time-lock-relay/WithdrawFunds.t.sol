// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {IRelay} from "../../lib/IRelay.sol";
import {CommonBase} from "../../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../../lib/forge-std/src/StdUtils.sol";
import {TimeLockRelayTest} from "./TimeLockRelayTest.t.sol";
import {console} from "../../lib/forge-std/src/console.sol";


contract DiscretionaryRelayWithdrawFundsTest is TimeLockRelayTest {
    uint public requiredAmount = 1_000_000_000_000_000_000; // 1 ETH in wei

    function setUp() public override {
        TimeLockRelayTest.setUp(); // Call the setup from the base test contract
        // Create the relay
        _createTimeLockRelay(
            requiredAmount,
            alice,
            bob,
            _getUnlockAt(),
            alice
        );
    }

    function testWithdrawFundsAfterApprovalHappyPath() public {
        _depositFunds();

        // Payer approves relay
        vm.prank(alice);
        relay.approveRelay(
            alice,
            0
        );

        // Payee's account balance should be zero before withdrawing
        uint accountBalanceBeforeWithdraw = relay.accountBalances(bob);
        assertEq(accountBalanceBeforeWithdraw, 0, "Payee's account balance should be zero before withdrawing");

        // Check the wallet balance of the payee before withdrawing
        uint initialWalletBalance = bob.balance;

        // Calculate expected amounts
        uint expectedPlatformFee = _calculateBasisPointProportion(requiredAmount, relay.basisPointFee());
        uint expectedPayeeAmount = requiredAmount - expectedPlatformFee;
        // Expect the event to be emitted
        vm.expectEmit(true, true, false, true);
        emit IRelay.FundsWithdrawn(alice, 0, requiredAmount, expectedPayeeAmount, expectedPlatformFee);

        // Payee withdraws funds
        vm.prank(bob);
        relay.withdrawFunds(
            alice,
            0
        );

        // Check the new account balance of the payee
        uint accountBalance = relay.accountBalances(bob);
        assertEq(accountBalance, 0, "Payee's account balance should still be zero after withdrawing funds");
        // Check the wallet balance of the payee
        assertEq(bob.balance, initialWalletBalance + expectedPayeeAmount, "Payee's wallet balance should match the expected amount after withdrawing funds");

        // Check the account balance of the contract owner
        uint ownerAccountBalance = relay.accountBalances(owner);
        assertEq(ownerAccountBalance, expectedPlatformFee, "Owner's account balance should match the platform fee amount");

        // Check the relay balances
        (uint requiredBalance, uint currentBalance, bool isInitialized ) = relay.getRelayBalances(alice, 0);
        assertEq(requiredBalance, requiredAmount, "Required balance should remain unchanged after withdrawal");
        assertEq(currentBalance, 0, "Current balance should be zero after withdrawal");
        assertTrue(isInitialized, "Relay balances should be initialized after withdrawal");
    }

    function testWithdrawFundsAfterReturnHappyPath() public {
        _depositFunds();

        // Payee returns relay
        vm.prank(bob);
        relay.returnRelay(
            alice,
            0
        );

        // Payer's account balance should be zero before withdrawing
        uint accountBalanceBeforeWithdraw = relay.accountBalances(alice);
        assertEq(accountBalanceBeforeWithdraw, 0, "Payer's account balance should be zero before withdrawing");

        // Check the wallet balance of the payer before withdrawing
        uint initialWalletBalance = alice.balance;

        // Calculate expected amounts
        uint expectedPlatformFee = _calculateBasisPointProportion(requiredAmount, relay.basisPointFee());
        uint expectedPayeeAmount = requiredAmount - expectedPlatformFee;
        // Expect the event to be emitted
        vm.expectEmit(true, true, false, true);
        emit IRelay.FundsWithdrawn(alice, 0, requiredAmount, expectedPayeeAmount, expectedPlatformFee);

        // Payer withdraws funds
        vm.prank(alice);
        relay.withdrawFunds(
            alice,
            0
        );

        // Check the new account balance of the payer
        uint accountBalance = relay.accountBalances(alice);
        assertEq(accountBalance, 0, "Payer's account balance should still be zero after withdrawing funds");

        // Check the wallet balance of the payer
        assertEq(alice.balance, initialWalletBalance + expectedPayeeAmount, "Payer's wallet balance should match the expected amount after withdrawing funds");

        // Check the account balance of the contract owner
        uint ownerAccountBalance = relay.accountBalances(owner);
        assertEq(ownerAccountBalance, expectedPlatformFee, "Owner's account balance should match the platform fee amount");

        // Check the relay balances
        (uint requiredBalance, uint currentBalance, bool isInitialized ) = relay.getRelayBalances(alice, 0);
        assertEq(requiredBalance, requiredAmount, "Required balance should remain unchanged after withdrawal");
        assertEq(currentBalance, 0, "Current balance should be zero after withdrawal");
        assertTrue(isInitialized, "Relay balances should be initialized after withdrawal");
    }

    function testWithdrawFundsAfterUnlockTime() public {
        _depositFunds();

        // Time passes the unlock time
        vm.warp(_getUnlockAt() + 1);

        // Payee's account balance should be zero before withdrawing
        uint accountBalanceBeforeWithdraw = relay.accountBalances(bob);
        assertEq(accountBalanceBeforeWithdraw, 0, "Payee's account balance should be zero before withdrawing");

        // Check the wallet balance of the payee before withdrawing
        uint initialWalletBalance = bob.balance;

        // Calculate expected amounts
        uint expectedPlatformFee = _calculateBasisPointProportion(requiredAmount, relay.basisPointFee());
        uint expectedPayeeAmount = requiredAmount - expectedPlatformFee;
        // Expect the event to be emitted
        vm.expectEmit(true, true, false, true);
        emit IRelay.FundsWithdrawn(alice, 0, requiredAmount, expectedPayeeAmount, expectedPlatformFee);

        // Payee can withdraw funds without approval because passed the unlock time
        vm.prank(bob);
        relay.withdrawFunds(
            alice,
            0
        );

        // Check the new account balance of the payee
        uint accountBalance = relay.accountBalances(bob);
        assertEq(accountBalance, 0, "Payee's account balance should still be zero after withdrawing funds");

        // Check the wallet balance of the payee
        assertEq(bob.balance, initialWalletBalance + expectedPayeeAmount, "Payee's wallet balance should match the expected amount after withdrawing funds");

        // Check the account balance of the contract owner
        uint ownerAccountBalance = relay.accountBalances(owner);
        assertEq(ownerAccountBalance, expectedPlatformFee, "Owner's account balance should match the platform fee amount");

        // Check the relay balances
        (uint requiredBalance, uint currentBalance, bool isInitialized ) = relay.getRelayBalances(alice, 0);
        assertEq(requiredBalance, requiredAmount, "Required balance should remain unchanged after withdrawal");
        assertEq(currentBalance, 0, "Current balance should be zero after withdrawal");
        assertTrue(isInitialized, "Relay balances should be initialized after withdrawal");
    }

    function testWithdrawFundsRevertsIfRelayNotLocked() public {
        vm.prank(bob);
        vm.expectRevert(IRelay.ErrRelayNotLocked.selector);
        relay.withdrawFunds(
            alice,
            0
        );
    }

    function testWithdrawFundsRevertsIfRelayIsApprovedAndSenderIsNotPayee() public {
        _depositFunds();

        // Payer approves relay
        vm.prank(alice);
        relay.approveRelay(
            alice,
            0
        );

        // Alice tries to withdraw funds, but she is not the payee (she is the payer)
        vm.prank(alice);
        vm.expectRevert(IRelay.ErrSenderNotPayee.selector);
        relay.withdrawFunds(
            alice,
            0
        );

        // Dee tries to withdraw funds, but she is not the payee (she is not involved in the relay)
        vm.prank(dee);
        vm.expectRevert(IRelay.ErrSenderNotPayee.selector);
        relay.withdrawFunds(
            alice,
            0
        );
    }

    function testWithdrawFundsRevertsIfRelayIsReturnedAndSenderIsNotPayer() public {
        _depositFunds();

        // Payee returns relay
        vm.prank(bob);
        relay.returnRelay(
            alice,
            0
        );

        // Bob tries to withdraw funds after they have been returned to the payer, but he is not the payer (he is the payee)
        vm.prank(bob);
        vm.expectRevert(IRelay.ErrSenderNotPayer.selector);
        relay.withdrawFunds(
            alice,
            0
        );

        // Dee tries to withdraw funds after they have been returned to the payer, but she is not the payer (she is not involved in the relay)
        vm.prank(dee);
        vm.expectRevert(IRelay.ErrSenderNotPayer.selector);
        relay.withdrawFunds(
            alice,
            0
        );
    }

    function testWithdrawFundsRevertsIfNotApprovedOrReturnedAndNotPastUnlockTime() public {
        _depositFunds();

        vm.warp(_getUnlockAt() - 1); // Ensure we are before the unlock time

        vm.prank(bob);
        vm.expectRevert(IRelay.ErrNotPastUnlockTime.selector);
        relay.withdrawFunds(
            alice,
            0
        );
    }

    function testWithdrawFundsRevertsIfPastUnlockTimeNotApprovedOrReturnedAndNotPayee() public {
        _depositFunds();

        vm.warp(_getUnlockAt() + 1); // Ensure we are after the unlock time

        vm.prank(alice);
        vm.expectRevert(IRelay.ErrSenderNotPayee.selector);
        relay.withdrawFunds(
            alice,
            0
        );

        vm.prank(dee);
        vm.expectRevert(IRelay.ErrSenderNotPayee.selector);
        relay.withdrawFunds(
            alice,
            0
        );
    }

    function _depositFunds() private {
        // Alice deposit the funds
        vm.prank(alice);
        relay.depositFunds{value: requiredAmount}(alice, 0);
    }
}