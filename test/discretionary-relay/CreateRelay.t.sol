pragma solidity ^0.8.20;

import "../../lib/IRelay.sol";
import {CommonBase} from "../../lib/forge-std/src/Base.sol";
import {DiscretionaryRelay} from "../../lib/DiscretionaryRelay.sol";
import {StdAssertions} from "../../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../../lib/forge-std/src/StdUtils.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";

contract DiscretionaryRelayCreateRelayTest is Test {
    DiscretionaryRelay public relay;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public dee = address(0xDEE);

    function setUp() public {
        relay = new DiscretionaryRelay("ETH", 100);
    }

    function testCreateRelayHappyPath() public {
        uint requiredBalance = 1_000_000_000_000_000_000; // 1 ETH in wei
        uint unlockAt = block.timestamp + 10 days;
        uint allowReturnAfter = block.timestamp + 5 days;
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit IRelay.RelayCreated(alice, 0, alice, bob);

        relay.createRelay(
            requiredBalance,
            alice,
            bob,
            unlockAt,
            allowReturnAfter
        );

        (address payer, address payee, address creator, bool initialized) = relay.getRelayActors(alice, 0);
        assertEq(payer, alice);
        assertEq(payee, bob);
        assertEq(creator, alice);
        assertTrue(initialized);
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
        uint currentTimestamp = 4102444800; // 2100/01/01 00:00:00 GMT
        vm.warp(currentTimestamp); // Set the current block timestamp
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