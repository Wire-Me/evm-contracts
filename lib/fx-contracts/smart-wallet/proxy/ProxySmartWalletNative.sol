// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {ProxySmartWallet} from "./ProxySmartWallet.sol";

contract ProxySmartWalletNative is ProxySmartWallet {
    constructor(address _impl, address _admin, address _authorizedEOA) ProxySmartWallet(_impl, _admin, _authorizedEOA) {}
}