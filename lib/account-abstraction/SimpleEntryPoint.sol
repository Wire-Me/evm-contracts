// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IAccount.sol";
import "./UserOperation.sol";

contract SimpleEntryPoint {
    event UserOperationExecuted(address indexed sender, bool success);

    mapping(address => uint256) public nonces;

    function handleOps(UserOperationLib.UserOperation[] calldata ops) external {
        for (uint256 i = 0; i < ops.length; i++) {
            UserOperationLib.UserOperation calldata op = ops[i];
            bytes32 userOpHash = getUserOpHash(op);

            // call validateUserOp on sender account
            (bool ok, bytes memory ret) = op.sender.call(
                abi.encodeWithSelector(
                    IAccount.validateUserOp.selector,
                    op,
                    userOpHash,
                    0
                )
            );
            require(ok, "validateUserOp failed");

            require(op.nonce == nonces[op.sender], "Invalid nonce");
            nonces[op.sender]++;

            // execute the call
            (ok, ) = op.sender.call(op.callData);
            emit UserOperationExecuted(op.sender, ok);
        }
    }

    function getUserOpHash(UserOperationLib.UserOperation calldata userOp) public pure returns (bytes32) {
        return keccak256(abi.encode(
            userOp.sender,
            userOp.nonce,
            keccak256(userOp.initCode),
            keccak256(userOp.callData),
            userOp.callGasLimit,
            userOp.verificationGasLimit,
            userOp.preVerificationGas,
            userOp.maxFeePerGas,
            userOp.maxPriorityFeePerGas,
            keccak256(userOp.paymasterAndData),
            keccak256(userOp.signature)
        ));
    }
}
