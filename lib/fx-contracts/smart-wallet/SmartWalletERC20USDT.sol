// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {SmartWalletERC20} from "./SmartWalletERC20.sol";

contract SmartWalletERC20USDT is SmartWalletERC20 {
    constructor(address payable _escrowContractAddress, address _admin)
    SmartWalletERC20(_escrowContractAddress, _admin) {}
}