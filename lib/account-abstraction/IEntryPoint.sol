// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./UserOperation.sol";

interface IEntryPoint {
    /**
     * @notice Called by bundlers to handle user operations.
     */
    function handleOps(UserOperationLib.UserOperation[] calldata ops, address payable beneficiary) external;

    /**
     * @notice Returns the hash to be signed by the user.
     * Used off-chain to prepare the signature.
     */
    function getUserOpHash(UserOperationLib.UserOperation calldata userOp) external view returns (bytes32);
}
