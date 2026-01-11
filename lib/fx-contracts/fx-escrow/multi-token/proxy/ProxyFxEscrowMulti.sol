// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../FxEscrowMultiStorage.sol";

contract ProxyFxEscrowMulti is FxEscrowMultiStorage {
    constructor(address _impl, address _admin) {
        implementation = _impl;
        admin = _admin;
    }

    function setImplementation(address _impl) external {
        require(msg.sender == admin, "Only admin account can call this function");
        implementation = _impl;
    }

    fallback() external payable {
        require(implementation != address(0), "No implementation");
        address impl = implementation;

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