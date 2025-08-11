// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;


import {Test} from "../../lib/forge-std/src/Test.sol";
import {DiscretionaryRelay} from "../../lib/deal-contracts/DiscretionaryRelay.sol";
import {TimeLockRelay} from "../../lib/deal-contracts/TimeLockRelay.sol";

abstract contract TimeLockRelayTest is Test {
    TimeLockRelay public relay;
    address public owner = address(0xb055);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public dee = address(0xDEE);
    uint public currentBlockTimestamp = 4102444800; // 2100/01/01 00:00:00 GMT

    function setUp() public virtual {
        vm.prank(owner);
        relay = new TimeLockRelay("ETH", 100);
        vm.warp(currentBlockTimestamp); // Set the current block timestamp

        // Fund the addresses with some ether for testing – 10 ETH for each
        vm.deal(alice, 10_000_000_000_000_000_000);
        vm.deal(bob, 10_000_000_000_000_000_000);
        vm.deal(dee, 10_000_000_000_000_000_000);
    }

    function _createTimeLockRelay(uint _requiredBalance, address _payer, address _payee, uint _automaticallyUnlockAt, address _creator) internal {
        vm.prank(_creator);

        relay.createRelay(
            _requiredBalance,
            _payer,
            _payee,
            _automaticallyUnlockAt,
            0
        );
    }

    function _getUnlockAt() internal view returns (uint) {
        return currentBlockTimestamp + 10 days;
    }

    function _getReturnAfter() internal pure returns (uint) {
        return 0;
    }

    function _calculateBasisPointProportion(uint _amount, uint basisPoints) internal pure returns (uint) {
        return (_amount * basisPoints) / 10000;
    }
}