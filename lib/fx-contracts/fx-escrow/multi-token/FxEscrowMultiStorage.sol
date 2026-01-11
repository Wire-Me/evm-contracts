// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../../../EscrowStructs.sol";
import {EscrowConfig} from "./configuration/EscrowConfig.sol";

abstract contract FxEscrowMultiStorage {
    address public implementation;
    address public admin;

    bytes32 immutable public nativeToken = keccak256("NATIVE");

    mapping(bytes32 => uint) public platformFeeBalances;
    uint immutable public defaultEscrowDuration = 1 hours; // Default expiration time for escrows

    mapping(address => bool) public authorizedUserWallets;
    mapping(address => bool) public authorizedBrokerWallets;

    /// @notice maps the address of the user to their escrows for a given token
    mapping(bytes32 => mapping(address => EscrowStructs.FXEscrow[])) public escrows;
    /// @notice maps the address of the broker to their offers for a given token
    mapping(bytes32 => mapping(address => EscrowStructs.FXEscrowOffer[])) public offers;

    EscrowConfig public config;
}