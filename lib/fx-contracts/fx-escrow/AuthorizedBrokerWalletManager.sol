// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {AdminBase} from "../AdminBase.sol";

abstract contract AuthorizedBrokerWalletManager is AdminBase {
    /// @notice all authorized broker wallets who have been approved to create offers
    mapping(address => bool) public authorizedBrokerWallets;

    modifier onlyAuthorizedBrokers() {
        require(authorizedBrokerWallets[msg.sender], "Sender is not an authorized broker wallet");
        _;
    }

    function addAuthorizedBroker(address broker) external onlyAdmin {
        require(broker != address(0), "Broker address cannot be zero");
        authorizedBrokerWallets[broker] = true;
    }

    function removeAuthorizedBroker(address broker) external onlyAdmin {
        require(broker != address(0), "Broker address cannot be zero");
        authorizedBrokerWallets[broker] = false;
    }
}