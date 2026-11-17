// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

/// @custom:deprecated Deprecated along with the rest of the smart-wallet layer in favor of
/// Openfort embedded wallets. Still in active production use via ProxySmartWalletMulti /
/// SmartWalletMulti; see AbstractSmartWalletMulti.sol for removal criteria.
contract WalletConfig {
    address public fxEscrowMultiContract;
    mapping(bytes32 => address) public erc20TokenContracts;

    constructor(
        address _fxEscrowMultiContract,
        address _usdcErc20Contract,
        address _usdtErc20Contract
    ) {
        fxEscrowMultiContract = _fxEscrowMultiContract;

        erc20TokenContracts[keccak256("USDC")] = _usdcErc20Contract;
        erc20TokenContracts[keccak256("USDT")] = _usdtErc20Contract;
    }
}