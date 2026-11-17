// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "../src/test-tokens/TestStablecoin.sol";
import "../lib/forge-std/src/Test.sol";

/// @notice Covers the stand-in token deployed to local/testnet by the `deploy-tokens` task. The
/// escrow contracts assume 6-decimal stablecoins (MINIMUM_BROKER_DEPOSIT_AMOUNT_ERC20 is
/// 500 * 10**6), so the configurable decimals are worth pinning down.
contract TestStablecoinTest is Test {
    TestStablecoin internal token;

    function setUp() public {
        token = new TestStablecoin("Test USD Coin", "USDC", 6);
    }

    function test_ReportsConstructorMetadata() public view {
        assertEq(token.name(), "Test USD Coin");
        assertEq(token.symbol(), "USDC");
        assertEq(token.decimals(), 6);
    }

    function test_DecimalsAreConfigurable() public {
        TestStablecoin eighteenDecimals = new TestStablecoin("Test Ether", "TETH", 18);
        assertEq(eighteenDecimals.decimals(), 18);
    }

    function test_MintIsUnrestricted() public {
        address recipient = address(0xBEEF);
        address stranger = address(0xD00D);

        vm.prank(stranger);
        token.mint(recipient, 1_000 * 10 ** 6);

        assertEq(token.balanceOf(recipient), 1_000 * 10 ** 6);
        assertEq(token.totalSupply(), 1_000 * 10 ** 6);
    }

    function test_TransfersMovePresetBalances() public {
        address sender = address(0xA11CE);
        address recipient = address(0xB0B);
        token.mint(sender, 100 * 10 ** 6);

        vm.prank(sender);
        token.transfer(recipient, 40 * 10 ** 6);

        assertEq(token.balanceOf(sender), 60 * 10 ** 6);
        assertEq(token.balanceOf(recipient), 40 * 10 ** 6);
    }
}
