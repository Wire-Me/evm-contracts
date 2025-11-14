// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../../EscrowStructs.sol";
import {AuthorizedBrokerWalletManager} from "./AuthorizedBrokerWalletManager.sol";
import {AuthorizedUserWalletManager} from "./AuthorizedUserWalletManager.sol";

abstract contract FxEscrow is AuthorizedBrokerWalletManager, AuthorizedUserWalletManager {
    uint public platformFeeBalance;
    uint immutable public defaultEscrowDuration = 1 hours; // Default expiration time for escrows
    bytes32 immutable public currency;

    /// @notice maps the address of the user to their escrows
    mapping(address => EscrowStructs.FXEscrow[]) public escrows;
    /// @notice maps the address of the broker to their offers
    mapping(address => EscrowStructs.FXEscrowOffer[]) public offers;

    function transferFundsFromContract(address _to, uint _amount) internal virtual;

    event EscrowCreated(
        address indexed _creatingUser,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        uint _expirationTimestamp,
        uint _amount
    );

    event OfferCreated(
        address indexed _creatingBroker,
        uint indexed _offerIndex,
        bytes32 indexed _currency,
        address _escrowUser,
        uint _escrowIndex
    );

    event EscrowSelectedOffer(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        address _creatorOfOffer,
        uint _offerIndex
    );

    event EscrowFrozen(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency
    );

    event EscrowDefrosted(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency
    );

    event EscrowFundsReturnedToUser(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency
    );

    event EscrowExpirationExtended(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        uint _newExpirationTimestamp
    );

    event EscrowWithdrawnAfterCompletion(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        address _withdrawnTo,
        uint _amountWithdrawn
    );

    event EscrowWithdrawnEarly(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        address _withdrawnTo,
        uint _amountWithdrawn
    );

    event EscrowWithdrawnAfterReturn(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        address _withdrawnTo,
        uint _amountWithdrawn
    );

    function createEscrow(uint _amount) external onlyAuthorizedUsers {
        uint expiration = block.timestamp + defaultEscrowDuration;

        escrows[msg.sender].push(
            EscrowStructs.FXEscrow({
                amount: _amount,
                createdAt: block.timestamp,
                expirationTimestamp: expiration,
                isWithdrawn: false,
                isFrozen: false,
                isReturned: false,
                selectedBrokerAccount: address(0),
                selectedOfferIndex: 0
            })
        );

        emit EscrowCreated(msg.sender, escrows[msg.sender].length - 1, currency, expiration, _amount);
    }

    function createOffer(
        address _escrowAccount,
        uint _escrowIndex,
        uint _feeBasisPoints
    ) external onlyAuthorizedBrokers {
        EscrowStructs.FXEscrow storage escrow = escrows[_escrowAccount][_escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(escrow.selectedBrokerAccount == address(0), "Escrow already has selected an offer");

        offers[msg.sender].push(
            EscrowStructs.FXEscrowOffer({
                escrowAccount: _escrowAccount,
                escrowIndex: _escrowIndex,
                feeBasisPoints: _feeBasisPoints,
                createdAt: block.timestamp
            })
        );

        emit OfferCreated(msg.sender, offers[msg.sender].length - 1, currency, _escrowAccount, _escrowIndex);
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

        // Defrost the escrow if it is frozen
        if (escrow.isFrozen) {
            escrow.isFrozen = false;
            emit EscrowDefrosted(msg.sender, _escrowIndex, currency);
        }

        // Extend the escrow expiration if it is past half of its duration
        if (block.timestamp > (escrow.expirationTimestamp - (defaultEscrowDuration / 2))) {
            uint newExpirationTimestamp = block.timestamp + defaultEscrowDuration;
            escrow.expirationTimestamp = newExpirationTimestamp;
            emit EscrowExpirationExtended(msg.sender, _escrowIndex, currency, newExpirationTimestamp);
        }

        escrow.selectedBrokerAccount = _offerAccount;
        escrow.selectedOfferIndex = _offerIndex;

        emit EscrowSelectedOffer(msg.sender, _escrowIndex, currency, _offerAccount, _offerIndex);
    }

    function freezeEscrow(address _escrowAccount, uint _escrowIndex) external onlyAdmin {
        EscrowStructs.FXEscrow storage escrow = escrows[_escrowAccount][_escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isFrozen, "Escrow is already frozen");

        escrow.isFrozen = true;

        emit EscrowFrozen(_escrowAccount, _escrowIndex, currency);
    }

    function defrostEscrow(address _escrowAccount, uint _escrowIndex) public onlyAdmin {
        EscrowStructs.FXEscrow storage escrow = escrows[_escrowAccount][_escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(escrow.isFrozen, "Escrow is not frozen");

        escrow.isFrozen = false;

        emit EscrowDefrosted(_escrowAccount, _escrowIndex, currency);
    }

    function returnEscrow(address _escrowAccount, uint _escrowIndex) external onlyAdmin {
        EscrowStructs.FXEscrow storage escrow = escrows[_escrowAccount][_escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isWithdrawn, "Escrow is already withdrawn");

        escrow.isReturned = true;
        escrow.isFrozen = false; // Unfreeze the escrow if it was frozen (most of the time it will be so no `if` check to save gas)

        emit EscrowFundsReturnedToUser(_escrowAccount, _escrowIndex, currency);
    }

    function extendEscrow(uint _escrowIndex) public onlyAuthorizedUsers {
        EscrowStructs.FXEscrow storage escrow = escrows[msg.sender][_escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(escrow.selectedBrokerAccount == address(0), "Escrow has already selected an offer");

        // Extend the escrow expiration by the default duration
        uint newExpirationTimestamp = block.timestamp + defaultEscrowDuration;
        escrow.expirationTimestamp = newExpirationTimestamp;

        emit EscrowExpirationExtended(msg.sender, _escrowIndex, currency, newExpirationTimestamp);
    }

    function withdrawEscrowAfterCompletion(address escrowAccount, uint escrowIndex) external onlyAuthorizedBrokers {
        EscrowStructs.FXEscrow storage escrow = escrows[escrowAccount][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isWithdrawn, "Escrow is already withdrawn");
        require(!escrow.isFrozen, "Escrow is frozen and cannot be withdrawn by the broker");
        require(!escrow.isReturned, "Escrow is returned and cannot be withdrawn by the broker");
        require(escrow.selectedBrokerAccount == msg.sender, "Only the selected broker can withdraw from the escrow");
        require(block.timestamp >= escrow.expirationTimestamp, "Escrow has not yet expired");

        EscrowStructs.FXEscrowOffer storage selectedOffer = offers[escrow.selectedBrokerAccount][escrow.selectedOfferIndex];

        uint platformFee = _calcBasisPointShare(escrow.amount, selectedOffer.feeBasisPoints);
        uint amountWithdrawn = escrow.amount - platformFee;

        escrow.isWithdrawn = true;

        // Transfer the escrow amount to the broker
        transferFundsFromContract(msg.sender, amountWithdrawn);
        // Add the platform fee to the contract's balance
        platformFeeBalance += platformFee;

        emit EscrowWithdrawnAfterCompletion(escrowAccount, escrowIndex, currency, msg.sender, amountWithdrawn);
    }

    function withdrawEscrowEarly(uint escrowIndex) external onlyAuthorizedUsers {
        EscrowStructs.FXEscrow storage escrow = escrows[msg.sender][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isWithdrawn, "Escrow is already withdrawn");
        require(escrow.selectedBrokerAccount == address(0), "Escrow has already selected an offer");

        escrow.isWithdrawn = true;

        // Transfer the escrow amount back to the user
        transferFundsFromContract(msg.sender, escrow.amount);

        emit EscrowWithdrawnEarly(msg.sender, escrowIndex, currency, msg.sender, escrow.amount);
    }

    function withdrawEscrowAfterReturn(uint escrowIndex) external onlyAuthorizedUsers {
        EscrowStructs.FXEscrow storage escrow = escrows[msg.sender][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isWithdrawn, "Escrow is already withdrawn");
        require(escrow.isReturned, "Escrow has not been returned");
        require(!escrow.isFrozen, "Escrow is frozen and cannot be withdrawn");

        escrow.isWithdrawn = true;

        // Transfer the escrow amount back to the user
        transferFundsFromContract(msg.sender, escrow.amount);

        emit EscrowWithdrawnAfterReturn(msg.sender, escrowIndex, currency, msg.sender, escrow.amount);
    }

    function withdrawFees(address payable _to) external onlyAdmin {
        require(_to != address(0), "Cannot withdraw to zero address");
        uint amount = platformFeeBalance;
        transferFundsFromContract(_to, amount);
        platformFeeBalance = 0;
    }

    function getCurrency() external view returns (string memory) {
        return string(abi.encodePacked(currency));
    }

    function _calcBasisPointShare(uint _amount, uint basisPoints) internal pure returns (uint) {
        return (_amount * basisPoints) / 10000;
    }
}