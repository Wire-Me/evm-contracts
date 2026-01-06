// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {SmartWalletMultiStorage} from "../SmartWalletMultiStorage.sol";

abstract contract ProxySmartWalletMulti is SmartWalletMultiStorage {
    constructor(address _impl, address _admin, address _authorizedEOA) {
        implementation = _impl;
        admin = _admin;
        authorizedEOA = _authorizedEOA;
    }

    function setImplementation(address _impl) external {
        require(msg.sender == admin, "Only admin account can call this function");
        implementation = _impl;
    }

    function setAuthorizedEOA(address _eoa) external {
        require(msg.sender == admin, "Only admin account can call this function");
        authorizedEOA = _eoa;
    }

    fallback() external payable {
        require(implementation != address(0), "No implementation");
        address impl = implementation;

        assembly {
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch success
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}