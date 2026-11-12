// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "../lib/fx-contracts/fx-escrow/FxEscrowMulti.sol";
import "../lib/fx-contracts/fx-escrow/proxy/ProxyFxEscrowMulti.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/forge-std/src/Test.sol";

contract MockStablecoin is ERC20 {
    uint8 private immutable tokenDecimals;

    constructor(uint8 _tokenDecimals) ERC20("USDC", "USDC") {
        tokenDecimals = _tokenDecimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }
}

// The escrow's events are declared on the contract, so they are redeclared here for vm.expectEmit.
// Runs once per stablecoin decimals the escrow is deployed with (see the contracts at the end).
abstract contract FxEscrowAdminTest is Test {
    event EscrowDefrosted(address indexed _creatorOfEscrow, uint indexed _escrowIndex, bytes32 indexed _currency);
    event EscrowExpirationExtended(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        uint _newExpirationTimestamp
    );
    event FundsReceivedAdmin(address indexed _creatorOfEscrow, uint indexed _escrowIndex, bytes32 indexed _currency);

    bytes32 internal constant USDC = keccak256("USDC");
    uint internal escrowAmount;
    uint internal brokerDeposit;

    // In production the admin is the Safe, so this stands in for it.
    address internal admin = makeAddr("safe");
    address internal seller = makeAddr("seller");
    address internal broker = makeAddr("broker");

    MockStablecoin internal usdc;
    FxEscrowMulti internal escrow;

    function _tokenDecimals() internal pure virtual returns (uint8);

    function setUp() public {
        uint oneToken = 10 ** _tokenDecimals();
        escrowAmount = 100 * oneToken;
        brokerDeposit = 500 * oneToken;
        usdc = new MockStablecoin(_tokenDecimals());

        vm.startPrank(admin);
        EscrowConfig escrowConfig = new EscrowConfig(address(usdc), address(usdc));
        ProxyFxEscrowMulti proxy = new ProxyFxEscrowMulti(
            address(new FxEscrowMulti()),
            admin,
            address(escrowConfig),
            brokerDeposit,
            48 hours
        );
        escrow = FxEscrowMulti(payable(address(proxy)));
        escrow.addAuthorizedUser(seller);
        escrow.addAuthorizedBroker(broker);
        vm.stopPrank();

        usdc.mint(seller, escrowAmount);
        usdc.mint(broker, brokerDeposit);
    }

    function _fundEscrowAndLinkOffer(bool withExplicitExpiration, uint expirationDuration) internal {
        vm.startPrank(seller);
        usdc.approve(address(escrow), escrowAmount);
        escrow.createEscrow(USDC, escrowAmount);
        vm.stopPrank();

        vm.prank(broker);
        if (withExplicitExpiration) {
            escrow.createOfferWithExpiration(USDC, seller, 0, 0, expirationDuration);
        } else {
            escrow.createOffer(USDC, seller, 0, 0);
        }

        vm.prank(seller);
        escrow.linkOfferToEscrow(USDC, 0, broker, 0);
    }

    function _assertNoEventNamesTheAdmin(Vm.Log[] memory logs) internal view {
        bytes32 adminTopic = bytes32(uint256(uint160(admin)));
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].emitter != address(escrow) || logs[i].topics.length < 2) continue;
            assertTrue(logs[i].topics[1] != adminTopic, "an escrow event names the admin as the escrow creator");
        }
    }

    function test_MarkFundsAsReceivedAdmin_ExplicitExpiration_EmitsForTheEscrowCreator() public {
        uint duration = 3 hours;
        _fundEscrowAndLinkOffer(true, duration);
        uint expectedExpiration = block.timestamp + duration;

        vm.expectEmit(true, true, true, true, address(escrow));
        emit EscrowExpirationExtended(seller, 0, USDC, expectedExpiration);
        vm.expectEmit(true, true, true, true, address(escrow));
        emit FundsReceivedAdmin(seller, 0, USDC);

        vm.recordLogs();
        vm.prank(admin);
        escrow.markFundsAsReceivedAdmin(USDC, seller, 0);
        _assertNoEventNamesTheAdmin(vm.getRecordedLogs());

        EscrowStructs.FXEscrow memory escrowData = escrow.getEscrow(USDC, seller, 0);
        assertTrue(escrowData.isFundsReceived);
        assertEq(escrowData.expirationTimestamp, expectedExpiration);
    }

    function test_MarkFundsAsReceivedAdmin_BrokerWithoutDeposit_EmitsFallbackExpirationForTheEscrowCreator() public {
        _fundEscrowAndLinkOffer(false, 0);
        uint expectedExpiration = block.timestamp + escrow.EXPIRATION_DURATION_FOR_NON_BROKERS();

        vm.expectEmit(true, true, true, true, address(escrow));
        emit EscrowExpirationExtended(seller, 0, USDC, expectedExpiration);
        vm.expectEmit(true, true, true, true, address(escrow));
        emit FundsReceivedAdmin(seller, 0, USDC);

        vm.recordLogs();
        vm.prank(admin);
        escrow.markFundsAsReceivedAdmin(USDC, seller, 0);
        _assertNoEventNamesTheAdmin(vm.getRecordedLogs());

        assertEq(escrow.getEscrow(USDC, seller, 0).expirationTimestamp, expectedExpiration);
    }

    function test_MarkFundsAsReceivedAdmin_FrozenEscrow_EmitsDefrostForTheEscrowCreator() public {
        uint duration = 3 hours;
        _fundEscrowAndLinkOffer(true, duration);
        vm.prank(admin);
        escrow.freezeEscrow(USDC, seller, 0);

        vm.expectEmit(true, true, true, true, address(escrow));
        emit EscrowDefrosted(seller, 0, USDC);
        vm.expectEmit(true, true, true, true, address(escrow));
        emit EscrowExpirationExtended(seller, 0, USDC, block.timestamp + duration);
        vm.expectEmit(true, true, true, true, address(escrow));
        emit FundsReceivedAdmin(seller, 0, USDC);

        vm.recordLogs();
        vm.prank(admin);
        escrow.markFundsAsReceivedAdmin(USDC, seller, 0);
        _assertNoEventNamesTheAdmin(vm.getRecordedLogs());

        assertFalse(escrow.getEscrow(USDC, seller, 0).isFrozen);
    }

    // A broker with a full deposit and no explicit offer expiration keeps the escrow's expiry as is.
    function test_MarkFundsAsReceivedAdmin_BrokerWithDeposit_EmitsNoExpirationEvent() public {
        vm.startPrank(broker);
        usdc.approve(address(escrow), brokerDeposit);
        escrow.upsertSecurityDeposit(USDC, brokerDeposit);
        vm.stopPrank();
        _fundEscrowAndLinkOffer(false, 0);

        vm.recordLogs();
        vm.prank(admin);
        escrow.markFundsAsReceivedAdmin(USDC, seller, 0);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], FundsReceivedAdmin.selector);
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(seller))));
    }

    function test_MarkFundsAsReceivedAdmin_RejectsNonAdmin() public {
        _fundEscrowAndLinkOffer(true, 3 hours);

        vm.prank(seller);
        vm.expectRevert("Sender is not an authorized admin account");
        escrow.markFundsAsReceivedAdmin(USDC, seller, 0);
    }
}

// USDC and USDT on Base, Ethereum and Sepolia
contract FxEscrowAdmin6DecimalTokenTest is FxEscrowAdminTest {
    function _tokenDecimals() internal pure override returns (uint8) {
        return 6;
    }
}

// The Binance-Peg USDC and USDT on BNB Smart Chain
contract FxEscrowAdmin18DecimalTokenTest is FxEscrowAdminTest {
    function _tokenDecimals() internal pure override returns (uint8) {
        return 18;
    }
}
