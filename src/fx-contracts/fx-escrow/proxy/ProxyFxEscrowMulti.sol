// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../FxEscrowMultiStorage.sol";
import "../configuration/EscrowConfig.sol";

contract ProxyFxEscrowMulti is FxEscrowMultiStorage {
    constructor(address _implementationAddress, address _adminAddress, address _escrowConfigAddress, uint256 _brokerDepositAmount, uint256 _expirationDurationForNonBrokers) {
        _implementation = _implementationAddress;
        _admin = _adminAddress;
        _config = EscrowConfig(_escrowConfigAddress);
        MINIMUM_BROKER_DEPOSIT_AMOUNT_ERC20 = _brokerDepositAmount;
        EXPIRATION_DURATION_FOR_NON_BROKERS = _expirationDurationForNonBrokers;
    }

    function getImplementation() external view returns (address) {
        return _implementation;
    }

    function setImplementation(address _impl) external {
        require(msg.sender == _admin, "Sender is not an authorized admin account");
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