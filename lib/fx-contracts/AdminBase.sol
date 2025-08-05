// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

abstract contract AdminBase {
    address payable immutable public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Sender is not an authorized admin account");
        _;
    }
}