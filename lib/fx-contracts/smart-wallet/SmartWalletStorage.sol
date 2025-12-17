// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

abstract contract SmartWalletStorage {
    address public implementation;
    address public admin;
    address public authorizedEOA;
}