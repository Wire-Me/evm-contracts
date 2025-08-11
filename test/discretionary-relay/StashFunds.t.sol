// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {IRelay} from "../../lib/deal-contracts/IRelay.sol";
import {CommonBase} from "../../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../../lib/forge-std/src/StdUtils.sol";
import {DiscretionaryRelayTest} from "./DiscretionaryRelayTest.t.sol";
import {console} from "../../lib/forge-std/src/console.sol";


contract DiscretionaryRelayStashFundsTest is DiscretionaryRelayTest {
    uint public requiredAmount = 1_000_000_000_000_000_000; // 1 ETH in wei

    function setUp() public override {
        DiscretionaryRelayTest.setUp(); // Call the setup from the base test contract
        // Create the relay
        _createDiscretionaryRelay(
            requiredAmount,
            alice,
            bob,
            _getUnlockAt(),
            _getReturnAfter(),
            alice
        );
    }

    function testStashFundsAfterApprovalHappyPath() public {
        _depositFunds();

        // Payer approves relay
        vm.prank(alice);
        relay.approveRelay(
            alice,
            0
        );

        // Payee's account balance should be zero before stashing
        uint accountBalanceBeforeStash = relay.accountBalances(bob);
        assertEq(accountBalanceBeforeStash, 0, "Payee's account balance should be zero before stashing");

        // Check the wallet balance of the payee before stashing
        uint initialWalletBalance = bob.balance;

        // Calculate expected amounts
        uint expectedPlatformFee = _calculateBasisPointProportion(requiredAmount, relay.basisPointFee());
        uint expectedPayeeAmount = requiredAmount - expectedPlatformFee;
        // Expect the event to be emitted
        vm.expectEmit(true, true, false, true);
        emit IRelay.FundsStashed(alice, 0, requiredAmount, expectedPayeeAmount, expectedPlatformFee);

        // Payee stashes funds
        vm.prank(bob);
        relay.stashFunds(
            alice,
            0
        );

        // Check the new account balance of the payee
        uint accountBalance = relay.accountBalances(bob);
        assertEq(accountBalance, expectedPayeeAmount, "Payee's account balance should match the expected amount");
        // Check the wallet balance of the payee
        assertEq(bob.balance, initialWalletBalance, "Payee's wallet balance should remain unchanged after stashing funds");

        // Check the account balance of the contract owner
        uint ownerAccountBalance = relay.accountBalances(owner);
        assertEq(ownerAccountBalance, expectedPlatformFee, "Owner's account balance should match the platform fee amount");

        // Check the relay balances
        (uint requiredBalance, uint currentBalance, bool isInitialized ) = relay.getRelayBalances(alice, 0);
        assertEq(requiredBalance, requiredAmount, "Required balance should remain unchanged after stashing");
        assertEq(currentBalance, 0, "Current balance should be zero after stashing");
        assertTrue(isInitialized, "Relay balances should be initialized after stashing");
    }

    function testStashFundsAfterReturnHappyPath() public {
        _depositFunds();

        // Payer returns relay
        vm.prank(alice);
        vm.warp(_getReturnAfter() + 1); // Ensure allowReturnAfter has passed
        relay.returnRelay(
            alice,
            0
        );

        // Payer's account balance should be zero before stashing
        uint accountBalanceBeforeStash = relay.accountBalances(alice);
        assertEq(accountBalanceBeforeStash, 0, "Payer's account balance should be zero before stashing");
        // Check the wallet balance of the payee before stashing
        uint initialWalletBalance = alice.balance;

        // Calculate expected amounts
        uint expectedPlatformFee = _calculateBasisPointProportion(requiredAmount, relay.basisPointFee());
        uint expectedPayeeAmount = requiredAmount - expectedPlatformFee;
        // Expect the event to be emitted
        vm.expectEmit(true, true, false, true);
        emit IRelay.FundsStashed(alice, 0, requiredAmount, expectedPayeeAmount, expectedPlatformFee);

        // Payer stashes funds
        vm.prank(alice);
        relay.stashFunds(
            alice,
            0
        );

        // Check the new account balance of the payer
        uint accountBalance = relay.accountBalances(alice);
        assertEq(accountBalance, expectedPayeeAmount, "Payer's account balance should match the expected amount");
        // Check the wallet balance of the payer
        assertEq(alice.balance, initialWalletBalance, "Payer's wallet balance should remain unchanged after stashing funds");

        // Check the account balance of the contract owner
        uint ownerAccountBalance = relay.accountBalances(owner);
        assertEq(ownerAccountBalance, expectedPlatformFee, "Owner's account balance should match the platform fee amount");

        // Check the relay balances
        (uint requiredBalance, uint currentBalance, bool isInitialized ) = relay.getRelayBalances(alice, 0);
        assertEq(requiredBalance, requiredAmount, "Required balance should remain unchanged after stashing");
        assertEq(currentBalance, 0, "Current balance should be zero after stashing");
        assertTrue(isInitialized, "Relay balances should be initialized after stashing");
    }

    function testStashFundsAfterUnlockTime() public {
        _depositFunds();

        // Time passes the unlock time
        vm.warp(_getUnlockAt() + 1);

        // Payee's account balance should be zero before stashing
        uint accountBalanceBeforeStash = relay.accountBalances(bob);
        assertEq(accountBalanceBeforeStash, 0, "Payee's account balance should be zero before stashing");
        // Check the wallet balance of the payee before stashing
        uint initialWalletBalance = bob.balance;

        // Calculate expected amounts
        uint expectedPlatformFee = _calculateBasisPointProportion(requiredAmount, relay.basisPointFee());
        uint expectedPayeeAmount = requiredAmount - expectedPlatformFee;
        // Expect the event to be emitted
        vm.expectEmit(true, true, false, true);
        emit IRelay.FundsStashed(alice, 0, requiredAmount, expectedPayeeAmount, expectedPlatformFee);

        // Payee can stash funds without approval because passed the unlock time
        vm.prank(bob);
        relay.stashFunds(
            alice,
            0
        );

        // Check the new account balance of the payee
        uint accountBalance = relay.accountBalances(bob);
        assertEq(accountBalance, expectedPayeeAmount, "Payee's account balance should match the expected amount");
        // Check the wallet balance of the payee
        assertEq(bob.balance, initialWalletBalance, "Payee's wallet balance should remain unchanged after stashing funds");

        // Check the account balance of the contract owner
        uint ownerAccountBalance = relay.accountBalances(owner);
        assertEq(ownerAccountBalance, expectedPlatformFee, "Owner's account balance should match the platform fee amount");

        // Check the relay balances
        (uint requiredBalance, uint currentBalance, bool isInitialized ) = relay.getRelayBalances(alice, 0);
        assertEq(requiredBalance, requiredAmount, "Required balance should remain unchanged after stashing");
        assertEq(currentBalance, 0, "Current balance should be zero after stashing");
        assertTrue(isInitialized, "Relay balances should be initialized after stashing");
    }

    function testStashFundsRevertsIfRelayNotLocked() public {
        vm.prank(bob);
        vm.expectRevert(IRelay.ErrRelayNotLocked.selector);
        relay.stashFunds(
            alice,
            0
        );
    }

    function testStashFundsRevertsIfRelayIsApprovedAndSenderIsNotPayee() public {
        _depositFunds();

        // Payer approves relay
        vm.prank(alice);
        relay.approveRelay(
            alice,
            0
        );

        // Alice tries to stash funds, but she is not the payee (she is the payer)
        vm.prank(alice);
        vm.expectRevert(IRelay.ErrSenderNotPayee.selector);
        relay.stashFunds(
            alice,
            0
        );

        // Dee tries to stash funds, but she is not the payee (she is not involved in the relay)
        vm.prank(dee);
        vm.expectRevert(IRelay.ErrSenderNotPayee.selector);
        relay.stashFunds(
            alice,
            0
        );
    }

    function testStashFundsRevertsIfRelayIsReturnedAndSenderIsNotPayer() public {
        _depositFunds();

        // Payer returns relay
        vm.warp(_getReturnAfter() + 1); // Ensure allowReturnAfter has passed
        vm.prank(alice);
        relay.returnRelay(
            alice,
            0
        );

        // Bob tries to stash funds after they have been returned to the payer, but he is not the payer (he is the payee)
        vm.prank(bob);
        vm.expectRevert(IRelay.ErrSenderNotPayer.selector);
        relay.stashFunds(
            alice,
            0
        );

        // Dee tries to stash funds after they have been returned to the payer, but she is not the payer (she is not involved in the relay)
        vm.prank(dee);
        vm.expectRevert(IRelay.ErrSenderNotPayer.selector);
        relay.stashFunds(
            alice,
            0
        );
    }

    function testStashFundsRevertsIfNotApprovedOrReturnedAndNotPastUnlockTime() public {
        _depositFunds();

        vm.warp(_getUnlockAt() - 1); // Ensure we are before the unlock time

        vm.prank(bob);
        vm.expectRevert(IRelay.ErrNotPastUnlockTime.selector);
        relay.stashFunds(
            alice,
            0
        );
    }

    function testStashFundsRevertsIfPastUnlockTimeNotApprovedOrReturnedAndNotPayee() public {
        _depositFunds();

        vm.warp(_getUnlockAt() + 1); // Ensure we are after the unlock time

        vm.prank(alice);
        vm.expectRevert(IRelay.ErrSenderNotPayee.selector);
        relay.stashFunds(
            alice,
            0
        );

        vm.prank(dee);
        vm.expectRevert(IRelay.ErrSenderNotPayee.selector);
        relay.stashFunds(
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