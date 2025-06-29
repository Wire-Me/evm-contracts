// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.23;


import {Test} from "../../lib/forge-std/src/Test.sol";
import {DiscretionaryRelay} from "../../lib/DiscretionaryRelay.sol";

abstract contract DiscretionaryRelayTest is Test {
    DiscretionaryRelay public relay;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public dee = address(0xDEE);
    uint public currentBlockTimestamp = 4102444800; // 2100/01/01 00:00:00 GMT

    function setUp() public virtual {
        relay = new DiscretionaryRelay("ETH", 100);
        vm.warp(currentBlockTimestamp); // Set the current block timestamp
    }

    function testIsDisputable() public view {
        bool isDisputable = relay.isDisputable();
        assertEq(isDisputable, false);
    }
}