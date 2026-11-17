// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "./configuration/WalletConfig.sol";

/// @custom:deprecated Deprecated along with the rest of the smart-wallet layer in favor of
/// Openfort embedded wallets. Still in active production use via ProxySmartWalletMulti /
/// SmartWalletMulti; see AbstractSmartWalletMulti.sol for removal criteria.
abstract contract SmartWalletMultiStorage {
    address internal _implementation;
    address internal _admin;
    address internal _authorizedEOA;
    WalletConfig internal _config;

    uint256[50] private __gap;
}