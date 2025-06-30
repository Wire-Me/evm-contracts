pragma solidity ^0.8.20;

import "../../lib/IRelay.sol";
import {CommonBase} from "../../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../../lib/forge-std/src/StdUtils.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";
import {TimeLockRelayTest} from "./TimeLockRelayTest.t.sol";


contract TimeLockRelayIsDisputableTest is TimeLockRelayTest {
    function testIsDisputable() public view {
        bool isDisputable = relay.isDisputable();
        assertEq(isDisputable, false);
    }
}