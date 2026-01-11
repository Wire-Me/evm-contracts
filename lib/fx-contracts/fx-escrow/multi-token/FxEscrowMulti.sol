// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "./configuration/EscrowConfig.sol";
import {AbstractFxEscrowMulti} from "./AbstractFxEscrowMulti.sol";

contract FxEscrowMulti is AbstractFxEscrowMulti {
    constructor(address _escrowConfigAddress) {
        require(_escrowConfigAddress != address(0), "escrow config address cannot be zero");

        config = EscrowConfig(_escrowConfigAddress);
    }
}