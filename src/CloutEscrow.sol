// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CloutEscrow is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // Enums
    // -------------------------------------------------------------------------

    enum ChallengeState { CREATED, ACCEPTED, SUBMITTED, DISPUTED, RESOLVED, FINALIZED, VOIDED }
    enum Outcome { NONE, CREATOR_WIN, OPPONENT_WIN, DRAW, INVALID }

    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    struct Challenge {
        address creator;
        address opponent;
        address designatedResolver;  // optional third-party resolver (zero = admin-only)
        address token;               // whitelisted stablecoin (USDT or USDC, 6 decimals)
        uint256 stakeAmount;         // amount in token units (6 decimals)
        ChallengeState state;
        bytes32 gameId;              // game type identifier
        bytes32 matchId;             // external match reference
        Outcome submittedResult;
        address submittedBy;
        uint256 createdAt;
        uint256 acceptedAt;
        uint256 submittedAt;         // when result was submitted (starts confirmation deadline)
        uint256 disputedAt;          // when dispute was triggered (starts resolver deadline)
        uint256 resolvedAt;          // when dispute was resolved (starts 24h appeal window for NC-007)
        bool claimed;                // true after settlement; set by voidChallenge or claimWinnings
        bool appealed;               // true if an appeal has been filed by creator or opponent
        uint256 appealedAt;          // timestamp when the appeal was filed (0 if no appeal)
    }

    struct WalletRecord {
        uint256 challengesEntered;     // incremented on both create and accept
        uint256 challengesCompleted;   // finalized (win or loss)
        uint256 challengesWon;
        uint256 challengesDisputed;
        uint256 totalStaked;           // cumulative USDC staked (6 decimals)
        uint256 firstChallengeAt;      // timestamp of first entry action (create or accept)
        uint256 lastChallengeAt;       // timestamp of most recent challenge
    }

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    uint256 public constant VOID_TIMEOUT = 172800; // 48 hours in seconds
    uint256 public constant SUBMISSION_TIMEOUT = 86400; // 24 hours in seconds

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    mapping(uint256 => Challenge) public challenges;
    uint256 public challengeCount;
    mapping(address => bool) private _whitelistedTokens;
    mapping(address => WalletRecord) public walletRecords;
    /// @notice Tracks how many disputes each resolver has resolved (for collusion detection).
    mapping(address => uint256) public resolvedChallenges;

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------

    error ZeroStake();
    error TokenNotWhitelisted();
    error OpponentIsZeroAddress();
    error OpponentIsCreator();
    error ResolverIsCreator();
    error ResolverIsOpponent();
    error NotOpponent();       // caller != challenge.opponent
    error WrongState();        // challenge not in required state
    error TimeoutNotExpired(); // 48h hasn't elapsed yet
    error NotParticipant();    // caller is not creator or opponent (ACCEPTED-void guard)
    error InvalidOutcome();    // submitter passed Outcome.NONE or Outcome.INVALID
    error CallerIsSubmitter(); // submitter attempts to call confirmResult
    error NotResolver();       // caller is not the designated resolver (when set) or admin (when no resolver)
    error ResolverTimedOut();  // designated resolver attempts to act after 48h window
    error AppealWindowExpired();   // appealResolution called after resolvedAt + 24h
    error AlreadyAppealed();       // appealResolution called when c.appealed == true
    error NoAppeal();              // adminFinalizeAppeal or voidByAdminTimeout when c.appealed == false
    error AppealPending();         // finalizeResolution called when c.appealed == true
    error AdminTimeoutExpired();   // adminFinalizeAppeal called after appealedAt + 48h
    error AppealNotAllowed();      // appealResolution called when designatedResolver == address(0); admin decisions are final

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

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
    event TokenWhitelisted(address indexed token);
    event TokenDelisted(address indexed token);
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
    event ResultSubmitted(
        uint256 indexed challengeId,
        address indexed submitter,
        Outcome outcome,
        uint256 submittedAt
    );
    event ResultConfirmed(
        uint256 indexed challengeId,
        address indexed confirmer,
        Outcome outcome
    );
    event ChallengeFinalizedByTimeout(
        uint256 indexed challengeId,
        Outcome outcome,
        uint256 finalizedAt
    );
    event ResultDisputed(
        uint256 indexed challengeId,
        address indexed disputer,
        uint256 disputedAt
    );
    event DisputeResolved(
        uint256 indexed challengeId,
        address indexed resolver,
        Outcome outcome,
        uint256 resolvedAt
    );
    event ResolutionAppealed(
        uint256 indexed challengeId,
        address indexed appellant,
        uint256 appealedAt
    );
    event ResolutionFinalized(
        uint256 indexed challengeId,
        Outcome outcome,
        uint256 finalizedAt
    );
    event ChallengeVoidedByAdminTimeout(
        uint256 indexed challengeId,
        uint256 voidedAt
    );

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Deploys CloutEscrow, setting the deployer as owner.
    /// @dev OZ v5 Ownable requires explicit initialOwner argument.
    constructor() Ownable(msg.sender) {}

    // -------------------------------------------------------------------------
    // Stablecoin Whitelist
    // -------------------------------------------------------------------------

    /// @notice Adds a token to the whitelist.
    /// @param token The token address to whitelist.
    function addWhitelistedToken(address token) external onlyOwner {
        _whitelistedTokens[token] = true;
        emit TokenWhitelisted(token);
    }

    /// @notice Removes a token from the whitelist.
    /// @param token The token address to delist.
    function removeWhitelistedToken(address token) external onlyOwner {
        _whitelistedTokens[token] = false;
        emit TokenDelisted(token);
    }

    /// @notice Returns whether a token is whitelisted.
    /// @param token The token address to query.
    /// @return True if the token is whitelisted.
    function isWhitelisted(address token) external view returns (bool) {
        return _whitelistedTokens[token];
    }

    // -------------------------------------------------------------------------
    // createChallenge
    // -------------------------------------------------------------------------

    /// @notice Creates a new challenge and transfers the creator's stake into escrow.
    /// @param opponent The address of the opponent.
    /// @param stakeAmount The amount to stake (6 decimals).
    /// @param token The whitelisted stablecoin address.
    /// @param gameId The game type identifier.
    /// @param designatedResolver Optional third-party resolver; address(0) = admin-only.
    /// @return challengeId The ID of the newly created challenge.
    function createChallenge(
        address opponent,
        uint256 stakeAmount,
        address token,
        bytes32 gameId,
        address designatedResolver
    ) external nonReentrant returns (uint256 challengeId) {
        if (stakeAmount == 0) revert ZeroStake();
        if (!_whitelistedTokens[token]) revert TokenNotWhitelisted();
        if (opponent == address(0)) revert OpponentIsZeroAddress();
        if (opponent == msg.sender) revert OpponentIsCreator();
        if (designatedResolver == msg.sender) revert ResolverIsCreator();
        if (designatedResolver == opponent) revert ResolverIsOpponent();

        challengeId = ++challengeCount;

        Challenge storage c = challenges[challengeId];
        c.creator = msg.sender;
        c.opponent = opponent;
        c.designatedResolver = designatedResolver;
        c.token = token;
        c.stakeAmount = stakeAmount;
        c.state = ChallengeState.CREATED;
        c.gameId = gameId;
        // matchId, submittedResult, submittedBy, acceptedAt, submittedAt, disputedAt default to zero
        c.createdAt = block.timestamp;

        // Transfer stake from creator — reverts if transfer fails or returns false
        IERC20(token).safeTransferFrom(msg.sender, address(this), stakeAmount);

        // Update WalletRecord for creator
        _updateEntryStats(msg.sender, stakeAmount);

        emit ChallengeCreated(challengeId, msg.sender, opponent, token, stakeAmount, gameId, designatedResolver, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // Internal Helpers
    // -------------------------------------------------------------------------

    /// @notice Updates wallet entry statistics for a participant.
    /// @dev Called on createChallenge (creator) and acceptChallenge (opponent).
    /// @param wallet The participant address.
    /// @param stakeAmount The stake amount being entered.
    function _updateEntryStats(address wallet, uint256 stakeAmount) internal {
        WalletRecord storage r = walletRecords[wallet];
        r.challengesEntered++;
        r.totalStaked += stakeAmount;
        if (r.firstChallengeAt == 0) r.firstChallengeAt = block.timestamp;
        r.lastChallengeAt = block.timestamp;
    }

    /// @notice Updates wallet completion statistics for a participant.
    /// @dev Called on voidChallenge (won=false) and will be called by claimWinnings (NC-008).
    /// @param wallet The participant address.
    /// @param won True if the participant won the challenge.
    function _updateCompletionStats(address wallet, bool won) internal {
        WalletRecord storage r = walletRecords[wallet];
        r.challengesCompleted++;
        if (won) r.challengesWon++;
    }

    // -------------------------------------------------------------------------
    // acceptChallenge
    // -------------------------------------------------------------------------

    /// @notice Accepts a challenge and transfers the opponent's matching stake into escrow.
    /// @param challengeId The ID of the challenge to accept.
    function acceptChallenge(uint256 challengeId) external nonReentrant {
        Challenge storage c = challenges[challengeId];
        if (c.state != ChallengeState.CREATED) revert WrongState();
        if (msg.sender != c.opponent) revert NotOpponent();
        IERC20(c.token).safeTransferFrom(msg.sender, address(this), c.stakeAmount);
        c.state = ChallengeState.ACCEPTED;
        c.acceptedAt = block.timestamp;
        _updateEntryStats(msg.sender, c.stakeAmount);
        emit ChallengeAccepted(challengeId, msg.sender, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // voidChallenge
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // submitResult
    // -------------------------------------------------------------------------

    /// @notice Submits a match result. Transitions challenge from ACCEPTED to SUBMITTED.
    /// @param challengeId The ID of the challenge.
    /// @param outcome The result being submitted (CREATOR_WIN, OPPONENT_WIN, or DRAW).
    function submitResult(uint256 challengeId, Outcome outcome) external {
        Challenge storage c = challenges[challengeId];
        if (c.state != ChallengeState.ACCEPTED) revert WrongState();
        if (msg.sender != c.creator && msg.sender != c.opponent) revert NotParticipant();
        if (outcome == Outcome.NONE || outcome == Outcome.INVALID) revert InvalidOutcome();
        c.submittedResult = outcome;
        c.submittedBy = msg.sender;
        c.submittedAt = block.timestamp;
        c.state = ChallengeState.SUBMITTED;
        emit ResultSubmitted(challengeId, msg.sender, outcome, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // confirmResult
    // -------------------------------------------------------------------------

    /// @notice Confirms the submitted result. Transitions challenge from SUBMITTED to FINALIZED.
    /// @dev Only the non-submitting participant may confirm.
    /// @param challengeId The ID of the challenge.
    function confirmResult(uint256 challengeId) external {
        Challenge storage c = challenges[challengeId];
        if (c.state != ChallengeState.SUBMITTED) revert WrongState();
        if (msg.sender != c.creator && msg.sender != c.opponent) revert NotParticipant();
        if (msg.sender == c.submittedBy) revert CallerIsSubmitter();
        c.state = ChallengeState.FINALIZED;
        emit ResultConfirmed(challengeId, msg.sender, c.submittedResult);
    }

    // -------------------------------------------------------------------------
    // finalizeSubmission
    // -------------------------------------------------------------------------

    /// @notice Permissionless auto-finalize after 24h with no response from the other participant.
    /// @param challengeId The ID of the challenge.
    function finalizeSubmission(uint256 challengeId) external {
        Challenge storage c = challenges[challengeId];
        if (c.state != ChallengeState.SUBMITTED) revert WrongState();
        if (block.timestamp < c.submittedAt + SUBMISSION_TIMEOUT) revert TimeoutNotExpired();
        c.state = ChallengeState.FINALIZED;
        emit ChallengeFinalizedByTimeout(challengeId, c.submittedResult, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // voidChallenge
    // -------------------------------------------------------------------------

    /// @notice Voids a challenge after the 48-hour timeout, refunding all staked tokens.
    /// @dev CREATED: anyone may call after 48h from creation; refunds creator.
    ///      ACCEPTED: creator or opponent may call after 48h from acceptance; refunds both.
    /// @param challengeId The ID of the challenge to void.
    function voidChallenge(uint256 challengeId) external nonReentrant {
        Challenge storage c = challenges[challengeId];
        if (c.state == ChallengeState.CREATED) {
            if (block.timestamp < c.createdAt + VOID_TIMEOUT) revert TimeoutNotExpired();
            c.state = ChallengeState.VOIDED;
            c.claimed = true;
            IERC20(c.token).safeTransfer(c.creator, c.stakeAmount);
            _updateCompletionStats(c.creator, false);
            emit ChallengeVoided(challengeId, msg.sender, block.timestamp);
        } else if (c.state == ChallengeState.ACCEPTED) {
            if (msg.sender != c.creator && msg.sender != c.opponent) revert NotParticipant();
            if (block.timestamp < c.acceptedAt + VOID_TIMEOUT) revert TimeoutNotExpired();
            c.state = ChallengeState.VOIDED;
            c.claimed = true;
            IERC20(c.token).safeTransfer(c.creator, c.stakeAmount);
            IERC20(c.token).safeTransfer(c.opponent, c.stakeAmount);
            _updateCompletionStats(c.creator, false);
            _updateCompletionStats(c.opponent, false);
            emit ChallengeVoided(challengeId, msg.sender, block.timestamp);
        } else {
            revert WrongState();
        }
    }

    // -------------------------------------------------------------------------
    // disputeResult
    // -------------------------------------------------------------------------

    /// @notice Disputes the submitted result. Transitions challenge from SUBMITTED to DISPUTED.
    /// @dev Only the non-submitting participant may dispute.
    /// @param challengeId The ID of the challenge.
    function disputeResult(uint256 challengeId) external {
        Challenge storage c = challenges[challengeId];
        if (c.state != ChallengeState.SUBMITTED) revert WrongState();
        if (msg.sender != c.creator && msg.sender != c.opponent) revert NotParticipant();
        if (msg.sender == c.submittedBy) revert CallerIsSubmitter();
        c.state = ChallengeState.DISPUTED;
        c.disputedAt = block.timestamp;
        walletRecords[msg.sender].challengesDisputed++;
        emit ResultDisputed(challengeId, msg.sender, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // _doResolve (internal shared resolution logic)
    // -------------------------------------------------------------------------

    /// @notice Shared resolution logic for both resolveDispute and resolveDisputeAsAdmin.
    /// @param challengeId The ID of the challenge.
    /// @param outcome The resolver's verdict (must not be Outcome.NONE).
    /// @param resolverAddr The address of the entity resolving (for tracking).
    function _doResolve(uint256 challengeId, Outcome outcome, address resolverAddr) internal {
        if (outcome == Outcome.NONE) revert InvalidOutcome();
        Challenge storage c = challenges[challengeId];
        c.submittedResult = outcome;
        c.state = ChallengeState.RESOLVED;
        c.resolvedAt = block.timestamp;
        resolvedChallenges[resolverAddr]++;
        emit DisputeResolved(challengeId, resolverAddr, outcome, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // resolveDispute
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // appealResolution
    // -------------------------------------------------------------------------

    /// @notice Files an appeal against a resolver decision. Either creator or opponent may call
    ///         within 24h of the challenge being resolved.
    /// @param challengeId The ID of the challenge.
    function appealResolution(uint256 challengeId) external {
        Challenge storage c = challenges[challengeId];
        if (c.state != ChallengeState.RESOLVED) revert WrongState();
        if (msg.sender != c.creator && msg.sender != c.opponent) revert NotParticipant();
        if (c.designatedResolver == address(0)) revert AppealNotAllowed(); // admin decisions are final
        if (c.appealed) revert AlreadyAppealed();
        if (block.timestamp >= c.resolvedAt + SUBMISSION_TIMEOUT) revert AppealWindowExpired();
        c.appealed = true;
        c.appealedAt = block.timestamp;
        emit ResolutionAppealed(challengeId, msg.sender, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // finalizeResolution
    // -------------------------------------------------------------------------

    /// @notice Permissionless finalize after 24h with no appeal filed. Resolver decision stands.
    /// @param challengeId The ID of the challenge.
    function finalizeResolution(uint256 challengeId) external {
        Challenge storage c = challenges[challengeId];
        if (c.state != ChallengeState.RESOLVED) revert WrongState();
        if (c.appealed) revert AppealPending();
        if (block.timestamp < c.resolvedAt + SUBMISSION_TIMEOUT) revert TimeoutNotExpired();
        c.state = ChallengeState.FINALIZED;
        emit ResolutionFinalized(challengeId, c.submittedResult, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // adminFinalizeAppeal
    // -------------------------------------------------------------------------

    /// @notice Admin reviews an appeal and issues a final decision. Must be called within 48h
    ///         of the appeal being filed.
    /// @param challengeId The ID of the challenge.
    /// @param outcome The admin's verdict (must not be Outcome.NONE).
    function adminFinalizeAppeal(uint256 challengeId, Outcome outcome) external onlyOwner {
        Challenge storage c = challenges[challengeId];
        if (c.state != ChallengeState.RESOLVED) revert WrongState();
        if (!c.appealed) revert NoAppeal();
        if (outcome == Outcome.NONE) revert InvalidOutcome();
        if (block.timestamp >= c.appealedAt + VOID_TIMEOUT) revert AdminTimeoutExpired();
        c.submittedResult = outcome;
        c.state = ChallengeState.FINALIZED;
        emit ResolutionFinalized(challengeId, outcome, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // voidByAdminTimeout
    // -------------------------------------------------------------------------

    /// @notice Permissionless void when admin fails to act within 48h of an appeal. Both parties
    ///         are refunded their stakes.
    /// @param challengeId The ID of the challenge.
    function voidByAdminTimeout(uint256 challengeId) external nonReentrant {
        Challenge storage c = challenges[challengeId];
        if (c.state != ChallengeState.RESOLVED) revert WrongState();
        if (!c.appealed) revert NoAppeal();
        if (block.timestamp < c.appealedAt + VOID_TIMEOUT) revert TimeoutNotExpired();
        c.state = ChallengeState.VOIDED;
        c.claimed = true;
        IERC20(c.token).safeTransfer(c.creator, c.stakeAmount);
        IERC20(c.token).safeTransfer(c.opponent, c.stakeAmount);
        _updateCompletionStats(c.creator, false);
        _updateCompletionStats(c.opponent, false);
        emit ChallengeVoidedByAdminTimeout(challengeId, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // resolveDispute
    // -------------------------------------------------------------------------

    /// @notice Resolves a disputed challenge.
    /// @dev When a designatedResolver is set, only that resolver may call (within 48h).
    ///      Admin is blocked from this function when a resolver is set — use resolveDisputeAsAdmin.
    ///      When no resolver is set (designatedResolver == address(0)), only admin may call.
    /// @param challengeId The ID of the challenge.
    /// @param outcome The resolver's verdict.
    function resolveDispute(uint256 challengeId, Outcome outcome) external {
        Challenge storage c = challenges[challengeId];
        if (c.state != ChallengeState.DISPUTED) revert WrongState();
        if (c.designatedResolver != address(0)) {
            // Resolver-assigned path: ONLY the designated resolver may call.
            // Admin is blocked here — admin must use resolveDisputeAsAdmin after timeout.
            if (msg.sender != c.designatedResolver) revert NotResolver();
            if (block.timestamp >= c.disputedAt + VOID_TIMEOUT) revert ResolverTimedOut();
        } else {
            // Admin-only path: no designated resolver, no timeout applies.
            if (msg.sender != owner()) revert NotResolver();
        }
        _doResolve(challengeId, outcome, msg.sender);
    }

    // -------------------------------------------------------------------------
    // resolveDisputeAsAdmin
    // -------------------------------------------------------------------------

    /// @notice Admin fallback to resolve a dispute after the resolver's 48h window expires.
    /// @dev When designatedResolver is set, admin must wait for the 48h timeout.
    ///      When designatedResolver == address(0), admin may call immediately (no timeout).
    /// @param challengeId The ID of the challenge.
    /// @param outcome The admin's verdict.
    function resolveDisputeAsAdmin(uint256 challengeId, Outcome outcome) external onlyOwner {
        Challenge storage c = challenges[challengeId];
        if (c.state != ChallengeState.DISPUTED) revert WrongState();
        if (c.designatedResolver != address(0)) {
            if (block.timestamp < c.disputedAt + VOID_TIMEOUT) revert TimeoutNotExpired();
        }
        _doResolve(challengeId, outcome, msg.sender);
    }
}
