// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {IRelay} from "../../lib/IRelay.sol";
import {CommonBase} from "../../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../../lib/forge-std/src/StdUtils.sol";
import {TimeLockRelayTest} from "./TimeLockRelayTest.t.sol";


contract TimeLockRelayDepositFundsTest is TimeLockRelayTest {
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

    function testDepositFundsHappyPath() public {
        // Deposit funds into the relay
        uint depositAmount = requiredAmount;
        // Expect the FundsDeposited event to be emitted
        vm.expectEmit(true, true, false, true);
        emit IRelay.FundsDeposited(alice, 0, depositAmount, depositAmount, depositAmount);
        // Alice deposit the funds
        vm.prank(alice);
        relay.depositFunds{value: depositAmount}(alice, 0);
        // Check the relay balances
        (uint requiredBalance2, uint currentBalance2, bool isInitialized4) = relay.getRelayBalances(alice, 0);
        assertEq(requiredBalance2, depositAmount);
        assertEq(currentBalance2, depositAmount);
        assertTrue(isInitialized4);
        (bool isLocked2, bool isReturning2, bool isApproved2, uint automaticallyUnlockAt2, uint allowReturnAfter2, bool isInitialized5) = relay.getRelayState(alice, 0);
        assertTrue(isLocked2); // The relay should be locked after deposit
        assertFalse(isReturning2);
        assertFalse(isApproved2);
        assertEq(automaticallyUnlockAt2, _getUnlockAt());
        assertEq(allowReturnAfter2, _getReturnAfter());
        assertTrue(isInitialized5);
    }

    function testDepositFundsRevertsWhenFundsDepositedNotEqualToRequiredBalance() public {
        vm.prank(alice);
        vm.expectRevert(IRelay.ErrDepositAmountNotEqualToRequiredAmount.selector);
        relay.depositFunds{value: requiredAmount + 1}(alice, 0);
    }
}