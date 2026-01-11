// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "./configuration/WalletConfig.sol";

abstract contract SmartWalletMultiStorage {
    address public implementation;
    address public admin;
    address public authorizedEOA;
    WalletConfig public config;
    bytes32 immutable public nativeToken = keccak256("NATIVE");
}