// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FxEscrowERC20} from "../fx-escrow/FxEscrowERC20.sol";
import {AdminBase} from "../AdminBase.sol";
import {SmartWallet} from "./SmartWallet.sol";

contract SmartWalletNative is SmartWallet {
    constructor(address _escrowContractAddress, address _admin) {
        require(_escrowContractAddress != address(0), "escrow address cannot be zero");

        admin = _admin;
        escrowContract = FxEscrowERC20(_escrowContractAddress);
    }

    function transferFundsFromContract(address _to, uint _amount) internal override {
        require(address(this).balance >= _amount, "Insufficient balance in contract");

        (bool success,) = payable(_to).call{value: _amount}("");
        require(success, "Transfer failed");
    }

    fallback() external payable {}
}