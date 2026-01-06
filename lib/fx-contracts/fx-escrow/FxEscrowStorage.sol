// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../../EscrowStructs.sol";

abstract contract FxEscrowStorage {
    address public implementation;
    address public admin;

    uint public platformFeeBalance;
    uint immutable public defaultEscrowDuration = 1 hours; // Default expiration time for escrows
    bytes32 immutable public currency;

    mapping(address => bool) public authorizedUserWallets;
    mapping(address => bool) public authorizedBrokerWallets;

    /// @notice maps the address of the user to their escrows
    mapping(address => EscrowStructs.FXEscrow[]) public escrows;
    /// @notice maps the address of the broker to their offers
    mapping(address => EscrowStructs.FXEscrowOffer[]) public offers;
}