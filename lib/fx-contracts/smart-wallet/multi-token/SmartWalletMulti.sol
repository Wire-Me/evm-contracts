// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AbstractSmartWalletMulti} from "./AbstractSmartWalletMulti.sol";
import {FxEscrow} from "../../fx-escrow/FxEscrow.sol";
import {WalletConfig} from "./configuration/WalletConfig.sol";

contract SmartWalletMulti is AbstractSmartWalletMulti {
    event TransferSuccessful(address indexed from, address indexed to, uint amount);

    constructor(address _walletConfigAddress) {
        require(_walletConfigAddress != address(0), "wallet config address cannot be zero");

        config = WalletConfig(_walletConfigAddress);
    }

    function transferFundsFromWallet(bytes32 _token, address _to, uint _amount) internal override {
        if (_token == keccak256("NATIVE")) {
            require(address(this).balance >= _amount, "Insufficient balance in contract");

            (bool success,) = payable(_to).call{value: _amount}("");
            require(success, "Transfer failed");

            emit TransferSuccessful(address(this), _to, _amount);
        } else {
            IERC20 erc20TokenContract = IERC20(config.erc20TokenContracts(_token));
            erc20TokenContract.transfer(_to, _amount);
        }
    }

    // override the getter
    function escrowContract(bytes32 _token) public view override returns (FxEscrow) {
        return FxEscrow(config.fxEscrowContracts(_token));
    }

    // Allow the proxy contract to receive native currency
    fallback() external payable {}

    // Do not allow direct sends to the contract
    receive() payable external {
        revert("Direct deposits not allowed");
    }
}