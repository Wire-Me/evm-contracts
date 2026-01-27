// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "./configuration/WalletConfig.sol";

abstract contract SmartWalletMultiStorage {
    address internal _implementation;
    address internal _admin;
    address internal _authorizedEOA;
    WalletConfig internal _config;

    uint256[50] private __gap;
}