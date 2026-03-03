// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CloutEscrow} from "../src/CloutEscrow.sol";
import {MockStablecoin} from "../src/MockStablecoin.sol";

contract CloutEscrowNC010Test is Test {
    // Re-declared events for vm.expectEmit
    event ChallengeFinalizedByTimeout(uint256 indexed, CloutEscrow.Outcome, uint256);
    event ResolutionFinalized(uint256 indexed, CloutEscrow.Outcome, uint256);
    event ChallengeVoidedByAdminTimeout(uint256 indexed, uint256);
    event WinningsClaimed(uint256 indexed, CloutEscrow.Outcome, uint256, uint256, uint256);
    event ChallengeVoided(uint256 indexed, address indexed, uint256);

    CloutEscrow escrow;
    MockStablecoin token;

    address admin    = address(this);
    address alice    = address(0xA11CE);
    address bob      = address(0xB0B);
    address charlie  = address(0xC4A1);
    address dave     = address(0xDA7E);
    address treasury = address(0xFEE1);

    uint256 constant STAKE       = 100e6;
    uint256 constant SMALL_STAKE = 21;
    // forge-lint: disable-next-line(unsafe-typecast)
    bytes32 constant GAME_ID     = bytes32("game-nc010");

    uint256 constant EXPECTED_FEE       = 5_000_000;
    uint256 constant CREATOR_WIN_PAYOUT = 195_000_000;
    uint256 constant DRAW_EACH          = 97_500_000;

    function setUp() public {
        token = new MockStablecoin();
        escrow = new CloutEscrow();
        escrow.addWhitelistedToken(address(token));
        escrow.setTreasury(treasury);

        token.mint(alice,   10_000e6);
        token.mint(bob,     10_000e6);
        token.mint(charlie, 10_000e6);
        token.mint(dave,    10_000e6);

        vm.prank(alice);
        token.approve(address(escrow), type(uint256).max);
        vm.prank(bob);
        token.approve(address(escrow), type(uint256).max);
    }

    // ─── Internal Helpers ────────────────────────────────────────────────────

    function _createDefault() internal returns (uint256) {
        vm.prank(alice);
        return escrow.createChallenge(bob, STAKE, address(token), GAME_ID, charlie);
    }

    function _createDefaultNoResolver() internal returns (uint256) {
        vm.prank(alice);
        return escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));
    }

    function _createAndAccept() internal returns (uint256) {
        uint256 id = _createDefault();
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

    function _submitDisputeAndResolve() internal returns (uint256) {
        uint256 id = _submitAndDispute();
        vm.prank(charlie);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);
        return id;
    }

    // ─── Group 1: Integration Happy Path Tests ────────────────────────────────

    function test_integration_happyPath_creatorWin() public {
        uint256 aliceBefore    = token.balanceOf(alice);
        uint256 bobBefore      = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        vm.prank(alice);
        uint256 id = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, charlie);
        assertEq(token.balanceOf(address(escrow)), STAKE);

        vm.prank(bob);
        escrow.acceptChallenge(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(bob);
        escrow.confirmResult(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.expectEmit(true, false, false, true);
        emit WinningsClaimed(id, CloutEscrow.Outcome.CREATOR_WIN, 195_000_000, 0, 5_000_000);
        vm.prank(bob);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);

        assertEq(token.balanceOf(alice),    aliceBefore - STAKE + 195_000_000);
        assertEq(token.balanceOf(bob),      bobBefore - STAKE);
        assertEq(token.balanceOf(treasury), treasuryBefore + 5_000_000);

        (,,,,, CloutEscrow.ChallengeState state, ,,,,,,,,,,,) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.FINALIZED));
        (,,,,,,,,,,,,,,, bool claimed, ,) = escrow.challenges(id);
        assertEq(claimed, true);
    }

    function test_integration_happyPath_opponentWin() public {
        uint256 aliceBefore    = token.balanceOf(alice);
        uint256 bobBefore      = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 id = _createDefault();
        assertEq(token.balanceOf(address(escrow)), STAKE);

        vm.prank(bob);
        escrow.acceptChallenge(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(bob);
        escrow.submitResult(id, CloutEscrow.Outcome.OPPONENT_WIN);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.confirmResult(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);

        assertEq(token.balanceOf(alice),    aliceBefore - STAKE);
        assertEq(token.balanceOf(bob),      bobBefore - STAKE + 195_000_000);
        assertEq(token.balanceOf(treasury), treasuryBefore + 5_000_000);
    }

    function test_integration_happyPath_draw() public {
        // Part A: Standard DRAW with STAKE = 100e6 (no rounding)
        uint256 aliceBefore    = token.balanceOf(alice);
        uint256 bobBefore      = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 id = _createDefault();
        assertEq(token.balanceOf(address(escrow)), STAKE);

        vm.prank(bob);
        escrow.acceptChallenge(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.DRAW);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(bob);
        escrow.confirmResult(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);

        assertEq(token.balanceOf(alice),    aliceBefore - STAKE + 97_500_000);
        assertEq(token.balanceOf(bob),      bobBefore   - STAKE + 97_500_000);
        assertEq(token.balanceOf(treasury), treasuryBefore + 5_000_000);

        // Part B: DRAW with SMALL_STAKE = 21 — verify rounding
        // fee=1, remaining=41, creatorPayout=21, opponentPayout=20
        vm.prank(alice);
        uint256 id2 = escrow.createChallenge(bob, SMALL_STAKE, address(token), GAME_ID, address(0));
        assertEq(token.balanceOf(address(escrow)), SMALL_STAKE);

        vm.prank(bob);
        escrow.acceptChallenge(id2);
        assertEq(token.balanceOf(address(escrow)), 2 * SMALL_STAKE);

        vm.prank(alice);
        escrow.submitResult(id2, CloutEscrow.Outcome.DRAW);
        assertEq(token.balanceOf(address(escrow)), 2 * SMALL_STAKE);

        vm.prank(bob);
        escrow.confirmResult(id2);
        assertEq(token.balanceOf(address(escrow)), 2 * SMALL_STAKE);

        uint256 aliceBefore2    = token.balanceOf(alice);
        uint256 bobBefore2      = token.balanceOf(bob);
        uint256 treasuryBefore2 = token.balanceOf(treasury);

        vm.prank(alice);
        escrow.claimWinnings(id2);
        assertEq(token.balanceOf(address(escrow)), 0);

        assertEq(token.balanceOf(alice),    aliceBefore2 + 21);
        assertEq(token.balanceOf(bob),      bobBefore2 + 20);
        assertEq(token.balanceOf(treasury), treasuryBefore2 + 1);
    }

    function test_integration_happyPath_invalid() public {
        uint256 aliceBefore    = token.balanceOf(alice);
        uint256 bobBefore      = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 id = _createAndAccept();
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(bob);
        escrow.disputeResult(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(charlie);
        escrow.resolveDispute(id, CloutEscrow.Outcome.INVALID);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        (,,,,,,,,,,,,,, uint256 resolvedAt, ,,) = escrow.challenges(id);
        vm.warp(resolvedAt + escrow.SUBMISSION_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.finalizeResolution(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);

        assertEq(token.balanceOf(alice),    aliceBefore);
        assertEq(token.balanceOf(bob),      bobBefore);
        assertEq(token.balanceOf(treasury), treasuryBefore);
    }

    function test_integration_happyPath_voidFromCreated() public {
        uint256 aliceBefore    = token.balanceOf(alice);
        uint256 bobBefore      = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        vm.prank(alice);
        uint256 id = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));
        assertEq(token.balanceOf(address(escrow)), STAKE);

        (,,,,,,,,,, uint256 createdAt, ,,,,,,) = escrow.challenges(id);
        vm.warp(createdAt + escrow.VOID_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.voidChallenge(id);
        assertEq(token.balanceOf(address(escrow)), STAKE);

        vm.prank(alice);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);

        assertEq(token.balanceOf(alice),    aliceBefore);
        assertEq(token.balanceOf(bob),      bobBefore);
        assertEq(token.balanceOf(treasury), treasuryBefore);
    }

    // ─── Group 2: Dispute and Appeal Path Integration Tests ──────────────────

    function test_integration_disputePath_resolverResolves() public {
        uint256 aliceBefore    = token.balanceOf(alice);
        uint256 bobBefore      = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 id = _createDefault();
        assertEq(token.balanceOf(address(escrow)), STAKE);

        vm.prank(bob);
        escrow.acceptChallenge(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(bob);
        escrow.disputeResult(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(charlie);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        (,,,,,,,,,,,,,, uint256 resolvedAt, ,,) = escrow.challenges(id);
        vm.warp(resolvedAt + escrow.SUBMISSION_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.finalizeResolution(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);

        assertEq(token.balanceOf(alice),    aliceBefore - STAKE + 195_000_000);
        assertEq(token.balanceOf(bob),      bobBefore - STAKE);
        assertEq(token.balanceOf(treasury), treasuryBefore + 5_000_000);
    }

    function test_integration_appealPath_adminDecides() public {
        uint256 aliceBefore    = token.balanceOf(alice);
        uint256 bobBefore      = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 id = _createAndAccept();
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(bob);
        escrow.disputeResult(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(charlie);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(bob);
        escrow.appealResolution(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        escrow.adminFinalizeAppeal(id, CloutEscrow.Outcome.OPPONENT_WIN);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(bob);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);

        assertEq(token.balanceOf(alice),    aliceBefore - STAKE);
        assertEq(token.balanceOf(bob),      bobBefore - STAKE + 195_000_000);
        assertEq(token.balanceOf(treasury), treasuryBefore + 5_000_000);
    }

    // ─── Group 3: All 6 Timeout Tests ────────────────────────────────────────

    function test_timeout_48h_create() public {
        uint256 aliceBefore = token.balanceOf(alice);

        vm.prank(alice);
        uint256 id = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));
        assertEq(token.balanceOf(address(escrow)), STAKE);

        (,,,,,,,,,, uint256 createdAt, ,,,,,,) = escrow.challenges(id);

        vm.warp(createdAt + escrow.VOID_TIMEOUT() - 1);
        vm.expectRevert(CloutEscrow.TimeoutNotExpired.selector);
        vm.prank(dave);
        escrow.voidChallenge(id);

        vm.warp(createdAt + escrow.VOID_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.voidChallenge(id);
        assertEq(token.balanceOf(address(escrow)), STAKE);

        vm.prank(alice);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);
        assertEq(token.balanceOf(alice), aliceBefore);
    }

    function test_timeout_48h_accept() public {
        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore   = token.balanceOf(bob);

        uint256 id = _createAndAccept();
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        (,,,,,,,,,,, uint256 acceptedAt, ,,,,,) = escrow.challenges(id);
        vm.warp(acceptedAt + escrow.VOID_TIMEOUT() + 1);

        vm.prank(dave);
        vm.expectRevert(CloutEscrow.NotParticipant.selector);
        escrow.voidChallenge(id);

        vm.prank(alice);
        escrow.voidChallenge(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(bob);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);

        assertEq(token.balanceOf(alice), aliceBefore);
        assertEq(token.balanceOf(bob),   bobBefore);
    }

    function test_timeout_24h_confirmAutoAccept() public {
        uint256 aliceBefore    = token.balanceOf(alice);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 id = _createAndAccept();
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        (,,,,,,,,,,,, uint256 submittedAt, ,,,,) = escrow.challenges(id);
        vm.warp(submittedAt + escrow.SUBMISSION_TIMEOUT() + 1);

        vm.expectEmit(true, false, false, true);
        emit ChallengeFinalizedByTimeout(id, CloutEscrow.Outcome.CREATOR_WIN, block.timestamp);
        vm.prank(dave);
        escrow.finalizeSubmission(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);

        assertEq(token.balanceOf(alice),    aliceBefore - STAKE + 195_000_000);
        assertEq(token.balanceOf(treasury), treasuryBefore + 5_000_000);
    }

    function test_timeout_48h_resolverFallback() public {
        uint256 aliceBefore    = token.balanceOf(alice);
        uint256 bobBefore      = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 id = _submitAndDispute();
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        (,,,,,,,,,,,,, uint256 disputedAt, ,,,) = escrow.challenges(id);
        vm.warp(disputedAt + escrow.VOID_TIMEOUT() + 1);

        escrow.resolveDisputeAsAdmin(id, CloutEscrow.Outcome.OPPONENT_WIN);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        (,,,,,,,,,,,,,, uint256 resolvedAt, ,,) = escrow.challenges(id);
        vm.warp(resolvedAt + escrow.SUBMISSION_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.finalizeResolution(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(bob);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);

        assertEq(token.balanceOf(alice),    aliceBefore - STAKE);
        assertEq(token.balanceOf(bob),      bobBefore - STAKE + 195_000_000);
        assertEq(token.balanceOf(treasury), treasuryBefore + 5_000_000);
    }

    function test_timeout_24h_appealWindow() public {
        uint256 aliceBefore    = token.balanceOf(alice);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 id = _submitDisputeAndResolve();
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        (,,,,,,,,,,,,,, uint256 resolvedAt, ,,) = escrow.challenges(id);
        vm.warp(resolvedAt + escrow.SUBMISSION_TIMEOUT() + 1);

        vm.expectEmit(true, false, false, true);
        emit ResolutionFinalized(id, CloutEscrow.Outcome.CREATOR_WIN, block.timestamp);
        vm.prank(dave);
        escrow.finalizeResolution(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);

        assertEq(token.balanceOf(alice),    aliceBefore - STAKE + 195_000_000);
        assertEq(token.balanceOf(treasury), treasuryBefore + 5_000_000);
    }

    function test_timeout_48h_adminTimeout() public {
        uint256 aliceBefore    = token.balanceOf(alice);
        uint256 bobBefore      = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 id = _submitDisputeAndResolve();
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.appealResolution(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        (,,,,,,,,,,,,,,,,, uint256 appealedAt) = escrow.challenges(id);
        vm.warp(appealedAt + escrow.VOID_TIMEOUT() + 1);

        vm.expectEmit(true, false, false, true);
        emit ChallengeVoidedByAdminTimeout(id, block.timestamp);
        vm.prank(dave);
        escrow.voidByAdminTimeout(id);
        assertEq(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);

        assertEq(token.balanceOf(alice),    aliceBefore);
        assertEq(token.balanceOf(bob),      bobBefore);
        assertEq(token.balanceOf(treasury), treasuryBefore);
    }

    // ─── Group 4: Edge Cases ──────────────────────────────────────────────────

    function test_edgeCase_doubleClaim() public {
        uint256 id = _createAndAccept();
        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        vm.prank(bob);
        escrow.confirmResult(id);
        vm.prank(alice);
        escrow.claimWinnings(id);

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.AlreadyClaimed.selector);
        escrow.claimWinnings(id);

        vm.prank(bob);
        vm.expectRevert(CloutEscrow.AlreadyClaimed.selector);
        escrow.claimWinnings(id);
    }

    function test_edgeCase_zeroStake() public {
        vm.prank(alice);
        vm.expectRevert(CloutEscrow.ZeroStake.selector);
        escrow.createChallenge(bob, 0, address(token), GAME_ID, charlie);
    }

    // ─── Group 5: Named Invariant Tests ──────────────────────────────────────

    function test_invariant_I1_solvency() public {
        assertEq(token.balanceOf(address(escrow)), 0);

        vm.prank(alice);
        uint256 id = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, charlie);
        assertGe(token.balanceOf(address(escrow)), STAKE);

        vm.prank(bob);
        escrow.acceptChallenge(id);
        assertGe(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        assertGe(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(bob);
        escrow.disputeResult(id);
        assertGe(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(charlie);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);
        assertGe(token.balanceOf(address(escrow)), 2 * STAKE);

        (,,,,,,,,,,,,,, uint256 resolvedAt, ,,) = escrow.challenges(id);
        vm.warp(resolvedAt + escrow.SUBMISSION_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.finalizeResolution(id);
        assertGe(token.balanceOf(address(escrow)), 2 * STAKE);

        vm.prank(alice);
        escrow.claimWinnings(id);
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    function test_invariant_I2_submitterCannotDispute() public {
        // Case A: alice submits → alice cannot dispute
        uint256 id = _createAndAccept();
        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        vm.prank(alice);
        vm.expectRevert(CloutEscrow.CallerIsSubmitter.selector);
        escrow.disputeResult(id);

        // Case B: bob submits → bob cannot dispute
        uint256 id2 = _createAndAccept();
        vm.prank(bob);
        escrow.submitResult(id2, CloutEscrow.Outcome.OPPONENT_WIN);
        vm.prank(bob);
        vm.expectRevert(CloutEscrow.CallerIsSubmitter.selector);
        escrow.disputeResult(id2);
    }

    function test_invariant_I3_resolverNotParticipant() public {
        // resolver == creator → ResolverIsCreator
        vm.prank(alice);
        vm.expectRevert(CloutEscrow.ResolverIsCreator.selector);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, alice);

        // resolver == opponent → ResolverIsOpponent
        vm.prank(alice);
        vm.expectRevert(CloutEscrow.ResolverIsOpponent.selector);
        escrow.createChallenge(bob, STAKE, address(token), GAME_ID, bob);
    }

    function test_invariant_I4_payoutCorrectness() public {
        // Part A: DRAW rounding — SMALL_STAKE=21 → fee=1, creatorPayout=21, opponentPayout=20
        vm.prank(alice);
        uint256 idA = escrow.createChallenge(bob, SMALL_STAKE, address(token), GAME_ID, address(0));
        vm.prank(bob);
        escrow.acceptChallenge(idA);
        vm.prank(alice);
        escrow.submitResult(idA, CloutEscrow.Outcome.DRAW);
        vm.prank(bob);
        escrow.confirmResult(idA);

        uint256 aliceBefore  = token.balanceOf(alice);
        uint256 bobBefore    = token.balanceOf(bob);
        uint256 treasBefore  = token.balanceOf(treasury);

        vm.prank(alice);
        escrow.claimWinnings(idA);
        assertEq(token.balanceOf(alice),    aliceBefore + 21);
        assertEq(token.balanceOf(bob),      bobBefore + 20);
        assertEq(token.balanceOf(treasury), treasBefore + 1);
        assertEq(token.balanceOf(address(escrow)), 0);

        // Part B: INVALID → full refund, no fee
        uint256 idB = _submitAndDispute();
        uint256 aliceBefore2 = token.balanceOf(alice);
        uint256 bobBefore2   = token.balanceOf(bob);
        uint256 treasBefore2 = token.balanceOf(treasury);

        vm.prank(charlie);
        escrow.resolveDispute(idB, CloutEscrow.Outcome.INVALID);
        (,,,,,,,,,,,,,, uint256 resolvedAtB, ,,) = escrow.challenges(idB);
        vm.warp(resolvedAtB + escrow.SUBMISSION_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.finalizeResolution(idB);

        vm.prank(alice);
        escrow.claimWinnings(idB);
        assertEq(token.balanceOf(alice),    aliceBefore2 + STAKE);
        assertEq(token.balanceOf(bob),      bobBefore2   + STAKE);
        assertEq(token.balanceOf(treasury), treasBefore2);
        assertEq(token.balanceOf(address(escrow)), 0);

        // Part C: VOIDED from CREATED state → creator-only refund, no fee
        vm.prank(alice);
        uint256 idC = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, address(0));
        (,,,,,,,,,, uint256 createdAtC, ,,,,,,) = escrow.challenges(idC);
        vm.warp(createdAtC + escrow.VOID_TIMEOUT() + 1);

        uint256 aliceBefore3 = token.balanceOf(alice);
        uint256 bobBefore3   = token.balanceOf(bob);
        uint256 treasBefore3 = token.balanceOf(treasury);

        vm.prank(dave);
        escrow.voidChallenge(idC);
        vm.prank(alice);
        escrow.claimWinnings(idC);
        assertEq(token.balanceOf(alice),    aliceBefore3 + STAKE);
        assertEq(token.balanceOf(bob),      bobBefore3);
        assertEq(token.balanceOf(treasury), treasBefore3);
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    function test_invariant_I5_walletRecordTiming() public {
        uint256 id = _createAndAccept();

        CloutEscrow.WalletRecord memory rA = escrow.getWalletRecord(alice);
        assertEq(rA.challengesEntered, 1);
        assertEq(rA.challengesCompleted, 0);

        vm.prank(alice);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);
        rA = escrow.getWalletRecord(alice);
        assertEq(rA.challengesCompleted, 0);

        vm.prank(bob);
        escrow.confirmResult(id);
        rA = escrow.getWalletRecord(alice);
        assertEq(rA.challengesCompleted, 0);
        CloutEscrow.WalletRecord memory rB = escrow.getWalletRecord(bob);
        assertEq(rB.challengesCompleted, 0);

        vm.prank(alice);
        escrow.claimWinnings(id);
        rA = escrow.getWalletRecord(alice);
        assertEq(rA.challengesCompleted, 1);
        assertEq(rA.challengesWon, 1);
        rB = escrow.getWalletRecord(bob);
        assertEq(rB.challengesCompleted, 1);
        assertEq(rB.challengesWon, 0);
    }

    function test_invariant_I6_noStateSkip() public {
        vm.prank(alice);
        uint256 id = escrow.createChallenge(bob, STAKE, address(token), GAME_ID, charlie);

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.submitResult(id, CloutEscrow.Outcome.CREATOR_WIN);

        vm.prank(bob);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.confirmResult(id);

        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.finalizeSubmission(id);

        vm.prank(bob);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.disputeResult(id);

        vm.prank(charlie);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.resolveDispute(id, CloutEscrow.Outcome.CREATOR_WIN);

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.claimWinnings(id);

        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.finalizeResolution(id);

        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.voidByAdminTimeout(id);

        // Advance to ACCEPTED
        vm.prank(bob);
        escrow.acceptChallenge(id);

        vm.prank(bob);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.confirmResult(id);

        vm.prank(bob);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.disputeResult(id);

        vm.prank(alice);
        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.claimWinnings(id);

        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.finalizeResolution(id);

        vm.expectRevert(CloutEscrow.WrongState.selector);
        escrow.voidByAdminTimeout(id);
    }

    function test_invariant_I7_adminTimeoutNeverPicksWinner() public {
        uint256 aliceBefore    = token.balanceOf(alice);
        uint256 bobBefore      = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 id = _submitDisputeAndResolve();
        vm.prank(alice);
        escrow.appealResolution(id);

        (,,,,,,,,,,,,,,,,, uint256 appealedAt) = escrow.challenges(id);
        vm.warp(appealedAt + escrow.VOID_TIMEOUT() + 1);
        vm.prank(dave);
        escrow.voidByAdminTimeout(id);

        (,,,,, CloutEscrow.ChallengeState state, ,,,,,,,,,,,) = escrow.challenges(id);
        assertEq(uint256(state), uint256(CloutEscrow.ChallengeState.VOIDED));

        vm.prank(alice);
        escrow.claimWinnings(id);

        assertEq(token.balanceOf(alice),    aliceBefore);
        assertEq(token.balanceOf(bob),      bobBefore);
        assertEq(token.balanceOf(treasury), treasuryBefore);
        assertEq(token.balanceOf(address(escrow)), 0);

        CloutEscrow.WalletRecord memory rA = escrow.getWalletRecord(alice);
        CloutEscrow.WalletRecord memory rB = escrow.getWalletRecord(bob);
        assertEq(rA.challengesWon, 0);
        assertEq(rB.challengesWon, 0);
        assertEq(rA.challengesCompleted, 1);
        assertEq(rB.challengesCompleted, 1);
    }
}
