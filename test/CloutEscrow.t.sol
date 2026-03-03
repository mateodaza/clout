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
    event ChallengeAccepted(
        uint256 indexed challengeId,
        address indexed opponent,
        uint256 acceptedAt
    );
    event ChallengeVoided(
        uint256 indexed challengeId,
        address indexed calledBy,
        uint256 voidedAt
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

        vm.prank(bob);
        token.approve(address(escrow), type(uint256).max);
    }

    function _createDefault() internal returns (uint256) {
        vm.prank(alice);
        return escrow.createChallenge(bob, STAKE, address(token), GAME_ID, charlie);
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
            uint256 disputedAt,
            bool claimed
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
        assertEq(claimed, false);
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

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , ) = escrow.challenges(1);
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

        (, , address designatedResolver, , , , , , , , , , , , ) = escrow.challenges(1);
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
        vm.prank(alice);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));

        // Read firstChallengeAt from storage (avoids via_ir block.timestamp CSE issue)
        (, , , , , uint256 firstTs, ) = escrow.walletRecords(alice);

        vm.warp(block.timestamp + 1 days);
        uint256 secondTs = block.timestamp;

        vm.prank(alice);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));

        (, , , , , uint256 firstChallengeAt, uint256 lastChallengeAt) = escrow.walletRecords(alice);

        assertEq(firstChallengeAt, firstTs);    // unchanged from first create
        assertEq(lastChallengeAt, secondTs);    // updated to second create ts
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

    // -------------------------------------------------------------------------
    // Test 17: acceptChallenge — state, acceptedAt, balances
    // -------------------------------------------------------------------------
    function test_acceptChallenge_success() public {
        uint256 id = _createDefault();
        uint256 bobBefore = token.balanceOf(bob);

        vm.prank(bob);
        escrow.acceptChallenge(id);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , uint256 acceptedAt, , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.ACCEPTED));
        assertEq(acceptedAt, block.timestamp);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);
        assertEq(token.balanceOf(bob), bobBefore - STAKE);
    }

    // -------------------------------------------------------------------------
    // Test 18: acceptChallenge — emits ChallengeAccepted event
    // -------------------------------------------------------------------------
    function test_acceptChallenge_emitsChallengeAcceptedEvent() public {
        uint256 id = _createDefault();

        vm.expectEmit(true, true, false, true);
        emit ChallengeAccepted(id, bob, block.timestamp);

        vm.prank(bob);
        escrow.acceptChallenge(id);
    }

    // -------------------------------------------------------------------------
    // Test 19: acceptChallenge — WalletRecord updated for opponent
    // -------------------------------------------------------------------------
    function test_acceptChallenge_walletRecord_updatedForOpponent() public {
        uint256 id = _createDefault();
        uint256 ts = block.timestamp;

        vm.prank(bob);
        escrow.acceptChallenge(id);

        (
            uint256 challengesEntered,
            ,
            ,
            ,
            uint256 totalStaked,
            uint256 firstChallengeAt,
            uint256 lastChallengeAt
        ) = escrow.walletRecords(bob);

        assertEq(challengesEntered, 1);
        assertEq(totalStaked, STAKE);
        assertEq(firstChallengeAt, ts);
        assertEq(lastChallengeAt, ts);
    }

    // -------------------------------------------------------------------------
    // Test 20: acceptChallenge — reverts when caller is not the designated opponent
    // -------------------------------------------------------------------------
    function test_acceptChallenge_revertsOnWrongOpponent() public {
        uint256 id = _createDefault();

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.NotOpponent.selector);
        escrow.acceptChallenge(id);
    }

    // -------------------------------------------------------------------------
    // Test 21: acceptChallenge — reverts when challenge is already ACCEPTED
    // -------------------------------------------------------------------------
    function test_acceptChallenge_revertsOnWrongState_alreadyAccepted() public {
        uint256 id = _createDefault();

        vm.prank(bob);
        escrow.acceptChallenge(id);

        vm.prank(bob);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.acceptChallenge(id);
    }

    // -------------------------------------------------------------------------
    // Test 22: acceptChallenge — reverts when opponent has insufficient allowance
    // -------------------------------------------------------------------------
    function test_acceptChallenge_revertsOnInsufficientAllowance() public {
        // charlie is opponent, dave is resolver; charlie has no approval
        vm.prank(alice);
        uint256 id = escrow.createChallenge(charlie, STAKE, address(token), GAME_ID, dave);

        vm.prank(charlie);
        vm.expectRevert();
        escrow.acceptChallenge(id);
    }

    // -------------------------------------------------------------------------
    // Test 23: voidChallenge from CREATED — refunds creator after timeout
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromCreated_afterTimeout_refundsCreator() public {
        uint256 id = _createDefault();
        (, , , , , , , , , , uint256 createdAt, , , , ) = escrow.challenges(id);
        uint256 aliceBefore = token.balanceOf(alice);

        vm.warp(createdAt + escrow.VOID_TIMEOUT() + 1);

        vm.prank(dave);
        escrow.voidChallenge(id);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.VOIDED));
        assertEq(token.balanceOf(alice), aliceBefore + STAKE);
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    // -------------------------------------------------------------------------
    // Test 24: voidChallenge from CREATED — emits ChallengeVoided event
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromCreated_emitsChallengeVoidedEvent() public {
        uint256 id = _createDefault();
        (, , , , , , , , , , uint256 createdAt, , , , ) = escrow.challenges(id);

        vm.warp(createdAt + escrow.VOID_TIMEOUT() + 1);

        vm.expectEmit(true, true, false, true);
        emit ChallengeVoided(id, dave, block.timestamp);

        vm.prank(dave);
        escrow.voidChallenge(id);
    }

    // -------------------------------------------------------------------------
    // Test 25: voidChallenge from CREATED — reverts before timeout expires
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromCreated_beforeTimeout_reverts() public {
        uint256 id = _createDefault();
        (, , , , , , , , , , uint256 createdAt, , , , ) = escrow.challenges(id);

        vm.warp(createdAt + escrow.VOID_TIMEOUT() - 1);

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.TimeoutNotExpired.selector);
        escrow.voidChallenge(id);
    }

    // -------------------------------------------------------------------------
    // Test 26: voidChallenge from CREATED — WalletRecord completion stats
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromCreated_walletRecord_completionStats() public {
        uint256 id = _createDefault();
        (, , , , , , , , , , uint256 createdAt, , , , ) = escrow.challenges(id);

        vm.warp(createdAt + escrow.VOID_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.voidChallenge(id);

        (, uint256 aliceCompleted, uint256 aliceWon, , , , ) = escrow.walletRecords(alice);
        assertEq(aliceCompleted, 1);
        assertEq(aliceWon, 0);

        // Bob never entered (never accepted), his record is unchanged
        (uint256 bobEntered, , , , , , ) = escrow.walletRecords(bob);
        assertEq(bobEntered, 0);
    }

    // -------------------------------------------------------------------------
    // Test 27: voidChallenge from ACCEPTED — refunds both parties after timeout
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromAccepted_afterTimeout_refundsBoth() public {
        uint256 id = _createDefault();
        vm.prank(bob);
        escrow.acceptChallenge(id);

        (, , , , , , , , , , , uint256 acceptedAt, , , ) = escrow.challenges(id);
        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore = token.balanceOf(bob);

        vm.warp(acceptedAt + escrow.VOID_TIMEOUT() + 1);

        vm.prank(alice);
        escrow.voidChallenge(id);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.VOIDED));
        assertEq(token.balanceOf(alice), aliceBefore + STAKE);
        assertEq(token.balanceOf(bob), bobBefore + STAKE);
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    // -------------------------------------------------------------------------
    // Test 28: voidChallenge from ACCEPTED — reverts before timeout expires
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromAccepted_beforeTimeout_reverts() public {
        uint256 id = _createDefault();
        vm.prank(bob);
        escrow.acceptChallenge(id);

        (, , , , , , , , , , , uint256 acceptedAt, , , ) = escrow.challenges(id);

        vm.warp(acceptedAt + escrow.VOID_TIMEOUT() - 1);

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.TimeoutNotExpired.selector);
        escrow.voidChallenge(id);
    }

    // -------------------------------------------------------------------------
    // Test 29: voidChallenge from ACCEPTED — reverts for non-participant
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromAccepted_revertsForNonParticipant() public {
        uint256 id = _createDefault();
        vm.prank(bob);
        escrow.acceptChallenge(id);

        (, , , , , , , , , , , uint256 acceptedAt, , , ) = escrow.challenges(id);

        vm.warp(acceptedAt + escrow.VOID_TIMEOUT() + 1);

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.NotParticipant.selector);
        escrow.voidChallenge(id);
    }

    // -------------------------------------------------------------------------
    // Test 30: voidChallenge from ACCEPTED — WalletRecord completion stats for both
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromAccepted_walletRecord_completionStats() public {
        uint256 id = _createDefault();
        vm.prank(bob);
        escrow.acceptChallenge(id);

        (, , , , , , , , , , , uint256 acceptedAt, , , ) = escrow.challenges(id);

        vm.warp(acceptedAt + escrow.VOID_TIMEOUT() + 1);
        vm.prank(alice);
        escrow.voidChallenge(id);

        (, uint256 aliceCompleted, uint256 aliceWon, , , , ) = escrow.walletRecords(alice);
        assertEq(aliceCompleted, 1);
        assertEq(aliceWon, 0);

        (, uint256 bobCompleted, uint256 bobWon, , , , ) = escrow.walletRecords(bob);
        assertEq(bobCompleted, 1);
        assertEq(bobWon, 0);
    }

    // -------------------------------------------------------------------------
    // Test 31: voidChallenge — claimed field is true after void
    // -------------------------------------------------------------------------
    function test_voidChallenge_claimed_field_true_after_void() public {
        uint256 id = _createDefault();
        (, , , , , , , , , , uint256 createdAt, , , , ) = escrow.challenges(id);

        vm.warp(createdAt + escrow.VOID_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.voidChallenge(id);

        (, , , , , , , , , , , , , , bool claimed) = escrow.challenges(id);
        assertEq(claimed, true);
    }

    // -------------------------------------------------------------------------
    // Test 32: voidChallenge from VOIDED — reverts WrongState
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromVoided_reverts() public {
        uint256 id = _createDefault();
        (, , , , , , , , , , uint256 createdAt, , , , ) = escrow.challenges(id);

        vm.warp(createdAt + escrow.VOID_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.voidChallenge(id);

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.voidChallenge(id);
    }
}
