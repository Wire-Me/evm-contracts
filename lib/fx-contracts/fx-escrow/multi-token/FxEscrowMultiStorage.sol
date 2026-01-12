// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../../../EscrowStructs.sol";
import {EscrowConfig} from "./configuration/EscrowConfig.sol";

abstract contract FxEscrowMultiStorage {
    address internal implementation;
    address internal admin;

    mapping(bytes32 => uint) internal platformFeeBalances;
    uint immutable public defaultEscrowDuration = 1 hours; // Default expiration time for escrows

    mapping(address => bool) internal authorizedUserWallets;
    mapping(address => bool) internal authorizedBrokerWallets;

    /// @notice maps the address of the user to their escrows for a given token
    mapping(bytes32 => mapping(address => EscrowStructs.FXEscrow[])) internal escrows;
    /// @notice maps the address of the broker to their offers for a given token
    mapping(bytes32 => mapping(address => EscrowStructs.FXEscrowOffer[])) internal offers;

    EscrowConfig internal config;

    uint256[50] private __gap;
}