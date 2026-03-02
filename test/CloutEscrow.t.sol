// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CloutEscrow} from "../src/CloutEscrow.sol";
import {MockStablecoin} from "../src/MockStablecoin.sol";

// ERC20 that returns false instead of reverting — used to test SafeERC20 path
contract MockReturnFalseToken {
    string public name = "ReturnFalse";
    string public symbol = "RF";
    uint8 public decimals = 6;
    function transferFrom(address, address, uint256) external pure returns (bool) { return false; }
    function allowance(address, address) external pure returns (uint256) { return type(uint256).max; }
}

contract CloutEscrowTest is Test {
    // Re-declare events for vm.expectEmit
    event ChallengeCreated(
        uint256 indexed challengeId,
        address indexed creator,
        address indexed opponent,
        address token,
        uint256 stakeAmount,
        bytes32 gameId,
        address designatedResolver,
        uint256 createdAt
    );

    CloutEscrow escrow;
    MockStablecoin token;
    MockReturnFalseToken badToken;

    address admin = address(this);        // test contract = owner of escrow
    address alice = address(0xA11CE);     // creator
    address bob   = address(0xB0B);       // opponent
    address charlie = address(0xC4A1);   // designated resolver
    address dave  = address(0xDA7E);      // unrelated address

    uint256 constant STAKE   = 100 * 1e6;           // 100 USDC
    bytes32 constant GAME_ID = bytes32("game-1");

    function setUp() public {
        token = new MockStablecoin();
        badToken = new MockReturnFalseToken();
        escrow = new CloutEscrow();

        escrow.addWhitelistedToken(address(token));

        token.mint(alice, 10_000e6);
        token.mint(bob, 10_000e6);
        token.mint(charlie, 10_000e6);

        vm.prank(alice);
        token.approve(address(escrow), type(uint256).max);
    }

    // -------------------------------------------------------------------------
    // Test 1: success — fields stored correctly, challengeCount=1, return value=1
    // -------------------------------------------------------------------------
    function test_createChallenge_success() public {
        vm.prank(alice);
        uint256 id = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, charlie);

        assertEq(id, 1);
        assertEq(escrow.challengeCount(), 1);

        (
            address creator,
            address opponent,
            address designatedResolver,
            address tok,
            uint256 stakeAmount,
            CloutEscrow.ChallengeState state,
            bytes32 gameId,
            bytes32 matchId,
            CloutEscrow.Outcome submittedResult,
            address submittedBy,
            uint256 createdAt,
            uint256 acceptedAt,
            uint256 submittedAt,
            uint256 disputedAt
        ) = escrow.challenges(1);

        assertEq(creator, alice);
        assertEq(opponent, bob);
        assertEq(designatedResolver, charlie);
        assertEq(tok, address(token));
        assertEq(stakeAmount, STAKE);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.CREATED));
        assertEq(gameId, GAME_ID);
        assertEq(matchId, bytes32(0));
        assertEq(uint256(submittedResult), uint256(CloutEscrow.Outcome.NONE));
        assertEq(submittedBy, address(0));
        assertEq(createdAt, block.timestamp);
        assertEq(acceptedAt, 0);
        assertEq(submittedAt, 0);
        assertEq(disputedAt, 0);
    }

    // -------------------------------------------------------------------------
    // Test 2: ChallengeCreated event emitted with all fields
    // -------------------------------------------------------------------------
    function test_createChallenge_emitsChallengeCreatedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit ChallengeCreated(
            1,
            alice,
            bob,
            address(token),
            STAKE,
            GAME_ID,
            charlie,
            block.timestamp
        );
        vm.prank(alice);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, charlie);
    }

    // -------------------------------------------------------------------------
    // Test 3: challengeCount increments with successive creates
    // -------------------------------------------------------------------------
    function test_createChallenge_incrementsChallengeCount() public {
        vm.prank(alice);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));
        assertEq(escrow.challengeCount(), 1);

        vm.prank(alice);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));
        assertEq(escrow.challengeCount(), 2);
    }

    // -------------------------------------------------------------------------
    // Test 4: state is CREATED
    // -------------------------------------------------------------------------
    function test_createChallenge_stateIsCreated() public {
        vm.prank(alice);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , ) = escrow.challenges(1);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.CREATED));
    }

    // -------------------------------------------------------------------------
    // Test 5: reverts on zero stake
    // -------------------------------------------------------------------------
    function test_createChallenge_revertsOnZeroStake() public {
        vm.prank(alice);
        vm.expectRevert(CloutEscrow.ZeroStake.selector);
        escrow.createChallenge(bob, 0, address(token), GAME_ID, address(0));
    }

    // -------------------------------------------------------------------------
    // Test 6: reverts on non-whitelisted token
    // -------------------------------------------------------------------------
    function test_createChallenge_revertsOnNonWhitelistedToken() public {
        address fakeToken = address(0xDEAD);
        vm.prank(alice);
        vm.expectRevert(CloutEscrow.TokenNotWhitelisted.selector);
        escrow.createChallenge(bob, STAKE, fakeToken, GAME_ID, address(0));
    }

    // -------------------------------------------------------------------------
    // Test 7: reverts on opponent == address(0)
    // -------------------------------------------------------------------------
    function test_createChallenge_revertsOnOpponentIsZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(CloutEscrow.OpponentIsZeroAddress.selector);
        escrow.createChallenge(address(0), STAKE, address(token), GAME_ID, address(0));
    }

    // -------------------------------------------------------------------------
    // Test 8: reverts on opponent == creator
    // -------------------------------------------------------------------------
    function test_createChallenge_revertsOnOpponentIsCreator() public {
        vm.prank(alice);
        vm.expectRevert(CloutEscrow.OpponentIsCreator.selector);
        escrow.createChallenge(alice, STAKE, address(token), GAME_ID, address(0));
    }

    // -------------------------------------------------------------------------
    // Test 9: reverts on resolver == creator (invariant I-3)
    // -------------------------------------------------------------------------
    function test_createChallenge_revertsOnResolverIsCreator() public {
        vm.prank(alice);
        vm.expectRevert(CloutEscrow.ResolverIsCreator.selector);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, alice);
    }

    // -------------------------------------------------------------------------
    // Test 10: reverts on resolver == opponent (invariant I-3)
    // -------------------------------------------------------------------------
    function test_createChallenge_revertsOnResolverIsOpponent() public {
        vm.prank(alice);
        vm.expectRevert(CloutEscrow.ResolverIsOpponent.selector);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, bob);
    }

    // -------------------------------------------------------------------------
    // Test 11: allows address(0) as resolver (admin-only mode)
    // -------------------------------------------------------------------------
    function test_createChallenge_allowsZeroAddressResolver() public {
        vm.prank(alice);
        uint256 id = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));
        assertEq(id, 1);

        (, , address designatedResolver, , , , , , , , , , , ) = escrow.challenges(1);
        assertEq(designatedResolver, address(0));
    }

    // -------------------------------------------------------------------------
    // Test 12: WalletRecord updated on create
    // -------------------------------------------------------------------------
    function test_walletRecord_updatedOnCreate() public {
        uint256 ts = block.timestamp;

        vm.prank(alice);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));

        (
            uint256 challengesEntered,
            uint256 challengesCompleted,
            uint256 challengesWon,
            uint256 challengesDisputed,
            uint256 totalStaked,
            uint256 firstChallengeAt,
            uint256 lastChallengeAt
        ) = escrow.walletRecords(alice);

        assertEq(challengesEntered, 1);
        assertEq(challengesCompleted, 0);
        assertEq(challengesWon, 0);
        assertEq(challengesDisputed, 0);
        assertEq(totalStaked, STAKE);
        assertEq(firstChallengeAt, ts);
        assertEq(lastChallengeAt, ts);
    }

    // -------------------------------------------------------------------------
    // Test 13: firstChallengeAt only set once; lastChallengeAt updates
    // -------------------------------------------------------------------------
    function test_walletRecord_firstChallengeAtOnlySetOnce() public {
        uint256 firstTs = block.timestamp;

        vm.prank(alice);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));

        vm.warp(block.timestamp + 1 days);
        uint256 secondTs = block.timestamp;

        vm.prank(alice);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));

        (, , , , , uint256 firstChallengeAt, uint256 lastChallengeAt) = escrow.walletRecords(alice);

        assertEq(firstChallengeAt, firstTs);
        assertEq(lastChallengeAt, secondTs);
    }

    // -------------------------------------------------------------------------
    // Test 14: whitelist add/remove/query, non-owner reverts
    // -------------------------------------------------------------------------
    function test_whitelist_addRemoveAndQuery() public {
        address newToken = address(0x1234);

        // not whitelisted initially
        assertFalse(escrow.isWhitelisted(newToken));

        // owner can add
        escrow.addWhitelistedToken(newToken);
        assertTrue(escrow.isWhitelisted(newToken));

        // owner can remove
        escrow.removeWhitelistedToken(newToken);
        assertFalse(escrow.isWhitelisted(newToken));

        // non-owner add reverts
        vm.prank(dave);
        vm.expectRevert();
        escrow.addWhitelistedToken(newToken);

        // non-owner remove reverts
        vm.prank(dave);
        vm.expectRevert();
        escrow.removeWhitelistedToken(newToken);
    }

    // -------------------------------------------------------------------------
    // Test 15: escrow holds funds after create; alice balance decreases
    // -------------------------------------------------------------------------
    function test_escrow_holdsFundsAfterCreate() public {
        uint256 aliceBefore = token.balanceOf(alice);

        vm.prank(alice);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));

        assertEq(token.balanceOf(address(escrow)), STAKE);
        assertEq(token.balanceOf(alice), aliceBefore - STAKE);
    }

    // -------------------------------------------------------------------------
    // Test 16: reverts when token transferFrom returns false (SafeERC20 path)
    // -------------------------------------------------------------------------
    function test_createChallenge_revertsWhenTransferReturnsFalse() public {
        // whitelist the bad token
        escrow.addWhitelistedToken(address(badToken));

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(badToken))
        );
        escrow.createChallenge(bob, STAKE, address(badToken), GAME_ID, address(0));
    }
}
