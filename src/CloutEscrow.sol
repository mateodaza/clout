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
    // Storage
    // -------------------------------------------------------------------------

    mapping(uint256 => Challenge) public challenges;
    uint256 public challengeCount;
    mapping(address => bool) private _whitelistedTokens;
    mapping(address => WalletRecord) public walletRecords;

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------

    error ZeroStake();
    error TokenNotWhitelisted();
    error OpponentIsZeroAddress();
    error OpponentIsCreator();
    error ResolverIsCreator();
    error ResolverIsOpponent();

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
}
