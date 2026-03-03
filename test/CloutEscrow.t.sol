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
    event ResultSubmitted(uint256 indexed, address indexed, CloutEscrow.Outcome, uint256);
    event ResultConfirmed(uint256 indexed, address indexed, CloutEscrow.Outcome);
    event ChallengeFinalizedByTimeout(uint256 indexed, CloutEscrow.Outcome, uint256);
    event ResultDisputed(uint256 indexed, address indexed, uint256);
    event DisputeResolved(uint256 indexed, address indexed, CloutEscrow.Outcome, uint256);
    event ResolutionAppealed(uint256 indexed, address indexed, uint256);
    event ResolutionFinalized(uint256 indexed, CloutEscrow.Outcome, uint256);
    event ChallengeVoidedByAdminTimeout(uint256 indexed, uint256);
    event WinningsClaimed(
        uint256 indexed challengeId,
        CloutEscrow.Outcome outcome,
        uint256 creatorPayout,
        uint256 opponentPayout,
        uint256 protocolFee
    );
    event ProtocolFeeUpdated(uint256 oldBps, uint256 newBps);
    event TreasuryUpdated(address oldTreasury, address newTreasury);

    CloutEscrow escrow;
    MockStablecoin token;
    MockReturnFalseToken badToken;

    address admin    = address(this);        // test contract = owner of escrow
    address alice    = address(0xA11CE);     // creator
    address bob      = address(0xB0B);       // opponent
    address charlie  = address(0xC4A1);      // designated resolver
    address dave     = address(0xDA7E);      // unrelated address
    address treasury = address(0xFEE1);      // protocol fee recipient

    uint256 constant STAKE   = 100 * 1e6;           // 100 USDC
    bytes32 constant GAME_ID = bytes32("game-1");

    function setUp() public {
        token = new MockStablecoin();
        badToken = new MockReturnFalseToken();
        escrow = new CloutEscrow();

        escrow.addWhitelistedToken(address(token));
        escrow.setTreasury(treasury);   // feeBps defaults to 250 from constructor

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

    function _createAndAccept() internal returns (uint256) {
        uint256 id = _createDefault(); // alice creates (creator=alice, opponent=bob)
        vm.prank(bob);
        escrow.acceptChallenge(id);
        return id;
    }

    function _submitAndDispute() internal returns (uint256) {
        uint256 id = _createAndAccept();
        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        vm.prank(bob);
        escrow.disputeResult(id);
        return id;
    }

    /// @dev Takes a challenge to RESOLVED state (alice submitted CREATOR_WIN, bob disputed, charlie resolved).
    function _submitDisputeAndResolve() internal returns (uint256) {
        uint256 id = _submitAndDispute();
        vm.prank(charlie);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);
        return id;
    }

    // -------------------------------------------------------------------------
    // Test 1: success — fields stored correctly, challengeCount=1, return value=1
    // -------------------------------------------------------------------------
    function test_createChallenge_success() public {
        vm.prank(alice);
        uint256 id = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, charlie);

        assertEq(id, 1);
        assertEq(escrow.challengeCount(), 1);

        // Split into two scoped blocks to avoid stack-too-deep with 18 fields
        {
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
                , , , , , , , ,
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
        }
        {
            (
                , , , , , , , , ,
                address submittedBy,
                uint256 createdAt,
                uint256 acceptedAt,
                uint256 submittedAt,
                uint256 disputedAt,
                uint256 resolvedAt,
                bool claimed,
                bool appealed,
                uint256 appealedAt
            ) = escrow.challenges(1);

            assertEq(submittedBy, address(0));
            assertEq(createdAt, block.timestamp);
            assertEq(acceptedAt, 0);
            assertEq(submittedAt, 0);
            assertEq(disputedAt, 0);
            assertEq(resolvedAt, 0);
            assertEq(claimed, false);
            assertEq(appealed, false);
            assertEq(appealedAt, 0);
        }
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

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , , , , ) = escrow.challenges(1);
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

        (, , address designatedResolver, , , , , , , , , , , , , , , ) = escrow.challenges(1);
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

        (, , , , , CloutEscrow.ChallengeState state, , , , , , uint256 acceptedAt, , , , , , ) = escrow.challenges(id);
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
    // Test 23: voidChallenge from CREATED — refunds creator after timeout (via claimWinnings)
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromCreated_afterTimeout_refundsCreator() public {
        uint256 id = _createDefault();
        (, , , , , , , , , , uint256 createdAt, , , , , , , ) = escrow.challenges(id);
        uint256 aliceBefore = token.balanceOf(alice);

        vm.warp(createdAt + escrow.VOID_TIMEOUT() + 1);

        vm.prank(dave);
        escrow.voidChallenge(id);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.VOIDED));

        // claimWinnings settles the transfer
        vm.prank(alice);
        escrow.claimWinnings(id);

        assertEq(token.balanceOf(alice), aliceBefore + STAKE);
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    // -------------------------------------------------------------------------
    // Test 24: voidChallenge from CREATED — emits ChallengeVoided event
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromCreated_emitsChallengeVoidedEvent() public {
        uint256 id = _createDefault();
        (, , , , , , , , , , uint256 createdAt, , , , , , , ) = escrow.challenges(id);

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
        (, , , , , , , , , , uint256 createdAt, , , , , , , ) = escrow.challenges(id);

        vm.warp(createdAt + escrow.VOID_TIMEOUT() - 1);

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.TimeoutNotExpired.selector);
        escrow.voidChallenge(id);
    }

    // -------------------------------------------------------------------------
    // Test 26: voidChallenge from CREATED — WalletRecord completion stats (via claimWinnings)
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromCreated_walletRecord_completionStats() public {
        uint256 id = _createDefault();
        (, , , , , , , , , , uint256 createdAt, , , , , , , ) = escrow.challenges(id);

        vm.warp(createdAt + escrow.VOID_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.voidChallenge(id);

        // claimWinnings updates completion stats
        vm.prank(alice);
        escrow.claimWinnings(id);

        (, uint256 aliceCompleted, uint256 aliceWon, , , , ) = escrow.walletRecords(alice);
        assertEq(aliceCompleted, 1);
        assertEq(aliceWon, 0);

        // Bob never entered (never accepted), his record is unchanged
        (uint256 bobEntered, , , , , , ) = escrow.walletRecords(bob);
        assertEq(bobEntered, 0);
    }

    // -------------------------------------------------------------------------
    // Test 27: voidChallenge from ACCEPTED — refunds both parties after timeout (via claimWinnings)
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromAccepted_afterTimeout_refundsBoth() public {
        uint256 id = _createDefault();
        vm.prank(bob);
        escrow.acceptChallenge(id);

        (, , , , , , , , , , , uint256 acceptedAt, , , , , , ) = escrow.challenges(id);
        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore = token.balanceOf(bob);

        vm.warp(acceptedAt + escrow.VOID_TIMEOUT() + 1);

        vm.prank(alice);
        escrow.voidChallenge(id);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.VOIDED));

        // claimWinnings settles the transfers
        vm.prank(alice);
        escrow.claimWinnings(id);

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

        (, , , , , , , , , , , uint256 acceptedAt, , , , , , ) = escrow.challenges(id);

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

        (, , , , , , , , , , , uint256 acceptedAt, , , , , , ) = escrow.challenges(id);

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

        (, , , , , , , , , , , uint256 acceptedAt, , , , , , ) = escrow.challenges(id);

        vm.warp(acceptedAt + escrow.VOID_TIMEOUT() + 1);
        vm.prank(alice);
        escrow.voidChallenge(id);

        // claimWinnings updates completion stats (ACCEPTED→VOIDED: both parties)
        vm.prank(alice);
        escrow.claimWinnings(id);

        (, uint256 aliceCompleted, uint256 aliceWon, , , , ) = escrow.walletRecords(alice);
        assertEq(aliceCompleted, 1);
        assertEq(aliceWon, 0);

        (, uint256 bobCompleted, uint256 bobWon, , , , ) = escrow.walletRecords(bob);
        assertEq(bobCompleted, 1);
        assertEq(bobWon, 0);
    }

    // -------------------------------------------------------------------------
    // Test 31: voidChallenge — claimed field is true after claimWinnings (not after void)
    // -------------------------------------------------------------------------
    function test_voidChallenge_claimed_field_true_after_void() public {
        uint256 id = _createDefault();
        (, , , , , , , , , , uint256 createdAt, , , , , , , ) = escrow.challenges(id);

        vm.warp(createdAt + escrow.VOID_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.voidChallenge(id);

        // claimed is not set by voidChallenge — only by claimWinnings
        (, , , , , , , , , , , , , , , bool claimedBefore, , ) = escrow.challenges(id);
        assertEq(claimedBefore, false);

        // claimWinnings sets claimed = true
        vm.prank(alice);
        escrow.claimWinnings(id);

        (, , , , , , , , , , , , , , , bool claimed, , ) = escrow.challenges(id);
        assertEq(claimed, true);
    }

    // -------------------------------------------------------------------------
    // Test 32: voidChallenge from VOIDED — reverts WrongState
    // -------------------------------------------------------------------------
    function test_voidChallenge_fromVoided_reverts() public {
        uint256 id = _createDefault();
        (, , , , , , , , , , uint256 createdAt, , , , , , , ) = escrow.challenges(id);

        vm.warp(createdAt + escrow.VOID_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.voidChallenge(id);

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.voidChallenge(id);
    }

    // -------------------------------------------------------------------------
    // T33: submitResult — creator submits CREATOR_WIN from ACCEPTED
    // -------------------------------------------------------------------------
    function test_submitResult_creatorSubmits_success() public {
        uint256 id = _createAndAccept();
        uint256 ts = block.timestamp;

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        (
            , , , , ,
            CloutEscrow.ChallengeState state,
            , ,
            CloutEscrow.Outcome submittedResult,
            address submittedBy,
            , ,
            uint256 submittedAt,
            , , , ,
        ) = escrow.challenges(id);

        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.SUBMITTED));
        assertEq(submittedBy, alice);
        assertEq(uint256(submittedResult), uint256(CloutEscrow.Outcome.CREATOR_WIN));
        assertEq(submittedAt, ts);
    }

    // -------------------------------------------------------------------------
    // T34: submitResult — opponent submits OPPONENT_WIN from ACCEPTED
    // -------------------------------------------------------------------------
    function test_submitResult_opponentSubmits_success() public {
        uint256 id = _createAndAccept();

        vm.prank(bob);
        escrow.submitResult(id, CloutEscrow.Outcome.OPPONENT_WIN);

        (, , , , , CloutEscrow.ChallengeState state, , , , address submittedBy, , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.SUBMITTED));
        assertEq(submittedBy, bob);
    }

    // -------------------------------------------------------------------------
    // T35: submitResult — creator submits DRAW
    // -------------------------------------------------------------------------
    function test_submitResult_drawSubmitted_success() public {
        uint256 id = _createAndAccept();

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.DRAW);

        (, , , , , , , , CloutEscrow.Outcome submittedResult, , , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(submittedResult), uint256(CloutEscrow.Outcome.DRAW));
    }

    // -------------------------------------------------------------------------
    // T36: submitResult — emits ResultSubmitted event with correct args
    // -------------------------------------------------------------------------
    function test_submitResult_emitsResultSubmittedEvent() public {
        uint256 id = _createAndAccept();
        uint256 ts = block.timestamp;

        vm.expectEmit(true, true, false, true);
        emit ResultSubmitted(id, alice, CloutEscrow.Outcome.CREATOR_WIN, ts);

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
    }

    // -------------------------------------------------------------------------
    // T37: submitResult — reverts when called from CREATED state (WrongState)
    // -------------------------------------------------------------------------
    function test_submitResult_revertsOnWrongState_created() public {
        uint256 id = _createDefault();

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
    }

    // -------------------------------------------------------------------------
    // T38: submitResult — reverts for non-participant (NotParticipant)
    // -------------------------------------------------------------------------
    function test_submitResult_revertsOnNotParticipant() public {
        uint256 id = _createAndAccept();

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.NotParticipant.selector);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
    }

    // -------------------------------------------------------------------------
    // T39: submitResult — reverts when outcome is Outcome.NONE (InvalidOutcome)
    // -------------------------------------------------------------------------
    function test_submitResult_revertsOnNoneOutcome() public {
        uint256 id = _createAndAccept();

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.InvalidOutcome.selector);
        escrow.submitResult(id, CloutEscrow.Outcome.NONE);
    }

    // -------------------------------------------------------------------------
    // T40: submitResult — reverts when outcome is Outcome.INVALID (InvalidOutcome)
    // -------------------------------------------------------------------------
    function test_submitResult_revertsOnInvalidOutcome() public {
        uint256 id = _createAndAccept();

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.InvalidOutcome.selector);
        escrow.submitResult(id, CloutEscrow.Outcome.INVALID);
    }

    // -------------------------------------------------------------------------
    // T41: confirmResult — non-submitter confirms, state transitions to FINALIZED
    // -------------------------------------------------------------------------
    function test_confirmResult_success() public {
        uint256 id = _createAndAccept();

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        vm.prank(bob);
        escrow.confirmResult(id);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.FINALIZED));
    }

    // -------------------------------------------------------------------------
    // T42: confirmResult — emits ResultConfirmed event with correct args
    // -------------------------------------------------------------------------
    function test_confirmResult_emitsResultConfirmedEvent() public {
        uint256 id = _createAndAccept();

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        vm.expectEmit(true, true, false, true);
        emit ResultConfirmed(id, bob, CloutEscrow.Outcome.CREATOR_WIN);

        vm.prank(bob);
        escrow.confirmResult(id);
    }

    // -------------------------------------------------------------------------
    // T43: confirmResult — reverts when called from ACCEPTED state (WrongState)
    // -------------------------------------------------------------------------
    function test_confirmResult_revertsOnWrongState_accepted() public {
        uint256 id = _createAndAccept();

        vm.prank(bob);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.confirmResult(id);
    }

    // -------------------------------------------------------------------------
    // T44: confirmResult — reverts when the submitter tries to confirm own result
    // -------------------------------------------------------------------------
    function test_confirmResult_revertsOnSubmitter() public {
        uint256 id = _createAndAccept();

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.CallerIsSubmitter.selector);
        escrow.confirmResult(id);
    }

    // -------------------------------------------------------------------------
    // T48: confirmResult — reverts for non-participant (NotParticipant)
    // -------------------------------------------------------------------------
    function test_confirmResult_revertsOnNotParticipant() public {
        uint256 id = _createAndAccept();

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.NotParticipant.selector);
        escrow.confirmResult(id);
    }

    // -------------------------------------------------------------------------
    // T45: finalizeSubmission — succeeds after 24h+1s, state=FINALIZED, emits event
    // -------------------------------------------------------------------------
    function test_finalizeSubmission_success_afterTimeout() public {
        uint256 id = _createAndAccept();

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        (, , , , , , , , , , , , uint256 submittedAt, , , , , ) = escrow.challenges(id);
        vm.warp(submittedAt + escrow.SUBMISSION_TIMEOUT() + 1);

        vm.expectEmit(true, false, false, true);
        emit ChallengeFinalizedByTimeout(id, CloutEscrow.Outcome.CREATOR_WIN, block.timestamp);

        vm.prank(dave);
        escrow.finalizeSubmission(id);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.FINALIZED));
    }

    // -------------------------------------------------------------------------
    // T46: finalizeSubmission — reverts before 24h elapses (TimeoutNotExpired)
    // -------------------------------------------------------------------------
    function test_finalizeSubmission_revertsBeforeTimeout() public {
        uint256 id = _createAndAccept();

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        (, , , , , , , , , , , , uint256 submittedAt, , , , , ) = escrow.challenges(id);
        vm.warp(submittedAt + escrow.SUBMISSION_TIMEOUT() - 1);

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.TimeoutNotExpired.selector);
        escrow.finalizeSubmission(id);
    }

    // -------------------------------------------------------------------------
    // T47: finalizeSubmission — reverts from ACCEPTED state (WrongState)
    // -------------------------------------------------------------------------
    function test_finalizeSubmission_revertsOnWrongState_accepted() public {
        uint256 id = _createAndAccept();

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.finalizeSubmission(id);
    }

    // -------------------------------------------------------------------------
    // T49: disputeResult — state DISPUTED, disputedAt set
    // -------------------------------------------------------------------------
    function test_disputeResult_success() public {
        uint256 id = _createAndAccept();
        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        uint256 ts = block.timestamp;
        vm.prank(bob);
        escrow.disputeResult(id);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , uint256 disputedAt, , , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.DISPUTED));
        assertEq(disputedAt, ts);
    }

    // -------------------------------------------------------------------------
    // T50: disputeResult — emits ResultDisputed event
    // -------------------------------------------------------------------------
    function test_disputeResult_emitsResultDisputedEvent() public {
        uint256 id = _createAndAccept();
        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        uint256 ts = block.timestamp;
        vm.expectEmit(true, true, false, true);
        emit ResultDisputed(id, bob, ts);

        vm.prank(bob);
        escrow.disputeResult(id);
    }

    // -------------------------------------------------------------------------
    // T51: disputeResult — walletRecord challengesDisputed incremented
    // -------------------------------------------------------------------------
    function test_disputeResult_walletRecord_challengesDisputedIncremented() public {
        uint256 id = _createAndAccept();
        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        vm.prank(bob);
        escrow.disputeResult(id);

        (, , , uint256 bobDisputed, , , ) = escrow.walletRecords(bob);
        assertEq(bobDisputed, 1);

        (, , , uint256 aliceDisputed, , , ) = escrow.walletRecords(alice);
        assertEq(aliceDisputed, 0);
    }

    // -------------------------------------------------------------------------
    // T52: disputeResult — reverts when called by the submitter (CallerIsSubmitter)
    // -------------------------------------------------------------------------
    function test_disputeResult_revertsOnSubmitter() public {
        uint256 id = _createAndAccept();
        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.CallerIsSubmitter.selector);
        escrow.disputeResult(id);
    }

    // -------------------------------------------------------------------------
    // T53: disputeResult — reverts from ACCEPTED state (WrongState)
    // -------------------------------------------------------------------------
    function test_disputeResult_revertsOnWrongState_accepted() public {
        uint256 id = _createAndAccept();

        vm.prank(bob);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.disputeResult(id);
    }

    // -------------------------------------------------------------------------
    // T54: disputeResult — reverts for non-participant (NotParticipant)
    // -------------------------------------------------------------------------
    function test_disputeResult_revertsOnNotParticipant() public {
        uint256 id = _createAndAccept();
        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.NotParticipant.selector);
        escrow.disputeResult(id);
    }

    // -------------------------------------------------------------------------
    // T55: resolveDispute — resolver succeeds within 48h, state RESOLVED
    // -------------------------------------------------------------------------
    function test_resolveDispute_resolver_success() public {
        uint256 id = _submitAndDispute();
        uint256 ts = block.timestamp;

        vm.prank(charlie);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);

        (, , , , , CloutEscrow.ChallengeState state, , , CloutEscrow.Outcome submittedResult, , , , , , uint256 resolvedAt, , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.RESOLVED));
        assertEq(uint256(submittedResult), uint256(CloutEscrow.Outcome.CREATOR_WIN));
        assertEq(resolvedAt, ts);
        assertEq(escrow.resolvedChallenges(charlie), 1);
    }

    // -------------------------------------------------------------------------
    // T56: resolveDispute — emits DisputeResolved event
    // -------------------------------------------------------------------------
    function test_resolveDispute_resolver_emitsDisputeResolvedEvent() public {
        uint256 id = _submitAndDispute();
        uint256 ts = block.timestamp;

        vm.expectEmit(true, true, false, true);
        emit DisputeResolved(id, charlie, CloutEscrow.Outcome.CREATOR_WIN, ts);

        vm.prank(charlie);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);
    }

    // -------------------------------------------------------------------------
    // T57: resolveDispute — resolver can submit Outcome.INVALID
    // -------------------------------------------------------------------------
    function test_resolveDispute_resolver_canSubmitInvalidOutcome() public {
        uint256 id = _submitAndDispute();

        vm.prank(charlie);
        escrow.resolveDispute(id, CloutEscrow.Outcome.INVALID);

        (, , , , , , , , CloutEscrow.Outcome submittedResult, , , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(submittedResult), uint256(CloutEscrow.Outcome.INVALID));
    }

    // -------------------------------------------------------------------------
    // T58: resolveDispute — reverts for wrong caller (NotResolver)
    // -------------------------------------------------------------------------
    function test_resolveDispute_revertsOnWrongCaller_notResolver() public {
        uint256 id = _submitAndDispute();

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.NotResolver.selector);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);
    }

    // -------------------------------------------------------------------------
    // T59: resolveDispute — reverts from SUBMITTED state (WrongState)
    // -------------------------------------------------------------------------
    function test_resolveDispute_revertsOnWrongState_submitted() public {
        uint256 id = _createAndAccept();
        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        vm.prank(charlie);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);
    }

    // -------------------------------------------------------------------------
    // T60: resolveDispute — resolver reverts after 48h timeout (ResolverTimedOut)
    // -------------------------------------------------------------------------
    function test_resolveDispute_resolver_revertsAfterTimeout() public {
        uint256 id = _submitAndDispute();
        (, , , , , , , , , , , , , uint256 disputedAt, , , , ) = escrow.challenges(id);

        vm.warp(disputedAt + escrow.VOID_TIMEOUT() + 1);

        vm.prank(charlie);
        vm.expectRevert(CloutEscrow.ResolverTimedOut.selector);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);
    }

    // -------------------------------------------------------------------------
    // T61: resolveDispute — admin succeeds when no resolver is set
    // -------------------------------------------------------------------------
    function test_resolveDispute_admin_success_noResolver() public {
        vm.prank(alice);
        uint256 id = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));
        vm.prank(bob);
        escrow.acceptChallenge(id);
        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        vm.prank(bob);
        escrow.disputeResult(id);

        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.RESOLVED));
    }

    // -------------------------------------------------------------------------
    // T62: resolveDisputeAsAdmin — succeeds after 48h timeout
    // -------------------------------------------------------------------------
    function test_resolveDisputeAsAdmin_success_afterTimeout() public {
        uint256 id = _submitAndDispute();
        (, , , , , , , , , , , , , uint256 disputedAt, , , , ) = escrow.challenges(id);

        vm.warp(disputedAt + escrow.VOID_TIMEOUT() + 1);
        escrow.resolveDisputeAsAdmin(id, CloutEscrow.Outcome.OPPONENT_WIN);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , uint256 resolvedAt, , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.RESOLVED));
        assertGt(resolvedAt, 0);
        assertEq(escrow.resolvedChallenges(admin), 1);
    }

    // -------------------------------------------------------------------------
    // T63: resolveDisputeAsAdmin — reverts before 48h timeout (TimeoutNotExpired)
    // -------------------------------------------------------------------------
    function test_resolveDisputeAsAdmin_revertsBeforeTimeout() public {
        uint256 id = _submitAndDispute(); // charlie is designated resolver

        vm.expectRevert(CloutEscrow.TimeoutNotExpired.selector);
        escrow.resolveDisputeAsAdmin(id, CloutEscrow.Outcome.CREATOR_WIN);
    }

    // -------------------------------------------------------------------------
    // T64: resolveDisputeAsAdmin — succeeds immediately when no resolver is set
    // -------------------------------------------------------------------------
    function test_resolveDisputeAsAdmin_success_noResolver() public {
        vm.prank(alice);
        uint256 id = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));
        vm.prank(bob);
        escrow.acceptChallenge(id);
        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        vm.prank(bob);
        escrow.disputeResult(id);

        escrow.resolveDisputeAsAdmin(id, CloutEscrow.Outcome.CREATOR_WIN);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.RESOLVED));
    }

    // -------------------------------------------------------------------------
    // T65: resolveDisputeAsAdmin — reverts for non-admin (OwnableUnauthorizedAccount)
    // -------------------------------------------------------------------------
    function test_resolveDisputeAsAdmin_revertsForNonAdmin() public {
        uint256 id = _submitAndDispute();
        (, , , , , , , , , , , , , uint256 disputedAt, , , , ) = escrow.challenges(id);

        vm.warp(disputedAt + escrow.VOID_TIMEOUT() + 1);

        vm.prank(dave);
        vm.expectRevert();
        escrow.resolveDisputeAsAdmin(id, CloutEscrow.Outcome.CREATOR_WIN);
    }

    // -------------------------------------------------------------------------
    // T66: resolvedChallenges tracking increments per resolve
    // -------------------------------------------------------------------------
    function test_resolvedChallenges_tracking() public {
        uint256 id1 = _submitAndDispute();
        vm.prank(charlie);
        escrow.resolveDispute(id1, CloutEscrow.Outcome.CREATOR_WIN);
        assertEq(escrow.resolvedChallenges(charlie), 1);

        vm.prank(alice);
        uint256 id2 = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, charlie);
        vm.prank(bob);
        escrow.acceptChallenge(id2);
        vm.prank(alice);
        escrow.submitResult(id2, CloutEscrow.Outcome.CREATOR_WIN);
        vm.prank(bob);
        escrow.disputeResult(id2);

        vm.prank(charlie);
        escrow.resolveDispute(id2, CloutEscrow.Outcome.DRAW);
        assertEq(escrow.resolvedChallenges(charlie), 2);
    }

    // -------------------------------------------------------------------------
    // T67: resolveDispute — admin blocked when resolver is set (before and after timeout)
    // -------------------------------------------------------------------------
    function test_resolveDispute_admin_blocked_when_resolver_set() public {
        uint256 id = _submitAndDispute();
        (, , , , , , , , , , , , , uint256 disputedAt, , , , ) = escrow.challenges(id);

        // Admin blocked within 48h
        vm.expectRevert(CloutEscrow.NotResolver.selector);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);

        // Admin still blocked after timeout — must use resolveDisputeAsAdmin
        vm.warp(disputedAt + escrow.VOID_TIMEOUT() + 1);
        vm.expectRevert(CloutEscrow.NotResolver.selector);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);
    }

    // -------------------------------------------------------------------------
    // T68: resolveDispute — reverts on Outcome.NONE (InvalidOutcome)
    // -------------------------------------------------------------------------
    function test_resolveDispute_revertsOnNoneOutcome() public {
        uint256 id = _submitAndDispute();

        vm.prank(charlie);
        vm.expectRevert(CloutEscrow.InvalidOutcome.selector);
        escrow.resolveDispute(id, CloutEscrow.Outcome.NONE);
    }

    // =========================================================================
    // NC-007: appealResolution, finalizeResolution, adminFinalizeAppeal,
    //         voidByAdminTimeout
    // =========================================================================

    // -------------------------------------------------------------------------
    // NC-007 Test 1: finalizeResolution — success after 24h with no appeal
    // -------------------------------------------------------------------------
    function test_finalizeResolution_success() public {
        uint256 id = _submitDisputeAndResolve();
        (, , , , , , , , , , , , , , uint256 resolvedAt, , , ) = escrow.challenges(id);

        vm.warp(resolvedAt + escrow.SUBMISSION_TIMEOUT() + 1);

        vm.expectEmit(true, false, false, true);
        emit ResolutionFinalized(id, CloutEscrow.Outcome.CREATOR_WIN, block.timestamp);

        vm.prank(dave);
        escrow.finalizeResolution(id);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.FINALIZED));
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 2: finalizeResolution — reverts before 24h timeout
    // -------------------------------------------------------------------------
    function test_finalizeResolution_revertBeforeTimeout() public {
        uint256 id = _submitDisputeAndResolve();
        (, , , , , , , , , , , , , , uint256 resolvedAt, , , ) = escrow.challenges(id);

        vm.warp(resolvedAt + escrow.SUBMISSION_TIMEOUT() - 1);

        vm.expectRevert(CloutEscrow.TimeoutNotExpired.selector);
        escrow.finalizeResolution(id);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 3: finalizeResolution — reverts when appeal is pending
    // -------------------------------------------------------------------------
    function test_finalizeResolution_revertIfAppealed() public {
        uint256 id = _submitDisputeAndResolve();
        (, , , , , , , , , , , , , , uint256 resolvedAt, , , ) = escrow.challenges(id);

        vm.prank(alice);
        escrow.appealResolution(id);

        vm.warp(resolvedAt + escrow.SUBMISSION_TIMEOUT() + 1);

        vm.expectRevert(CloutEscrow.AppealPending.selector);
        escrow.finalizeResolution(id);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 4: appealResolution — reverts after 24h window closes
    // -------------------------------------------------------------------------
    function test_appealResolution_revertAfterWindow() public {
        uint256 id = _submitDisputeAndResolve();
        (, , , , , , , , , , , , , , uint256 resolvedAt, , , ) = escrow.challenges(id);

        vm.warp(resolvedAt + escrow.SUBMISSION_TIMEOUT() + 1);

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.AppealWindowExpired.selector);
        escrow.appealResolution(id);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 5: appealResolution — creator can appeal; fields set; event emitted
    // -------------------------------------------------------------------------
    function test_appealResolution_creatorCanAppeal() public {
        uint256 id = _submitDisputeAndResolve();

        vm.expectEmit(true, true, false, true);
        emit ResolutionAppealed(id, alice, block.timestamp);

        vm.prank(alice);
        escrow.appealResolution(id);

        (, , , , , , , , , , , , , , , , bool appealed, uint256 appealedAt) = escrow.challenges(id);
        assertEq(appealed, true);
        assertEq(appealedAt, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 6: appealResolution — opponent can appeal
    // -------------------------------------------------------------------------
    function test_appealResolution_opponentCanAppeal() public {
        uint256 id = _submitDisputeAndResolve();

        vm.expectEmit(true, true, false, true);
        emit ResolutionAppealed(id, bob, block.timestamp);

        vm.prank(bob);
        escrow.appealResolution(id);

        (, , , , , , , , , , , , , , , , bool appealed, uint256 appealedAt) = escrow.challenges(id);
        assertEq(appealed, true);
        assertEq(appealedAt, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 7: appealResolution — reverts for non-participant
    // -------------------------------------------------------------------------
    function test_appealResolution_revertNotParticipant() public {
        uint256 id = _submitDisputeAndResolve();

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.NotParticipant.selector);
        escrow.appealResolution(id);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 8: appealResolution — reverts when already appealed
    // -------------------------------------------------------------------------
    function test_appealResolution_revertAlreadyAppealed() public {
        uint256 id = _submitDisputeAndResolve();

        vm.prank(alice);
        escrow.appealResolution(id);

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.AlreadyAppealed.selector);
        escrow.appealResolution(id);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 9: adminFinalizeAppeal — success; admin overrides outcome
    // -------------------------------------------------------------------------
    function test_adminFinalizeAppeal_success() public {
        uint256 id = _submitDisputeAndResolve();

        vm.prank(alice);
        escrow.appealResolution(id);

        vm.expectEmit(true, false, false, true);
        emit ResolutionFinalized(id, CloutEscrow.Outcome.OPPONENT_WIN, block.timestamp);

        escrow.adminFinalizeAppeal(id, CloutEscrow.Outcome.OPPONENT_WIN);

        (, , , , , CloutEscrow.ChallengeState state, , , CloutEscrow.Outcome result, , , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.FINALIZED));
        assertEq(uint256(result), uint256(CloutEscrow.Outcome.OPPONENT_WIN));
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 10: adminFinalizeAppeal — reverts when no appeal filed
    // -------------------------------------------------------------------------
    function test_adminFinalizeAppeal_revertNoAppeal() public {
        uint256 id = _submitDisputeAndResolve();

        vm.expectRevert(CloutEscrow.NoAppeal.selector);
        escrow.adminFinalizeAppeal(id, CloutEscrow.Outcome.CREATOR_WIN);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 11: adminFinalizeAppeal — reverts for non-admin
    // -------------------------------------------------------------------------
    function test_adminFinalizeAppeal_revertNotAdmin() public {
        uint256 id = _submitDisputeAndResolve();

        vm.prank(alice);
        escrow.appealResolution(id);

        vm.prank(dave);
        vm.expectRevert();
        escrow.adminFinalizeAppeal(id, CloutEscrow.Outcome.CREATOR_WIN);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 12: voidByAdminTimeout — success; state VOIDED; claimWinnings refunds both; stats updated
    // -------------------------------------------------------------------------
    function test_voidByAdminTimeout_success() public {
        uint256 id = _submitDisputeAndResolve();

        vm.prank(alice);
        escrow.appealResolution(id);

        (, , , , , , , , , , , , , , , , , uint256 appealedAt) = escrow.challenges(id);

        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore = token.balanceOf(bob);

        vm.warp(appealedAt + escrow.VOID_TIMEOUT() + 1);

        vm.expectEmit(true, false, false, true);
        emit ChallengeVoidedByAdminTimeout(id, block.timestamp);

        vm.prank(dave);
        escrow.voidByAdminTimeout(id);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , , bool claimedBefore, , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.VOIDED));
        // claimed is not set by voidByAdminTimeout — only by claimWinnings
        assertEq(claimedBefore, false);

        // claimWinnings settles refunds and updates stats
        vm.prank(alice);
        escrow.claimWinnings(id);

        (, , , , , , , , , , , , , , , bool claimed, , ) = escrow.challenges(id);
        assertEq(claimed, true);
        assertEq(token.balanceOf(alice), aliceBefore + STAKE);
        assertEq(token.balanceOf(bob), bobBefore + STAKE);

        (, uint256 aliceCompleted, , , , , ) = escrow.walletRecords(alice);
        (, uint256 bobCompleted, , , , , ) = escrow.walletRecords(bob);
        assertEq(aliceCompleted, 1);
        assertEq(bobCompleted, 1);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 13: voidByAdminTimeout — reverts when no appeal filed
    // -------------------------------------------------------------------------
    function test_voidByAdminTimeout_revertNoAppeal() public {
        uint256 id = _submitDisputeAndResolve();
        (, , , , , , , , , , , , , , uint256 resolvedAt, , , ) = escrow.challenges(id);

        vm.warp(resolvedAt + escrow.VOID_TIMEOUT() + 1);

        vm.expectRevert(CloutEscrow.NoAppeal.selector);
        escrow.voidByAdminTimeout(id);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 14: voidByAdminTimeout — reverts before 48h from appealedAt
    // -------------------------------------------------------------------------
    function test_voidByAdminTimeout_revertBefore48h() public {
        uint256 id = _submitDisputeAndResolve();

        vm.prank(alice);
        escrow.appealResolution(id);

        (, , , , , , , , , , , , , , , , , uint256 appealedAt) = escrow.challenges(id);

        vm.warp(appealedAt + escrow.VOID_TIMEOUT() - 1);

        vm.expectRevert(CloutEscrow.TimeoutNotExpired.selector);
        escrow.voidByAdminTimeout(id);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 15: admin acts before timeout; subsequent voidByAdminTimeout reverts
    // -------------------------------------------------------------------------
    function test_adminActsBeforeTimeout() public {
        uint256 id = _submitDisputeAndResolve();

        vm.prank(alice);
        escrow.appealResolution(id);

        escrow.adminFinalizeAppeal(id, CloutEscrow.Outcome.CREATOR_WIN);

        (, , , , , CloutEscrow.ChallengeState state, , , , , , , , , , , , ) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.FINALIZED));

        (, , , , , , , , , , , , , , , , , uint256 appealedAt) = escrow.challenges(id);
        vm.warp(appealedAt + escrow.VOID_TIMEOUT() + 1);

        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.voidByAdminTimeout(id);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 16: appealResolution — reverts from wrong state (DISPUTED)
    // -------------------------------------------------------------------------
    function test_appealResolution_revertWrongState() public {
        uint256 id = _submitAndDispute();

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.appealResolution(id);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 17: adminFinalizeAppeal — reverts after 48h from appealedAt
    // -------------------------------------------------------------------------
    function test_adminFinalizeAppeal_revertAfterTimeout() public {
        uint256 id = _submitDisputeAndResolve();

        vm.prank(alice);
        escrow.appealResolution(id);

        (, , , , , , , , , , , , , , , , , uint256 appealedAt) = escrow.challenges(id);

        vm.warp(appealedAt + escrow.VOID_TIMEOUT() + 1);

        vm.expectRevert(CloutEscrow.AdminTimeoutExpired.selector);
        escrow.adminFinalizeAppeal(id, CloutEscrow.Outcome.CREATOR_WIN);
    }

    // -------------------------------------------------------------------------
    // NC-007 Test 18: appealResolution — reverts when admin resolved in admin-only mode
    // -------------------------------------------------------------------------
    function test_appealResolution_revertAdminOnlyMode() public {
        // Create challenge with no designated resolver (admin-only mode)
        vm.prank(alice);
        uint256 id = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));
        vm.prank(bob);
        escrow.acceptChallenge(id);
        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        vm.prank(bob);
        escrow.disputeResult(id);

        // Admin resolves via the admin-only path in resolveDispute
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);

        // Neither participant may appeal an admin-only resolution — it is final
        vm.prank(bob);
        vm.expectRevert(CloutEscrow.AppealNotAllowed.selector);
        escrow.appealResolution(id);

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.AppealNotAllowed.selector);
        escrow.appealResolution(id);
    }

    // =========================================================================
    // NC-009: getWalletRecord view and integration hardening
    // =========================================================================

    // -------------------------------------------------------------------------
    // NC-009 Test 1: getWalletRecord returns correct struct for all 7 fields
    // -------------------------------------------------------------------------
    function test_NC009_getWalletRecord_returnsCorrectStruct() public {
        vm.prank(alice);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, charlie);

        CloutEscrow.WalletRecord memory r = escrow.getWalletRecord(alice);
        assertEq(r.challengesEntered,   1);
        assertEq(r.challengesCompleted, 0);
        assertEq(r.challengesWon,       0);
        assertEq(r.challengesDisputed,  0);
        assertEq(r.totalStaked,         STAKE);
        assertEq(r.firstChallengeAt,    block.timestamp);
        assertEq(r.lastChallengeAt,     block.timestamp);

        // bob has not acted — all fields should be zero
        CloutEscrow.WalletRecord memory rBob = escrow.getWalletRecord(bob);
        assertEq(rBob.challengesEntered,   0);
        assertEq(rBob.challengesCompleted, 0);
        assertEq(rBob.challengesWon,       0);
        assertEq(rBob.challengesDisputed,  0);
        assertEq(rBob.totalStaked,         0);
        assertEq(rBob.firstChallengeAt,    0);
        assertEq(rBob.lastChallengeAt,     0);
    }

    // -------------------------------------------------------------------------
    // NC-009 Test 2: full lifecycle — create → accept → submit → confirm → claim
    // -------------------------------------------------------------------------
    function test_NC009_walletRecord_lifecycle_creatorWinPath() public {
        uint256 t0 = block.timestamp;

        vm.prank(alice);
        uint256 id = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, charlie);

        // After create: alice entry stats set; bob untouched
        CloutEscrow.WalletRecord memory rA = escrow.getWalletRecord(alice);
        assertEq(rA.challengesEntered,   1);
        assertEq(rA.challengesCompleted, 0);
        assertEq(rA.challengesWon,       0);
        assertEq(rA.totalStaked,         STAKE);
        assertEq(rA.firstChallengeAt,    t0);
        assertEq(rA.lastChallengeAt,     t0);

        CloutEscrow.WalletRecord memory rB = escrow.getWalletRecord(bob);
        assertEq(rB.challengesEntered, 0);

        vm.prank(bob);
        escrow.acceptChallenge(id);

        // After accept: bob entry stats set
        rB = escrow.getWalletRecord(bob);
        assertEq(rB.challengesEntered,   1);
        assertEq(rB.challengesCompleted, 0);
        assertEq(rB.challengesWon,       0);
        assertEq(rB.totalStaked,         STAKE);
        assertEq(rB.firstChallengeAt,    t0);
        assertEq(rB.lastChallengeAt,     t0);

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        // submitResult does not mutate WalletRecord
        rA = escrow.getWalletRecord(alice);
        assertEq(rA.challengesCompleted, 0);

        vm.prank(bob);
        escrow.confirmResult(id);

        // confirmResult does not mutate WalletRecord
        rA = escrow.getWalletRecord(alice);
        assertEq(rA.challengesCompleted, 0);

        vm.prank(alice);
        escrow.claimWinnings(id);

        // After claim: completion stats updated for both
        rA = escrow.getWalletRecord(alice);
        assertEq(rA.challengesEntered,   1);
        assertEq(rA.challengesCompleted, 1);
        assertEq(rA.challengesWon,       1);

        rB = escrow.getWalletRecord(bob);
        assertEq(rB.challengesEntered,   1);
        assertEq(rB.challengesCompleted, 1);
        assertEq(rB.challengesWon,       0);
    }

    // -------------------------------------------------------------------------
    // NC-009 Test 3: firstChallengeAt set once; lastChallengeAt updates each entry
    // -------------------------------------------------------------------------
    function test_NC009_walletRecord_multiChallenge_entryTimestamps() public {
        vm.prank(alice);
        uint256 id1 = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));

        // Read firstChallengeAt from storage after first create (avoids via_ir CSE issue)
        CloutEscrow.WalletRecord memory rA = escrow.getWalletRecord(alice);
        uint256 aliceFirstTs = rA.firstChallengeAt;
        assertEq(rA.challengesEntered, 1);
        assertEq(rA.totalStaked,       STAKE);
        assertEq(rA.firstChallengeAt,  aliceFirstTs);
        assertEq(rA.lastChallengeAt,   aliceFirstTs);

        vm.warp(block.timestamp + 1 days);
        uint256 t1 = block.timestamp;

        vm.prank(alice);
        uint256 id2 = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));

        // After second create: firstChallengeAt unchanged; lastChallengeAt = t1
        rA = escrow.getWalletRecord(alice);
        assertEq(rA.challengesEntered, 2);
        assertEq(rA.totalStaked,       2 * STAKE);
        assertEq(rA.firstChallengeAt,  aliceFirstTs);   // UNCHANGED (storage-read reference)
        assertEq(rA.lastChallengeAt,   t1);             // updated

        vm.prank(bob);
        escrow.acceptChallenge(id1);

        // bob's first action: read firstChallengeAt from storage (same avoidance pattern)
        CloutEscrow.WalletRecord memory rB = escrow.getWalletRecord(bob);
        uint256 bobFirstTs = rB.firstChallengeAt;
        assertEq(rB.challengesEntered, 1);
        assertEq(rB.totalStaked,       STAKE);
        assertEq(rB.firstChallengeAt,  bobFirstTs);
        assertEq(rB.lastChallengeAt,   bobFirstTs);

        vm.warp(block.timestamp + 1 hours);
        uint256 t2 = block.timestamp;

        vm.prank(bob);
        escrow.acceptChallenge(id2);

        // bob's second action: firstChallengeAt unchanged; lastChallengeAt = t2
        rB = escrow.getWalletRecord(bob);
        assertEq(rB.challengesEntered, 2);
        assertEq(rB.totalStaked,       2 * STAKE);
        assertEq(rB.firstChallengeAt,  bobFirstTs);   // UNCHANGED (storage-read reference)
        assertEq(rB.lastChallengeAt,   t2);           // updated
    }

    // -------------------------------------------------------------------------
    // NC-009 Test 4: disputeResult increments challengesDisputed; DRAW path
    // -------------------------------------------------------------------------
    function test_NC009_walletRecord_lifecycle_disputeAndDrawPath() public {
        // Part A: dispute → resolve → finalize → claim (CREATOR_WIN)
        uint256 id = _submitAndDispute();

        // challengesDisputed incremented for bob (disputer), not alice
        CloutEscrow.WalletRecord memory rB = escrow.getWalletRecord(bob);
        assertEq(rB.challengesDisputed, 1);
        CloutEscrow.WalletRecord memory rA = escrow.getWalletRecord(alice);
        assertEq(rA.challengesDisputed, 0);

        vm.prank(charlie);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);

        // Warp past 24h appeal window then finalize
        (, , , , , , , , , , , , , uint256 resolvedAt, , , , ) = escrow.challenges(id);
        vm.warp(resolvedAt + escrow.SUBMISSION_TIMEOUT() + 1);
        escrow.finalizeResolution(id);

        vm.prank(alice);
        escrow.claimWinnings(id);

        // After claim
        rA = escrow.getWalletRecord(alice);
        assertEq(rA.challengesEntered,   1);
        assertEq(rA.challengesCompleted, 1);
        assertEq(rA.challengesWon,       1);
        assertEq(rA.challengesDisputed,  0);

        rB = escrow.getWalletRecord(bob);
        assertEq(rB.challengesEntered,   1);
        assertEq(rB.challengesCompleted, 1);
        assertEq(rB.challengesWon,       0);
        assertEq(rB.challengesDisputed,  1);

        // Part B: DRAW outcome
        vm.prank(alice);
        uint256 id2 = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));
        vm.prank(bob);
        escrow.acceptChallenge(id2);
        vm.prank(alice);
        escrow.submitResult(id2, CloutEscrow.Outcome.DRAW);
        vm.prank(bob);
        escrow.confirmResult(id2);
        vm.prank(bob);
        escrow.claimWinnings(id2);

        // After DRAW claim: completed++ for both, won unchanged
        rA = escrow.getWalletRecord(alice);
        assertEq(rA.challengesEntered,   2);
        assertEq(rA.challengesCompleted, 2);
        assertEq(rA.challengesWon,       1);   // still only from Part A

        rB = escrow.getWalletRecord(bob);
        assertEq(rB.challengesEntered,   2);
        assertEq(rB.challengesCompleted, 2);
        assertEq(rB.challengesWon,       0);   // DRAW does not count as won
    }
}
