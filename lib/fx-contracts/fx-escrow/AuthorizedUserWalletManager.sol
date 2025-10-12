// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {AdminBase} from "../AdminBase.sol";

abstract contract AuthorizedUserWalletManager is AdminBase {
    /// @notice all authorized user wallets who have been approved to create escrows
    mapping(address => bool) public authorizedUserWallets;

    modifier onlyAuthorizedUsers() {
        require(authorizedUserWallets[msg.sender], "Sender is not an authorized user wallet");
        _;
    }

    function addAuthorizedUser(address user) external onlyAdmin {
        require(user != address(0), "User address cannot be zero");
        authorizedUserWallets[user] = true;
    }

    function removeAuthorizedUser(address user) external onlyAdmin {
        require(user != address(0), "User address cannot be zero");
        authorizedUserWallets[user] = false;
    }
}