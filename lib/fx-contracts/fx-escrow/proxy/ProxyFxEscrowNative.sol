// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {ProxyFxEscrow} from "./ProxyFxEscrow.sol";

contract ProxyFxEscrowNative is ProxyFxEscrow {
    constructor(address _impl, address _admin) ProxyFxEscrow(_impl, _admin) {}
}