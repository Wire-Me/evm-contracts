// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "./configuration/EscrowConfig.sol";
import {AbstractFxEscrowMulti} from "./AbstractFxEscrowMulti.sol";

contract FxEscrowMulti is AbstractFxEscrowMulti {
    constructor(uint256 _brokerDepositAmount, uint256 _expirationDurationForNonBrokers) {
        MINIMUM_BROKER_DEPOSIT_AMOUNT_ERC20 = _brokerDepositAmount;
        EXPIRATION_DURATION_FOR_NON_BROKERS = _expirationDurationForNonBrokers;
    }
}