// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

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

    // Allow the proxy contract to receive native currency
    fallback() external payable {}

    // Do not allow direct sends to the contract
    receive() payable external {
        revert("Direct deposits not allowed");
    }
}