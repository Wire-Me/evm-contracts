// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

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