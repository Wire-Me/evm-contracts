// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {IRelay} from "../../lib/deal-contracts/IRelay.sol";
import {CommonBase} from "../../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../../lib/forge-std/src/StdUtils.sol";
import {TimeLockRelayTest} from "./TimeLockRelayTest.t.sol";
import {TimeLockRelay} from "../../lib/deal-contracts/TimeLockRelay.sol";


contract TimeLockRelayBaseTest is TimeLockRelayTest {
    string public coinSymbol = "ETH";
    uint public basisPointFee = 100;

    function setUp() public override {
        vm.prank(owner);
        relay = new TimeLockRelay(coinSymbol, basisPointFee);
    }

    function testOwner() public view {
        assertEq(relay.owner(), owner);
    }

    function testCoinSymbol() public view {
        assertEq(relay.coinSymbol(), coinSymbol);
    }

    function testBasisPointFee() public view {
        assertEq(relay.basisPointFee(), basisPointFee);
    }
}