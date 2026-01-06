// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

contract WalletConfig {
    mapping(bytes32 => address) public fxEscrowContracts;
    mapping(bytes32 => address) public erc20TokenContracts;

    constructor(
        address _usdcFxEscrowContract,
        address _usdtFxEscrowContract,
        address _nativeFxEscrowContract,
        address _usdcErc20Contract,
        address _usdtErc20Contract
    ) {
        fxEscrowContracts[keccak256("USDC")] = _usdcFxEscrowContract;
        fxEscrowContracts[keccak256("USDT")] = _usdtFxEscrowContract;
        fxEscrowContracts[keccak256("NATIVE")] = _nativeFxEscrowContract;

        erc20TokenContracts[keccak256("USDC")] = _usdcErc20Contract;
        erc20TokenContracts[keccak256("USDT")] = _usdtErc20Contract;
    }
}