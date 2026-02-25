// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../../EscrowStructs.sol";
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

    mapping(address => EscrowStructs.BrokerDeposit) internal _brokerDeposits;

    mapping(address => uint256[]) internal _ongoingBrokerOffers;
    mapping(address => mapping(uint256 => uint256)) internal _ongoingBrokerOffersIndex;

    uint8 public MAX_ONGOING_BROKER_OFFERS = 3;
    uint8 public MAX_OFFERS_PER_ESCROW = 5;

    uint256 public MINIMUM_BROKER_DEPOSIT_AMOUNT_ERC20 = 500 * 10**6; // 500 units of the token with 6 decimals

    uint256 public EXPIRATION_DURATION_FOR_NON_BROKERS = 48 hours;

    uint256[44] private __gap;
}