// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;


import "../../lib/IRelay.sol";
import {CommonBase} from "../../lib/forge-std/src/Base.sol";
import {DiscretionaryRelay} from "../../lib/DiscretionaryRelay.sol";
import {StdAssertions} from "../../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../../lib/forge-std/src/StdUtils.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";
import {console} from "../../lib/forge-std/src/console.sol";
import {DiscretionaryRelayTest} from "./DiscretionaryRelayTest.t.sol";

contract DiscretionaryRelayCreateRelayTest is DiscretionaryRelayTest {
    function setUp() public override {
        DiscretionaryRelayTest.setUp(); // Call the setup from the base test contract
    }

    function testCreateRelayHappyPath() public {
        uint requiredAmount = 1_000_000_000_000_000_000; // 1 ETH in wei
        uint unlockAt = block.timestamp + 10 days;
        uint returnAfter = block.timestamp + 5 days;

        vm.expectEmit(true, true, false, true);
        emit IRelay.RelayCreated(alice, 0, alice, bob);

        _createDiscretionaryRelay(
            requiredAmount,
            alice,
            bob,
            unlockAt,
            returnAfter,
            alice
        );

        (address payer, address payee, address creator, bool isInitialized1) = relay.getRelayActors(alice, 0);
        assertEq(payer, alice);
        assertEq(payee, bob);
        assertEq(creator, alice);
        assertTrue(isInitialized1);
        (uint requiredBalance, uint currentBalance, bool isInitialized2 ) = relay.getRelayBalances(alice, 0);
        assertEq(requiredBalance, requiredAmount);
        assertEq(currentBalance, 0);
        assertTrue(isInitialized2);
        (bool isLocked, bool isReturning, bool isApproved, uint automaticallyUnlockAt, uint allowReturnAfter, bool isInitialized3) = relay.getRelayState(alice, 0);
        assertFalse(isLocked);
        assertFalse(isReturning);
        assertFalse(isApproved);
        assertEq(unlockAt, automaticallyUnlockAt);
        assertEq(returnAfter, allowReturnAfter);
        assertTrue(isInitialized3);
    }

    function testCreateRelayRevertsWhenPayerAndPayeeAreSame() public {
        uint requiredBalance = 1_000_000_000_000_000_000; // 1 ETH in wei
        uint unlockAt = block.timestamp + 10 days;
        uint allowReturnAfter = block.timestamp + 5 days;

        vm.expectRevert(IRelay.ErrPayerEqualsPayee.selector);
        vm.prank(alice);
        relay.createRelay(
            requiredBalance,
            alice,
            alice, // Same address for payer and payee
            unlockAt,
            allowReturnAfter
        );
    }

    function testCreateRelayRevertsWhenRequiredBalanceIsZero() public {
        uint requiredBalance = 0; // 0 ETH in wei
        uint unlockAt = block.timestamp + 10 days;
        uint allowReturnAfter = block.timestamp + 5 days;

        vm.expectRevert(IRelay.ErrRequiredBalanceNotGreaterThanZero.selector);
        vm.prank(alice);
        relay.createRelay(
            requiredBalance,
            alice,
            bob,
            unlockAt,
            allowReturnAfter
        );
    }

    function testCreateRelayRevertsWhenSenderIsNotPayerOrPayee() public {
        uint requiredBalance = 1_000_000_000_000_000_000; // 1 ETH in wei
        uint unlockAt = block.timestamp + 10 days;
        uint allowReturnAfter = block.timestamp + 5 days;

        vm.expectRevert(IRelay.ErrSenderNotPayerOrPayee.selector);
        vm.prank(dee); // Dee is not the payer or payee
        relay.createRelay(
            requiredBalance,
            alice,
            bob,
            unlockAt,
            allowReturnAfter
        );
    }

    function testCreateRelayRevertsWhenPayerIsZeroAddress() public {
        uint requiredBalance = 1_000_000_000_000_000_000; // 1 ETH in wei
        uint unlockAt = block.timestamp + 10 days;
        uint allowReturnAfter = block.timestamp + 5 days;

        vm.expectRevert(IRelay.ErrPayerHasZeroAddress.selector);
        vm.prank(alice);
        relay.createRelay(
            requiredBalance,
            address(0), // Zero address for payer
            alice,
            unlockAt,
            allowReturnAfter
        );
    }

    function testCreateRelayRevertsWhenPayeeIsZeroAddress() public {
        uint requiredBalance = 1_000_000_000_000_000_000; // 1 ETH in wei
        uint unlockAt = block.timestamp + 10 days;
        uint allowReturnAfter = block.timestamp + 5 days;

        vm.expectRevert(IRelay.ErrPayeeHasZeroAddress.selector);
        vm.prank(alice);
        relay.createRelay(
            requiredBalance,
            alice,
            address(0), // Zero address for payee
            unlockAt,
            allowReturnAfter
        );
    }

    function testCreateRelayRevertsWhenAutomaticallyApprovedAtInPast() public {
        uint requiredBalance = 1_000_000_000_000_000_000; // 1 ETH in wei
        uint unlockAt = 946684800; // In the past – 2000/01/01 00:00:00 GMT
        uint allowReturnAfter = block.timestamp + 5 days;

        vm.expectRevert(IRelay.ErrUnlockAtNotInFuture.selector);
        vm.prank(alice);
        relay.createRelay(
            requiredBalance,
            alice,
            bob,
            unlockAt,
            allowReturnAfter
        );
    }

    function testCreateRelayRevertsWhenAutomaticallyApprovedAtLessThanAllowReturnAfter() public {
        uint requiredBalance = 1_000_000_000_000_000_000; // 1 ETH in wei
        uint unlockAt = block.timestamp + 5 days; // Automatically approved at
        uint allowReturnAfter = block.timestamp + 10 days; // Allow return after

        vm.expectRevert(IRelay.ErrUnlockAtNotGreaterThanReturnAfter.selector);
        vm.prank(alice);
        relay.createRelay(
            requiredBalance,
            alice,
            bob,
            unlockAt,
            allowReturnAfter
        );
    }
}