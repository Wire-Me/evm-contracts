// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {SmartWalletMultiStorage} from "../SmartWalletMultiStorage.sol";
import "../configuration/WalletConfig.sol";

contract ProxySmartWalletMulti is SmartWalletMultiStorage {
    constructor(address _impl, address _admin, address _walletConfig) {
        _implementation = _impl;
        _admin = _admin;
        _config = WalletConfig(_walletConfig);
    }

    fallback() external payable {
        require(_implementation != address(0), "No implementation");
        address impl = _implementation;

        assembly {
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch success
            case 0 {revert(0, returndatasize())}
            default {return (0, returndatasize())}
        }
    }

    receive() external payable {}
}