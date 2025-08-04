// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "./EscrowStructs.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AuthorizedBrokerWalletManager} from "./AuthorizedBrokerWalletManager.sol";
import {AuthorizedUserWalletManager} from "./AuthorizedUserWalletManager.sol";


contract FxEscrowERC20 is AuthorizedBrokerWalletManager, AuthorizedUserWalletManager {
    uint public basisPointFee; // The fee for using this contract in basis points (1 basis point = 0.01%, 100 basis points = 1%, 10000 basis points = 100%)
    IERC20 immutable public erc20TokenContract;

    uint public defaultEscrowDuration = 1 hours; // Default expiration time for escrows

    /// @notice maps the address of the user to their escrows
    mapping(address => EscrowStructs.FXEscrow[]) public escrows;
    /// @notice maps the address of the broker to their offers
    mapping(address => EscrowStructs.FXEscrowOffer[]) public offers;

    constructor(uint _basisPointFee, address _erc20TokenAddress) {
        require(_basisPointFee <= 10000, "TransactionRelay: basis point fee must be less than or equal to 10000 (100%)");
        require(_erc20TokenAddress != address(0), "ERC20 token address cannot be zero");

        // Check if the token implements the decimals() function and that it returns 6 decimals
        try IERC20Metadata(_erc20TokenAddress).decimals() returns (uint8 d) {
            require(d == 6, "Token decimals must be equal to 6");
        } catch {
            revert("Token does not implement decimals()");
        }

        admin = payable(msg.sender);
        basisPointFee = _basisPointFee;
        erc20TokenContract = IERC20(_erc20TokenAddress);
    }

    function createEscrow(uint amount) external onlyAuthorizedUsers {
        escrows[msg.sender].push(
            EscrowStructs.FXEscrow({
                amount: amount,
                createdAt: block.timestamp,
                expirationTimestamp: block.timestamp + defaultEscrowDuration,
                isWithdrawn: false,
                isFrozen: false,
                isReturned: false,
                selectedBrokerAccount: address(0),
                selectedOfferIndex: 0
            })
        );
    }

    function createOffer(
        address escrowAccount,
        uint escrowIndex
    ) external onlyAuthorizedBrokers {
        EscrowStructs.FXEscrow storage escrow = escrows[escrowAccount][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(escrow.selectedBrokerAccount == address(0), "Escrow already has selected an offer");

        offers[msg.sender].push(
            EscrowStructs.FXEscrowOffer({
                escrowAccount: escrowAccount,
                escrowIndex: escrowIndex,
                createdAt: block.timestamp
            })
        );
    }

    function linkOfferToEscrow(
        uint _escrowIndex,
        address _offerAccount,
        uint _offerIndex
    ) external onlyAuthorizedUsers {
        EscrowStructs.FXEscrow storage escrow = escrows[msg.sender][_escrowIndex];
        EscrowStructs.FXEscrowOffer storage offer = offers[_offerAccount][_offerIndex];

        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(offer.createdAt > 0, "Offer is not initialized");

        escrow.selectedBrokerAccount = _offerAccount;
        escrow.selectedOfferIndex = _offerIndex;
    }

    function freezeEscrow(address escrowAccount, uint escrowIndex) external onlyAdmin {
        EscrowStructs.FXEscrow storage escrow = escrows[escrowAccount][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isFrozen, "Escrow is already frozen");

        escrow.isFrozen = true;
    }

    function defrostEscrow(address escrowAccount, uint escrowIndex) external onlyAdmin {
        EscrowStructs.FXEscrow storage escrow = escrows[escrowAccount][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(escrow.isFrozen, "Escrow is not frozen");

        escrow.isFrozen = false;
    }

    function returnEscrow(address escrowAccount, uint escrowIndex) external onlyAdmin {
        EscrowStructs.FXEscrow storage escrow = escrows[escrowAccount][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isWithdrawn, "Escrow is already withdrawn");

        escrow.isReturned = true;
        escrow.isFrozen = false; // Unfreeze the escrow if it was frozen
    }

    function extendEscrow(uint escrowIndex) external onlyAuthorizedUsers {
        EscrowStructs.FXEscrow storage escrow = escrows[msg.sender][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(escrow.selectedBrokerAccount == address(0), "Escrow has already selected an offer");

        // Extend the escrow expiration by the default duration
        escrow.expirationTimestamp += (block.timestamp + defaultEscrowDuration);
    }

    function withdrawEscrowAfterCompletion(address escrowAccount, uint escrowIndex) external onlyAuthorizedBrokers {
        EscrowStructs.FXEscrow storage escrow = escrows[escrowAccount][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isWithdrawn, "Escrow is already withdrawn");
        require(!escrow.isFrozen, "Escrow is frozen and cannot be withdrawn");
        require(escrow.selectedBrokerAccount == msg.sender, "Only the selected broker can withdraw from the escrow");
        require(block.timestamp >= escrow.expirationTimestamp, "Escrow has not yet expired");

        escrow.isWithdrawn = true;

        // Transfer the escrow amount to the broker
        erc20TokenContract.transfer(msg.sender, escrow.amount);
    }

    function withdrawEscrowEarly(uint escrowIndex) external onlyAuthorizedUsers {
        EscrowStructs.FXEscrow storage escrow = escrows[msg.sender][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isWithdrawn, "Escrow is already withdrawn");
        require(escrow.selectedBrokerAccount == address(0), "Escrow has already selected an offer");

        escrow.isWithdrawn = true;

        // Transfer the escrow amount back to the user
        erc20TokenContract.transfer(msg.sender, escrow.amount);
    }

    function withdrawEscrowAfterReturn(uint escrowIndex) external onlyAuthorizedUsers {
        EscrowStructs.FXEscrow storage escrow = escrows[msg.sender][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isWithdrawn, "Escrow is already withdrawn");
        require(escrow.isReturned, "Escrow has not been returned");

        escrow.isWithdrawn = true;

        // Transfer the escrow amount back to the user
        erc20TokenContract.transfer(msg.sender, escrow.amount);
    }

    function isFxEscrowContractTest() external pure returns (bool) {
        return true; // This contract is a FxEscrowERC20 contract
    }
}