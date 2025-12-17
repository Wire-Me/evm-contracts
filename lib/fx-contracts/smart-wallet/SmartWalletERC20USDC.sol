// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {SmartWalletERC20} from "./SmartWalletERC20.sol";

contract SmartWalletERC20USDC is SmartWalletERC20 {
    constructor(address payable _escrowContractAddress)
    SmartWalletERC20(_escrowContractAddress) {}
}