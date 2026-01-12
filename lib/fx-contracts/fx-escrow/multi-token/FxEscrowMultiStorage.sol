// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../../../EscrowStructs.sol";
import {EscrowConfig} from "./configuration/EscrowConfig.sol";

abstract contract FxEscrowMultiStorage {
    address internal _implementation;
    address internal _admin;

    mapping(bytes32 => uint) internal _platformFeeBalances;
    uint immutable public defaultEscrowDuration = 1 hours; // Default expiration time for escrows

    mapping(address => bool) internal _authorizedUserWallets;
    mapping(address => bool) internal _authorizedBrokerWallets;

    /// @notice maps the address of the user to their escrows for a given token
    mapping(bytes32 => mapping(address => EscrowStructs.FXEscrow[])) internal _escrows;
    /// @notice maps the address of the broker to their offers for a given token
    mapping(bytes32 => mapping(address => EscrowStructs.FXEscrowOffer[])) internal _offers;

    EscrowConfig internal _config;

    uint256[50] private __gap;
}