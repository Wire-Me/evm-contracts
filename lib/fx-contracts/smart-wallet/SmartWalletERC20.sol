// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FxEscrowERC20} from "../fx-escrow/FxEscrowERC20.sol";
import {AdminBase} from "../AdminBase.sol";
import {SmartWallet} from "./SmartWallet.sol";

abstract contract SmartWalletERC20 is SmartWallet {
    IERC20 immutable public erc20TokenContract;

    constructor(address _escrowContractAddress, address _admin) {
        require(_escrowContractAddress != address(0), "escrow address cannot be zero");

        admin = _admin;
        escrowContract = FxEscrowERC20(_escrowContractAddress);
        erc20TokenContract = escrowContract.erc20TokenContract();
    }

    function transferFundsFromContract(address _to, uint _amount) internal override {
        erc20TokenContract.transfer(_to, _amount);
    }

    fallback() external {}
}