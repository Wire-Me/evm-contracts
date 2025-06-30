// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

contract SwapEscrow {
    struct Escrow {
        /// @notice the address of the buyer's account
        address sender;
        /// @notice the address of the seller's account
        address receiver;
        /// @notice 'true' if initialized
        bool initialized;
        /// @notice the amount of funds required to be deposited by the payer
        uint requiredBalance;
        /// @notice 'true' if the relay is returning (the payer can withdraw funds)
        bool isReturning;
        /// @notice 'true' if the relay is approved (the payee can withdraw funds)
        bool isApproved;
    }

    mapping(address => Escrow[]) public escrows;

    address payable public owner; // The account which deployed this contract

    event EscrowCreated(address indexed _creator, uint indexed _agreementIndex);

    // Example constructor
    constructor() {
        owner = payable(msg.sender);
    }

    function checkEscrowActors(address _creator, uint _index) external view returns (address, address, bool) {
        Escrow storage escrow = escrows[_creator][_index];
        return (escrow.sender, escrow.receiver, escrow.initialized);
    }

    // Revert any plain ETH transfer (no calldata)
    receive() external payable {
        escrows[msg.sender].push(
            Escrow({
                sender: msg.sender,
                receiver: address(0),
                initialized: true,
                requiredBalance: msg.value,
                isReturning: false,
                isApproved: false
            })
        );

        emit EscrowCreated(msg.sender, escrows[msg.sender].length - 1);
    }

    // Revert any ETH sent with calldata
    fallback() external payable {
        revert("Fallback function called. ETH not accepted");
    }
}