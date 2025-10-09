// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {FxEscrowERC20} from "./FxEscrowERC20.sol";

contract FxEscrowERC20USDC is FxEscrowERC20 {
    constructor(address _erc20TokenAddress, address _admin)
    FxEscrowERC20(_erc20TokenAddress, _admin) {}
}