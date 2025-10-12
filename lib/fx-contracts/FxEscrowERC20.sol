// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../EscrowStructs.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {FxEscrow} from "./FxEscrow.sol";


contract FxEscrowERC20 is FxEscrow {
    IERC20 immutable public erc20TokenContract;

    constructor(address _erc20TokenAddress, address _admin, string memory _currency) {
        require(_erc20TokenAddress != address(0), "ERC20 token address cannot be zero");

        // Check if the token implements the decimals() function and that it returns 6 decimals
        try IERC20Metadata(_erc20TokenAddress).decimals() returns (uint8 d) {
            require(d == 6, "Token decimals must be equal to 6");
        } catch {
            revert("Token does not implement decimals()");
        }

        admin = payable(_admin);
        erc20TokenContract = IERC20(_erc20TokenAddress);
        currency = keccak256(bytes(_currency));
    }

    function transferFundsFromContract(address _to, uint _amount) internal override {
        erc20TokenContract.transfer(_to, _amount);
    }
}