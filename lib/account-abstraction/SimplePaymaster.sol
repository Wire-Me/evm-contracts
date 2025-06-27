// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./UserOperation.sol";
import "./IEntryPoint.sol";

contract SimplePaymaster {
    address public immutable owner;
    IEntryPoint public immutable entryPoint;

    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
        owner = msg.sender;
    }

    function validatePaymasterUserOp(
        UserOperationLib.UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData) {
        require(msg.sender == address(entryPoint), "Only EntryPoint");
        // Accept everything for now
        return ("", 0); // context, validationData = 0 (valid)
    }

    function postOp(
        uint8 mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external {
        require(msg.sender == address(entryPoint), "Only EntryPoint");
        // optionally reimburse self here
    }

    // Deposit ETH so EntryPoint can draw gas fees
    receive() external payable {}
}
