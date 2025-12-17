// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FxEscrowERC20} from "../fx-escrow/FxEscrowERC20.sol";
import {FxEscrow} from "../fx-escrow/FxEscrow.sol";
import {AdminBase} from "../AdminBase.sol";
import {SmartWallet} from "./SmartWallet.sol";

abstract contract SmartWalletERC20 is SmartWallet {
    IERC20 immutable public erc20TokenContract;
    FxEscrowERC20 immutable public _escrowContract;

    constructor(address payable _escrowContractAddress) {
        require(_escrowContractAddress != address(0), "escrow address cannot be zero");

        _escrowContract = FxEscrowERC20(_escrowContractAddress);
        erc20TokenContract = _escrowContract.erc20TokenContract();
    }

    function transferFundsFromContract(address _to, uint _amount) internal override {
        erc20TokenContract.transfer(_to, _amount);
    }

    // override the getter
    function escrowContract() public view override returns (FxEscrow) {
        return _escrowContract;
    }

    // Do not allow direct sends to the proxy contract
    fallback() external {}

    // Do not allow direct sends to the contract
    receive() payable external {
        revert("Direct deposits not allowed");
    }
}