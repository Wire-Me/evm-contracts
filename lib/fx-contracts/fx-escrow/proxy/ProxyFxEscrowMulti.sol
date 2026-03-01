// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../FxEscrowMultiStorage.sol";
import "../configuration/EscrowConfig.sol";

contract ProxyFxEscrowMulti is FxEscrowMultiStorage {
    constructor(address _implementationAddress, address _adminAddress, address _escrowConfigAddress) {
        _implementation = _implementationAddress;
        _admin = _adminAddress;
        _config = EscrowConfig(_escrowConfigAddress);
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