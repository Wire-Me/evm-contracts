// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../fx-escrow/FxEscrowMulti.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AbstractSmartWalletMulti} from "./AbstractSmartWalletMulti.sol";
import {WalletConfig} from "./configuration/WalletConfig.sol";

contract SmartWalletMulti is AbstractSmartWalletMulti {
    bytes32 internal constant NATIVE_TOKEN = keccak256("NATIVE");

    event TransferSuccessful(address indexed from, address indexed to, uint amount);

    constructor() {}

    function transferFundsFromWallet(bytes32 _token, address _to, uint _amount) internal override {
        if (_token == NATIVE_TOKEN) {
            require(address(this).balance >= _amount, "Insufficient balance in contract");

            (bool success,) = payable(_to).call{value: _amount}("");
            require(success, "Transfer failed");

            emit TransferSuccessful(address(this), _to, _amount);
        } else {
            IERC20 erc20TokenContract = IERC20(_config.erc20TokenContracts(_token));
            erc20TokenContract.transfer(_to, _amount);
        }
    }

    // override the getter
    function escrowContract() public view override returns (FxEscrowMulti) {
        return FxEscrowMulti(_config.fxEscrowMultiContract());
    }

    // Allow the proxy contract to receive native currency
    fallback() external payable {}

    // Do not allow direct sends to the contract
    receive() payable external {
        revert("Direct deposits not allowed");
    }
}