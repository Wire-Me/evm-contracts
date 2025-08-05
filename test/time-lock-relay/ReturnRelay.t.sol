// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {IRelay} from "../../lib/deal-contracts/IRelay.sol";
import {CommonBase} from "../../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../../lib/forge-std/src/StdUtils.sol";
import {TimeLockRelayTest} from "./TimeLockRelayTest.t.sol";


contract TimeLockRelayReturnRelayTest is TimeLockRelayTest {
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

    function testReturnRelayHappyPath() public {
        _depositFunds();

        // Expect the RelayApproved event to be emitted
        vm.expectEmit(true, true, false, false);
        emit IRelay.RelayReturned(alice, 0);
        // Bob returns the relay
        vm.prank(bob);
        relay.returnRelay(
            alice,
            0
        );
        (bool isLocked, bool isReturning, bool isApproved, uint automaticallyUnlockAt, uint allowReturnAfter, bool isInitialized) = relay.getRelayState(alice, 0);
        assertTrue(isLocked);
        assertTrue(isReturning);
        assertFalse(isApproved); // The relay should be approved after approval
        assertEq(automaticallyUnlockAt, _getUnlockAt());
        assertEq(allowReturnAfter, _getReturnAfter());
        assertTrue(isInitialized);
    }

    function testApproveRelayRevertsIfRelayNotLocked() public {
        vm.expectRevert(IRelay.ErrRelayNotLocked.selector);
        vm.prank(bob);
        relay.returnRelay(
            alice,
            0
        );
    }

    function testReturnRelayRevertsIfRelayAlreadyApproved() public {
        _depositFunds();

        vm.prank(alice);
        relay.approveRelay(alice, 0); // Approve the relay first

        vm.prank(bob);
        vm.expectRevert(IRelay.ErrRelayAlreadyApprovedOrReturned.selector);
        relay.returnRelay(
            alice,
            0
        );
    }

    function testReturnRelayRevertsIfSenderNotPayee() public {
        _depositFunds();

        vm.prank(alice);
        vm.expectRevert(IRelay.ErrSenderNotPayee.selector);
        relay.returnRelay(
            alice,
            0
        );

        vm.prank(dee);
        vm.expectRevert(IRelay.ErrSenderNotPayee.selector);
        relay.returnRelay(
            alice,
            0
        );
    }

    function testReturnRelayRevertsIfRelayAlreadyReturned() public {
        _depositFunds();

        vm.prank(bob);
        relay.returnRelay(alice, 0); // Return the relay first

        vm.expectRevert(IRelay.ErrRelayAlreadyApprovedOrReturned.selector);
        vm.prank(bob);
        relay.returnRelay(
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