// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {ProxySmartWallet} from "./ProxySmartWallet.sol";

contract ProxySmartWalletNative is ProxySmartWallet {
    constructor(address _impl, address _admin) ProxySmartWallet(_impl, _admin) {}
}