// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../FxEscrowMultiStorage.sol";
import "../configuration/EscrowConfig.sol";

contract ProxyFxEscrowMulti is FxEscrowMultiStorage {
    constructor(address _impl, address _admin, address _config) {
        _implementation = _impl;
        _admin = _admin;
        _config = EscrowConfig(_config);
    }

    function setImplementation(address _impl) external {
        require(msg.sender == _admin, "Only admin account can call this function");
        _implementation = _impl;
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