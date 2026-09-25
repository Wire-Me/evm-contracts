// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice A stand-in for USDC/USDT on networks that don't have the real thing - local chains and
/// testnets. Name, symbol and decimals are constructor args so one contract covers both tokens.
/// Minting is deliberately unrestricted so it doubles as a faucet on a testnet.
///
/// @dev Not for mainnet. Real USDC and USDT already exist on Base; point EscrowConfig and
/// WalletConfig at those canonical addresses rather than deploying this. The `deploy-tokens`
/// hardhat task refuses to deploy this to a mainnet chain id without an explicit override.
contract TestStablecoin is ERC20 {
    uint8 private immutable _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
