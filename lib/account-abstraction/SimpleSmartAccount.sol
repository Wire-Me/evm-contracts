// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IAccount.sol";
import "./IEntryPoint.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SimpleSmartAccount is IAccount {
    using MessageHashUtils for bytes32;

    address public immutable owner;
    IEntryPoint public immutable entryPoint;

    constructor(address _owner, IEntryPoint _entryPoint) {
        owner = _owner;
        entryPoint = _entryPoint;
    }

    /// @notice Required by ERC-4337
    function validateUserOp(
        UserOperationLib.UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 /*missingFunds*/
    ) external override returns (uint256) {
        require(msg.sender == address(entryPoint), "Not EntryPoint");
        address recovered = ECDSA.recover(userOpHash.toEthSignedMessageHash(), userOp.signature);
        require(recovered == owner, "Invalid signature");
        return 0; // validation successful
    }

    /// @notice Called by EntryPoint to execute user operation
    function execute(address to, uint256 value, bytes calldata data) external {
        require(msg.sender == address(entryPoint), "Only EntryPoint can execute");
        (bool success, ) = to.call{value: value}(data);
        require(success, "Call failed");
    }

    /// @notice Allow receiving ETH
    receive() external payable {}
}
