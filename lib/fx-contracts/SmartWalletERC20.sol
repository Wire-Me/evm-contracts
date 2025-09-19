// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FxEscrowERC20} from "./FxEscrowERC20.sol";
import {AdminBase} from "./AdminBase.sol";


abstract contract SmartWalletERC20 is AdminBase {
    IERC20 immutable public erc20TokenContract;
    FxEscrowERC20 immutable public escrowContract;

    constructor(address _escrowContractAddress, address _admin) {
        require(_escrowContractAddress != address(0), "escrow address cannot be zero");

        admin = payable(_admin);
        escrowContract = FxEscrowERC20(_escrowContractAddress);
        erc20TokenContract = escrowContract.erc20TokenContract();

        // Make sure the escrow contract address specified corresponds to a valid FxEscrowERC20 contract
//        try escrowContract.isFxEscrowContractTest() returns (bool isInitialized) {
//            require(isInitialized, "escrow contract address specified does not correctly implement the isFxEscrowContractTest function");
//        } catch {
//            revert("escrow contract does not implement required interface");
//        }
    }

//    modifier onlyAdminOrAuthorizedUser() {
//        require(msg.sender == admin || msg.sender == authorizedUserExternalAccount, "Only admin or authorized user account can call this function");
//        _;
//    }

//    function setAuthorizedUserExternalAccount(address payable _newExternalAccount) external onlyAdmin {
//        require(_newExternalAccount != address(0), "New external account cannot be zero address");
//        authorizedUserExternalAccount = _newExternalAccount;
//    }
}