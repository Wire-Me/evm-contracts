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

        // Fund the addresses with some ether for testing – 10 ETH for each
        vm.deal(alice, 10_000_000_000_000_000_000);
        vm.deal(bob, 10_000_000_000_000_000_000);
        vm.deal(dee, 10_000_000_000_000_000_000);
    }

    function _createDiscretionaryRelay(uint _requiredBalance, address _payer, address _payee, uint _automaticallyUnlockAt, uint _allowReturnAfter, address _creator) internal {
        vm.prank(_creator);

        relay.createRelay(
            _requiredBalance,
            _payer,
            _payee,
            _automaticallyUnlockAt,
            _allowReturnAfter
        );
    }

    function _getUnlockAt() internal view returns (uint) {
        return block.timestamp + 10 days;
    }

    function _getReturnAfter() internal view returns (uint) {
        return block.timestamp + 5 days;
    }
}