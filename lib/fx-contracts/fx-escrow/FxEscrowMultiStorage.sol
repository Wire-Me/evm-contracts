// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../../EscrowStructs.sol";
import {EscrowConfig} from "./configuration/EscrowConfig.sol";

abstract contract FxEscrowMultiStorage {
    address internal _implementation;
    address internal _admin;

    mapping(bytes32 => uint) internal _platformFeeBalances;
    uint constant public defaultEscrowDuration = 1 hours; // Default expiration time for escrows

    mapping(address => bool) internal _authorizedUserWallets;
    mapping(address => bool) internal _authorizedBrokerWallets;

    /// @notice maps the address of the user to their escrows for a given token
    mapping(bytes32 => mapping(address => EscrowStructs.FXEscrow[])) internal _escrows;
    /// @notice maps the address of the broker to their offers for a given token
    mapping(bytes32 => mapping(address => EscrowStructs.FXEscrowOffer[])) internal _offers;

    EscrowConfig internal _config;

    mapping(address => EscrowStructs.BrokerDeposit) internal _brokerDeposits;

    /// @notice maps the address of the broker to an array of offer indexes
    /// These indexes correspond to the offers in _offers that the broker has made for escrows that are still ongoing
    mapping(address => uint256[]) internal _ongoingBrokerOffers;
    /// @notice maps the address of the broker to a mapping which maps the offer index (value in _ongoingBrokerOffers) to the index of it in the _ongoingBrokerOffers array
    /// This allows for efficient removal of offers from the _ongoingBrokerOffers array when an offer is no longer ongoing
    mapping(address => mapping(uint256 => uint256)) internal _ongoingBrokerOffersIndex;

    uint8 public MAX_ONGOING_BROKER_OFFERS = 3;
    uint8 public MAX_OFFERS_PER_ESCROW = 5;

    uint256 public MINIMUM_BROKER_DEPOSIT_AMOUNT_ERC20 = 500 * 10**6; // 500 units of the token with 6 decimals

    uint256 public EXPIRATION_DURATION_FOR_NON_BROKERS = 48 hours;

    mapping(address => bool) internal _frozenBrokerDeposits;

    /// @notice maps the address of the broker to a mapping which maps the offer to the hash of the token the offer is on
    mapping(address => mapping(uint256 => bytes32)) internal _ongoingBrokerOffersToken;

    uint256[42] private __gap;
}