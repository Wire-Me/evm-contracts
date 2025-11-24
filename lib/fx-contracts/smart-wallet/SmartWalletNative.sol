// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AdminBase} from "../AdminBase.sol";
import {SmartWallet} from "./SmartWallet.sol";
import {FxEscrowNative} from "../fx-escrow/FxEscrowNative.sol";
import {FxEscrow} from "../fx-escrow/FxEscrow.sol";

contract SmartWalletNative is SmartWallet {
    FxEscrowNative immutable public _escrowContract;

    event TransferSuccessful(address indexed from, address indexed to, uint amount);

    constructor(address payable _escrowContractAddress, address _admin) {
        require(_escrowContractAddress != address(0), "escrow address cannot be zero");

        admin = _admin;
        _escrowContract = FxEscrowNative(_escrowContractAddress);
    }

    function transferFundsFromContract(address _to, uint _amount) internal override {
        require(address(this).balance >= _amount, "Insufficient balance in contract");

        (bool success,) = payable(_to).call{value: _amount}("");
        require(success, "Transfer failed");

        emit TransferSuccessful(address(this), _to, _amount);
    }

    // override the getter
    function escrowContract() public view override returns (FxEscrow) {
        return _escrowContract;
    }

    // Allow the proxy contract to receive native currency
    fallback() external payable {}

    // Do not allow direct sends to the contract
    receive() payable external {
        revert("Direct deposits not allowed");
    }
}