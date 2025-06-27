pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DiscretionaryRelay} from "../lib/DiscretionaryRelay.sol";

contract CreateDiscretionaryRelayTest is Test {
    DiscretionaryRelay public relay;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        relay = new DiscretionaryRelay("ETH", 100);
    }

    function testCreateRelayHappyPath() public {
        uint requiredBalance = 1_000_000_000_000_000_000 ; // 1 ETH in wei
        uint unlockAt = block.timestamp + 10 days;
        uint allowReturnAfter = block.timestamp + 5 days;
        vm.prank(alice);

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
//        assertEq(relay.relays[alice][0].payer, alice);
//        assertEq(relay.relays[alice][0].payee, bob);
//        assertEq(relay.relays[alice][0].automaticallyUnlockAt, unlockAt);
//        assertEq(relay.relays[alice][0].allowReturnAfter, allowReturnAfter);
    }
}