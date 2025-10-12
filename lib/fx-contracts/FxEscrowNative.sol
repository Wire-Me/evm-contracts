// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../EscrowStructs.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AuthorizedBrokerWalletManager} from "./AuthorizedBrokerWalletManager.sol";
import {AuthorizedUserWalletManager} from "./AuthorizedUserWalletManager.sol";
import {FxEscrow} from "./FxEscrow.sol";


contract FxEscrowNative is FxEscrow {
    constructor(address _admin, string memory _currency) {
        admin = payable(_admin);
        currency = keccak256(bytes(_currency));
    }

    function transferFundsFromContract(address _to, uint _amount) internal override {
        (bool success,) = payable(_to).call{value: _amount}("");
        require(success, "Transfer failed");
    }
}