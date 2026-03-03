// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CloutPool is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // Enums
    // -------------------------------------------------------------------------

    enum PoolState { OPEN, CLOSED, SUBMITTED, DISPUTED, FINALIZED, VOIDED }

    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    struct Pool {
        address host;               // Pool creator; stakes YES at creation
        address resolver;           // Designated third-party resolver — must not be address(0), must not equal host
        address token;              // Whitelisted stablecoin (6 decimals)
        uint256 eventStart;         // Timestamp when event begins; pool closes at or after this
        uint256 eventEnd;           // Timestamp when event ends
        uint256 resolveBy;          // Deadline for resolver to submit result; void if exceeded
        uint256 perWalletCap;       // Max stake per wallet per side (I-10)
        uint256 totalPoolCap;       // Max combined YES+NO total (I-11)
        uint256 hostCommissionBps;  // Host commission in basis points (only on YES win — I-12)
        PoolState state;            // Current state
        uint256 yesTotal;           // Accumulated YES-side stakes
        uint256 noTotal;            // Accumulated NO-side stakes
        uint256 resolvedAt;         // Timestamp when resolver submitted result (for NC-012A dispute window)
        bool yesWins;               // Stored resolver verdict (for NC-012A/B)
        uint256 losingStakerCount;  // Count of unique wallets on losing side, snapshotted at resolution (for NC-012A)
        uint256 flagCount;          // Number of dispute flags received (for NC-012A)
    }

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    uint256 public constant DISPUTE_WINDOW = 86400;        // 24 hours — for NC-012A
    uint256 public constant MAX_FEE_BPS = 1000;            // 10% hard cap on protocol fee
    uint256 public constant MAX_COMMISSION_BPS = 10000;    // 100% cap on host commission

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    // Pool registry
    mapping(uint256 => Pool) public pools;
    uint256 public poolCount;

    // Per-wallet stake amounts — keyed by (poolId, wallet)
    mapping(uint256 => mapping(address => uint256)) public yesStakes;
    mapping(uint256 => mapping(address => uint256)) public noStakes;

    // First-stake flags for unique staker counting.
    // Set to true when a wallet makes its FIRST stake on a given side.
    // Never reset. Used to increment yesStakerCount / noStakerCount exactly once per wallet per side.
    mapping(uint256 => mapping(address => bool)) public hasStakedYes;
    mapping(uint256 => mapping(address => bool)) public hasStakedNo;

    // Unique staker counters per pool per side.
    // At resolution time (NC-012A): pool.losingStakerCount = yesWins ? noStakerCount[poolId] : yesStakerCount[poolId]
    mapping(uint256 => uint256) public yesStakerCount;
    mapping(uint256 => uint256) public noStakerCount;

    // Per-wallet dispute flag tracking — for NC-012A (one flag per wallet)
    mapping(uint256 => mapping(address => bool)) public disputeFlags;

    // Per-staker claim tracking — for NC-012B (prevents double-claim)
    mapping(uint256 => mapping(address => bool)) public claimed;

    // Stablecoin whitelist
    mapping(address => bool) private _whitelistedTokens;

    // Protocol fee config
    uint256 public feeBps;       // protocol fee in basis points; default 250 = 2.5%
    address public treasury;     // fee recipient; address(0) = no fee collected

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------

    error TokenNotWhitelisted();
    error ZeroResolver();
    error HostIsResolver();
    error InvalidTimestamps();
    error ZeroStake();
    error ZeroCapValue();
    error CommissionTooHigh();
    error WrongState();
    error PerWalletCapExceeded();
    error TotalCapExceeded();
    error ZeroAmount();
    error FeeTooHigh();
    error NotResolver();             // msg.sender != pool.resolver
    error ResolverDeadlinePassed(); // block.timestamp > pool.resolveBy — resolver cannot submit after deadline
    error NotLosingStaker();         // caller has zero stake on the losing side
    error AlreadyFlagged();          // disputeFlags[poolId][msg.sender] is already true
    error DisputeWindowExpired();    // block.timestamp > resolvedAt + DISPUTE_WINDOW
    error DisputeWindowOpen();       // block.timestamp <= resolvedAt + DISPUTE_WINDOW (can't finalize yet)

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event PoolCreated(
        uint256 indexed poolId,
        address indexed host,
        address resolver,
        address token,
        uint256 eventStart,
        uint256 eventEnd,
        uint256 resolveBy,
        uint256 perWalletCap,
        uint256 totalPoolCap,
        uint256 hostCommissionBps,
        PoolState state,
        uint256 yesTotal,
        uint256 noTotal
    );

    event Staked(
        uint256 indexed poolId,
        address indexed staker,
        bool isYes,
        uint256 amount
    );

    event PoolClosed(
        uint256 indexed poolId,
        uint256 totalYes,
        uint256 totalNo
    );

    event TokenWhitelisted(address indexed token);
    event TokenDelisted(address indexed token);
    event ProtocolFeeUpdated(uint256 oldBps, uint256 newBps);
    event TreasuryUpdated(address oldTreasury, address newTreasury);

    // Events for NC-012A/B — declared for complete ABI, not emitted by NC-011 functions
    event PoolResolved(uint256 indexed poolId, bool yesWins, uint256 resolvedAt);
    event PoolDisputeFlagged(uint256 indexed poolId, address indexed flagger, uint256 flagCount);
    event PoolDisputeTriggered(uint256 indexed poolId);
    event PoolFinalized(uint256 indexed poolId, bool yesWins);
    event WinningsClaimed(uint256 indexed poolId, address indexed staker, uint256 amount);
    event PoolVoided(uint256 indexed poolId);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Deploys CloutPool, setting the deployer as owner.
    constructor() Ownable(msg.sender) {
        feeBps = 250; // default 2.5%
    }

    // -------------------------------------------------------------------------
    // Admin Functions
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

    /// @notice Sets the protocol fee in basis points. Hard-capped at MAX_FEE_BPS (10%).
    /// @param bps The new fee in basis points (e.g., 250 = 2.5%).
    function setProtocolFee(uint256 bps) external onlyOwner {
        if (bps > MAX_FEE_BPS) revert FeeTooHigh();
        emit ProtocolFeeUpdated(feeBps, bps);
        feeBps = bps;
    }

    /// @notice Sets the protocol fee recipient address.
    /// @param _treasury The new treasury address; address(0) disables fee collection.
    function setTreasury(address _treasury) external onlyOwner {
        emit TreasuryUpdated(treasury, _treasury);
        treasury = _treasury;
    }

    // -------------------------------------------------------------------------
    // createPool
    // -------------------------------------------------------------------------

    /// @notice Creates a new prediction pool. The host stakes the initial YES-side amount.
    /// @param resolver  Designated third-party resolver; must not be address(0) or host.
    /// @param token     Whitelisted stablecoin address (6 decimals).
    /// @param eventStart  Timestamp when the event begins; pool may be closed at or after this.
    /// @param eventEnd    Timestamp when the event ends.
    /// @param resolveBy   Deadline for resolver to submit result; pool is voided if exceeded.
    /// @param perWalletCap  Maximum stake per wallet per side (I-10).
    /// @param totalPoolCap  Maximum combined YES+NO total (I-11).
    /// @param hostCommissionBps  Host commission in basis points (I-12).
    /// @param initialYesStake  Host's initial YES-side stake; must be non-zero (I-8).
    /// @return poolId The ID of the newly created pool.
    function createPool(
        address resolver,
        address token,
        uint256 eventStart,
        uint256 eventEnd,
        uint256 resolveBy,
        uint256 perWalletCap,
        uint256 totalPoolCap,
        uint256 hostCommissionBps,
        uint256 initialYesStake
    ) external nonReentrant returns (uint256 poolId) {
        // CHECKS
        if (!_whitelistedTokens[token]) revert TokenNotWhitelisted();
        if (resolver == address(0)) revert ZeroResolver();
        if (resolver == msg.sender) revert HostIsResolver();
        if (
            eventStart <= block.timestamp ||
            eventStart >= eventEnd ||
            eventEnd >= resolveBy
        ) revert InvalidTimestamps();
        if (initialYesStake == 0) revert ZeroStake();
        if (perWalletCap == 0 || totalPoolCap == 0) revert ZeroCapValue();
        if (initialYesStake > perWalletCap) revert PerWalletCapExceeded();
        if (initialYesStake > totalPoolCap) revert TotalCapExceeded();
        if (hostCommissionBps > MAX_COMMISSION_BPS) revert CommissionTooHigh();

        // EFFECTS
        poolId = ++poolCount;

        Pool storage p = pools[poolId];
        p.host              = msg.sender;
        p.resolver          = resolver;
        p.token             = token;
        p.eventStart        = eventStart;
        p.eventEnd          = eventEnd;
        p.resolveBy         = resolveBy;
        p.perWalletCap      = perWalletCap;
        p.totalPoolCap      = totalPoolCap;
        p.hostCommissionBps = hostCommissionBps;
        p.state             = PoolState.OPEN;
        p.yesTotal          = initialYesStake;
        p.noTotal           = 0;

        yesStakes[poolId][msg.sender]  = initialYesStake;
        hasStakedYes[poolId][msg.sender] = true;
        yesStakerCount[poolId]         = 1;

        // INTERACTIONS
        IERC20(token).safeTransferFrom(msg.sender, address(this), initialYesStake);

        emit PoolCreated(
            poolId,
            msg.sender,
            resolver,
            token,
            eventStart,
            eventEnd,
            resolveBy,
            perWalletCap,
            totalPoolCap,
            hostCommissionBps,
            PoolState.OPEN,
            initialYesStake,
            0
        );
    }

    // -------------------------------------------------------------------------
    // stakePool
    // -------------------------------------------------------------------------

    /// @notice Stakes on a YES or NO side of an open pool.
    /// @param poolId The ID of the pool to stake in.
    /// @param isYes  True to stake on the YES side; false for the NO side.
    /// @param amount The amount to stake (must be non-zero).
    function stakePool(
        uint256 poolId,
        bool isYes,
        uint256 amount
    ) external nonReentrant {
        // CHECKS
        Pool storage pool = pools[poolId];
        if (pool.host == address(0)) revert WrongState();
        if (amount == 0) revert ZeroAmount();
        if (pool.state != PoolState.OPEN) revert WrongState();

        uint256 currentWalletStake = isYes
            ? yesStakes[poolId][msg.sender]
            : noStakes[poolId][msg.sender];
        if (currentWalletStake + amount > pool.perWalletCap) revert PerWalletCapExceeded();
        if (pool.yesTotal + pool.noTotal + amount > pool.totalPoolCap) revert TotalCapExceeded();

        // EFFECTS
        if (isYes) {
            yesStakes[poolId][msg.sender] += amount;
            pool.yesTotal += amount;
            if (!hasStakedYes[poolId][msg.sender]) {
                hasStakedYes[poolId][msg.sender] = true;
                yesStakerCount[poolId]++;
            }
        } else {
            noStakes[poolId][msg.sender] += amount;
            pool.noTotal += amount;
            if (!hasStakedNo[poolId][msg.sender]) {
                hasStakedNo[poolId][msg.sender] = true;
                noStakerCount[poolId]++;
            }
        }

        // INTERACTIONS
        IERC20(pool.token).safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(poolId, msg.sender, isYes, amount);
    }

    // -------------------------------------------------------------------------
    // closePool
    // -------------------------------------------------------------------------

    /// @notice Permissionless: transitions an OPEN pool to CLOSED once the event has started.
    /// @param poolId The ID of the pool to close.
    function closePool(uint256 poolId) external {
        Pool storage pool = pools[poolId];
        if (pool.host == address(0)) revert WrongState();
        if (pool.state != PoolState.OPEN) revert WrongState();
        if (block.timestamp < pool.eventStart) revert WrongState();

        pool.state = PoolState.CLOSED;

        emit PoolClosed(poolId, pool.yesTotal, pool.noTotal);
    }

    // -------------------------------------------------------------------------
    // resolvePool
    // -------------------------------------------------------------------------

    /// @notice Resolver submits the outcome of a closed pool.
    /// @param poolId  The ID of the pool to resolve.
    /// @param yesWins True if the YES side won; false otherwise.
    function resolvePool(uint256 poolId, bool yesWins) external {
        Pool storage pool = pools[poolId];
        // CHECKS
        if (pool.host == address(0)) revert WrongState();
        if (pool.state != PoolState.CLOSED) revert WrongState();
        if (msg.sender != pool.resolver) revert NotResolver();
        if (block.timestamp > pool.resolveBy) revert ResolverDeadlinePassed();

        // EFFECTS
        pool.yesWins = yesWins;

        uint256 losingCount = yesWins ? noStakerCount[poolId] : yesStakerCount[poolId];
        pool.losingStakerCount = losingCount;
        pool.resolvedAt = block.timestamp;

        if (losingCount == 0) {
            pool.state = PoolState.FINALIZED;
            emit PoolResolved(poolId, yesWins, pool.resolvedAt);
            emit PoolFinalized(poolId, yesWins);
        } else {
            pool.state = PoolState.SUBMITTED;
            emit PoolResolved(poolId, yesWins, pool.resolvedAt);
        }
    }

    // -------------------------------------------------------------------------
    // disputePool
    // -------------------------------------------------------------------------

    /// @notice A losing-side staker flags the resolution as disputed.
    /// @param poolId The ID of the pool to dispute.
    function disputePool(uint256 poolId) external {
        Pool storage pool = pools[poolId];
        // CHECKS
        if (pool.host == address(0)) revert WrongState();
        if (pool.state != PoolState.SUBMITTED) revert WrongState();
        if (block.timestamp > pool.resolvedAt + DISPUTE_WINDOW) revert DisputeWindowExpired();
        if (pool.yesWins) {
            if (noStakes[poolId][msg.sender] == 0) revert NotLosingStaker();
        } else {
            if (yesStakes[poolId][msg.sender] == 0) revert NotLosingStaker();
        }
        if (disputeFlags[poolId][msg.sender]) revert AlreadyFlagged();

        // EFFECTS
        disputeFlags[poolId][msg.sender] = true;
        pool.flagCount++;
        emit PoolDisputeFlagged(poolId, msg.sender, pool.flagCount);

        if (pool.flagCount * 10000 > pool.losingStakerCount * 2000) {
            pool.state = PoolState.DISPUTED;
            emit PoolDisputeTriggered(poolId);
        }
    }

    // -------------------------------------------------------------------------
    // finalizePool
    // -------------------------------------------------------------------------

    /// @notice Permissionless finalization after the 24h dispute window passes with no threshold met.
    /// @param poolId The ID of the pool to finalize.
    function finalizePool(uint256 poolId) external {
        Pool storage pool = pools[poolId];
        // CHECKS
        if (pool.host == address(0)) revert WrongState();
        if (pool.state != PoolState.SUBMITTED) revert WrongState();
        if (block.timestamp <= pool.resolvedAt + DISPUTE_WINDOW) revert DisputeWindowOpen();

        // EFFECTS
        pool.state = PoolState.FINALIZED;
        emit PoolFinalized(poolId, pool.yesWins);
    }

    // -------------------------------------------------------------------------
    // adminResolvePool
    // -------------------------------------------------------------------------

    /// @notice Admin resolves a disputed pool with a final verdict.
    /// @param poolId  The ID of the disputed pool to resolve.
    /// @param yesWins True if the YES side wins; false otherwise.
    function adminResolvePool(uint256 poolId, bool yesWins) external onlyOwner {
        Pool storage pool = pools[poolId];
        // CHECKS
        if (pool.state != PoolState.DISPUTED) revert WrongState();

        // EFFECTS
        pool.yesWins = yesWins;
        pool.state = PoolState.FINALIZED;
        emit PoolFinalized(poolId, yesWins);
    }

    // -------------------------------------------------------------------------
    // View Functions
    // -------------------------------------------------------------------------

    /// @notice Returns all Pool fields for a given pool.
    /// @param poolId The ID of the pool to query.
    /// @return The complete Pool struct.
    function getPool(uint256 poolId) external view returns (Pool memory) {
        return pools[poolId];
    }

    /// @notice Returns a wallet's YES and NO stakes in a pool.
    /// @param poolId The ID of the pool.
    /// @param staker The wallet address to query.
    /// @return yesStake The wallet's YES-side stake.
    /// @return noStake  The wallet's NO-side stake.
    function getStakes(uint256 poolId, address staker)
        external view returns (uint256 yesStake, uint256 noStake)
    {
        yesStake = yesStakes[poolId][staker];
        noStake  = noStakes[poolId][staker];
    }

    /// @notice Returns unique staker counts for a given pool.
    /// @param poolId The ID of the pool.
    /// @return yesCount Unique wallets that have staked YES.
    /// @return noCount  Unique wallets that have staked NO.
    function getStakerCounts(uint256 poolId)
        external view returns (uint256 yesCount, uint256 noCount)
    {
        yesCount = yesStakerCount[poolId];
        noCount  = noStakerCount[poolId];
    }
}
