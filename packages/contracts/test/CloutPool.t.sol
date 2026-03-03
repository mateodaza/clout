// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CloutPool} from "../src/CloutPool.sol";
import {MockStablecoin} from "../src/MockStablecoin.sol";

contract CloutPoolTest is Test {
    // Re-declare events for vm.expectEmit
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
        CloutPool.PoolState state,
        uint256 yesTotal,
        uint256 noTotal
    );
    event Staked(uint256 indexed poolId, address indexed staker, bool isYes, uint256 amount);
    event PoolClosed(uint256 indexed poolId, uint256 totalYes, uint256 totalNo);
    event PoolResolved(uint256 indexed poolId, bool yesWins, uint256 resolvedAt);
    event PoolDisputeFlagged(uint256 indexed poolId, address indexed flagger, uint256 flagCount);
    event PoolDisputeTriggered(uint256 indexed poolId);
    event PoolFinalized(uint256 indexed poolId, bool yesWins);
    event WinningsClaimed(uint256 indexed poolId, address indexed staker, uint256 amount);
    event PoolVoided(uint256 indexed poolId);

    CloutPool pool;
    MockStablecoin token;

    address admin    = address(this);
    address host     = address(0xA0);
    address resolver = address(0xB0);
    address staker1  = address(0xC0);
    address staker2  = address(0xD0);
    address staker3  = address(0xE0);
    address staker4  = address(0xF0);
    address staker5  = address(0x1A0);
    address treasury = address(0xFEE1);

    uint256 constant STAKE = 100 * 1e6; // 100 USDC (6 decimals)

    function setUp() public {
        token = new MockStablecoin();
        pool  = new CloutPool();

        pool.addWhitelistedToken(address(token));
        pool.setTreasury(treasury);

        // Mint and approve for all actors
        address[8] memory actors = [host, resolver, staker1, staker2, staker3, staker4, staker5, treasury];
        for (uint256 i = 0; i < actors.length; i++) {
            token.mint(actors[i], 1000 * 1e6);
            vm.prank(actors[i]);
            token.approve(address(pool), type(uint256).max);
        }
    }

    // -------------------------------------------------------------------------
    // Helper
    // -------------------------------------------------------------------------

    function _defaultCreatePool() internal returns (uint256 poolId) {
        vm.prank(host);
        poolId = pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,   // eventStart
            block.timestamp + 2 days,   // eventEnd
            block.timestamp + 3 days,   // resolveBy
            500 * 1e6,                  // perWalletCap
            1000 * 1e6,                 // totalPoolCap
            500,                        // hostCommissionBps (5%)
            STAKE                       // initialYesStake
        );
    }

    // -------------------------------------------------------------------------
    // Test 1 — createPool: happy path
    // -------------------------------------------------------------------------

    function test_createPool_success() public {
        uint256 eStart   = block.timestamp + 1 days;
        uint256 eEnd     = block.timestamp + 2 days;
        uint256 resolveB = block.timestamp + 3 days;

        vm.expectEmit(true, true, false, true);
        emit PoolCreated(
            1,
            host,
            resolver,
            address(token),
            eStart,
            eEnd,
            resolveB,
            500 * 1e6,
            1000 * 1e6,
            500,
            CloutPool.PoolState.OPEN,
            STAKE,
            0
        );

        vm.prank(host);
        uint256 poolId = pool.createPool(
            resolver,
            address(token),
            eStart,
            eEnd,
            resolveB,
            500 * 1e6,
            1000 * 1e6,
            500,
            STAKE
        );

        assertEq(poolId, 1);

        CloutPool.Pool memory p = pool.getPool(poolId);
        assertEq(p.host,             host);
        assertEq(p.resolver,         resolver);
        assertEq(p.token,            address(token));
        assertEq(p.eventStart,       eStart);
        assertEq(p.eventEnd,         eEnd);
        assertEq(p.resolveBy,        resolveB);
        assertEq(p.perWalletCap,     500 * 1e6);
        assertEq(p.totalPoolCap,     1000 * 1e6);
        assertEq(p.hostCommissionBps, 500);
        assertEq(uint8(p.state),     uint8(CloutPool.PoolState.OPEN));
        assertEq(p.yesTotal,         STAKE);
        assertEq(p.noTotal,          0);

        // Per-staker stake recorded
        assertEq(pool.yesStakes(poolId, host), STAKE);
        // Staker count initialized to 1 (host)
        assertEq(pool.yesStakerCount(poolId), 1);
        assertTrue(pool.hasStakedYes(poolId, host));
        // Token transferred
        assertEq(token.balanceOf(address(pool)), STAKE);
    }

    // -------------------------------------------------------------------------
    // Test 2 — createPool: host == resolver reverts HostIsResolver
    // -------------------------------------------------------------------------

    function test_createPool_revertsHostIsResolver() public {
        vm.prank(host);
        vm.expectRevert(CloutPool.HostIsResolver.selector);
        pool.createPool(
            host, // resolver == host
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500 * 1e6,
            1000 * 1e6,
            500,
            STAKE
        );
    }

    // -------------------------------------------------------------------------
    // Test 3 — createPool: resolver == address(0) reverts ZeroResolver
    // -------------------------------------------------------------------------

    function test_createPool_revertsZeroResolver() public {
        vm.prank(host);
        vm.expectRevert(CloutPool.ZeroResolver.selector);
        pool.createPool(
            address(0), // resolver == address(0)
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500 * 1e6,
            1000 * 1e6,
            500,
            STAKE
        );
    }

    // -------------------------------------------------------------------------
    // Test 4 — createPool: initialYesStake == 0 reverts ZeroStake
    // -------------------------------------------------------------------------

    function test_createPool_revertsZeroStake() public {
        vm.prank(host);
        vm.expectRevert(CloutPool.ZeroStake.selector);
        pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500 * 1e6,
            1000 * 1e6,
            500,
            0 // initialYesStake == 0
        );
    }

    // -------------------------------------------------------------------------
    // Test 5 — createPool: invalid timestamps
    // -------------------------------------------------------------------------

    function test_createPool_revertsInvalidTimestamps() public {
        // Sub-case A: eventStart in the past
        vm.prank(host);
        vm.expectRevert(CloutPool.InvalidTimestamps.selector);
        pool.createPool(
            resolver,
            address(token),
            block.timestamp - 1, // eventStart in past
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500 * 1e6,
            1000 * 1e6,
            500,
            STAKE
        );

        // Sub-case B: eventStart >= eventEnd
        vm.prank(host);
        vm.expectRevert(CloutPool.InvalidTimestamps.selector);
        pool.createPool(
            resolver,
            address(token),
            block.timestamp + 2 days, // eventStart == eventEnd
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500 * 1e6,
            1000 * 1e6,
            500,
            STAKE
        );

        // Sub-case C: eventEnd >= resolveBy
        vm.prank(host);
        vm.expectRevert(CloutPool.InvalidTimestamps.selector);
        pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 3 days, // eventEnd == resolveBy
            block.timestamp + 3 days,
            500 * 1e6,
            1000 * 1e6,
            500,
            STAKE
        );
    }

    // -------------------------------------------------------------------------
    // Test 6 — createPool: non-whitelisted token reverts TokenNotWhitelisted
    // -------------------------------------------------------------------------

    function test_createPool_revertsNonWhitelistedToken() public {
        MockStablecoin badToken = new MockStablecoin();
        vm.prank(host);
        vm.expectRevert(CloutPool.TokenNotWhitelisted.selector);
        pool.createPool(
            resolver,
            address(badToken),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500 * 1e6,
            1000 * 1e6,
            500,
            STAKE
        );
    }

    // -------------------------------------------------------------------------
    // Test 7 — stakePool: happy path YES and NO
    // -------------------------------------------------------------------------

    function test_stakePool_success_yesAndNo() public {
        uint256 poolId = _defaultCreatePool();

        // staker1 stakes YES
        vm.expectEmit(true, true, false, true);
        emit Staked(poolId, staker1, true, STAKE);
        vm.prank(staker1);
        pool.stakePool(poolId, true, STAKE);

        // staker2 stakes NO
        vm.expectEmit(true, true, false, true);
        emit Staked(poolId, staker2, false, STAKE);
        vm.prank(staker2);
        pool.stakePool(poolId, false, STAKE);

        CloutPool.Pool memory p = pool.getPool(poolId);
        assertEq(p.yesTotal, STAKE * 2); // host + staker1
        assertEq(p.noTotal,  STAKE);     // staker2

        assertEq(pool.yesStakes(poolId, staker1), STAKE);
        assertEq(pool.noStakes(poolId, staker2),  STAKE);

        // staker1 is second YES staker (after host); yesStakerCount should be 2
        assertEq(pool.yesStakerCount(poolId), 2);
        // staker2 is first NO staker
        assertEq(pool.noStakerCount(poolId), 1);
        assertTrue(pool.hasStakedNo(poolId, staker2));
    }

    // -------------------------------------------------------------------------
    // Test 8 — stakePool: unique staker count does not double-increment (FB-3A)
    // -------------------------------------------------------------------------

    function test_stakePool_uniqueStakerCount_noDoubleIncrement() public {
        uint256 poolId = _defaultCreatePool();

        // staker1 stakes YES twice
        vm.prank(staker1);
        pool.stakePool(poolId, true, STAKE);

        vm.prank(staker1);
        pool.stakePool(poolId, true, STAKE);

        // host (count=1) + staker1 (count should be +1 only once) = 2
        assertEq(pool.yesStakerCount(poolId), 2);

        // Both deposits accumulated correctly
        assertEq(pool.yesStakes(poolId, staker1), STAKE * 2);
    }

    // -------------------------------------------------------------------------
    // Test 9 — stakePool: per-wallet cap exceeded reverts PerWalletCapExceeded
    // -------------------------------------------------------------------------

    function test_stakePool_revertsPerWalletCap() public {
        uint256 poolId = _defaultCreatePool();

        // perWalletCap = 500 * 1e6; staker1 tries to stake 501 * 1e6
        token.mint(staker1, 1000 * 1e6);
        vm.prank(staker1);
        vm.expectRevert(CloutPool.PerWalletCapExceeded.selector);
        pool.stakePool(poolId, true, 501 * 1e6);
    }

    // -------------------------------------------------------------------------
    // Test 10 — stakePool: total cap exceeded reverts TotalCapExceeded
    // -------------------------------------------------------------------------

    function test_stakePool_revertsTotalCap() public {
        uint256 poolId = _defaultCreatePool();
        // totalPoolCap = 1000 * 1e6; yesTotal is already 100 * 1e6 (host's stake)
        // stake 500 * 1e6 from staker1 YES → yesTotal = 600
        vm.prank(staker1);
        pool.stakePool(poolId, true, 500 * 1e6);
        // stake 500 * 1e6 from staker2 NO → combined would be 1100 > 1000
        token.mint(staker2, 1000 * 1e6);
        vm.prank(staker2);
        vm.expectRevert(CloutPool.TotalCapExceeded.selector);
        pool.stakePool(poolId, false, 500 * 1e6);
    }

    // -------------------------------------------------------------------------
    // Test 11 — closePool: success transitions OPEN→CLOSED, blocks further staking
    // -------------------------------------------------------------------------

    function test_closePool_success() public {
        uint256 poolId = _defaultCreatePool();
        CloutPool.Pool memory p = pool.getPool(poolId);

        // Warp to eventStart
        vm.warp(p.eventStart);

        vm.expectEmit(true, false, false, true);
        emit PoolClosed(poolId, p.yesTotal, p.noTotal);
        pool.closePool(poolId);

        CloutPool.Pool memory p2 = pool.getPool(poolId);
        assertEq(uint8(p2.state), uint8(CloutPool.PoolState.CLOSED));

        // staking on a CLOSED pool should revert
        vm.prank(staker1);
        vm.expectRevert(CloutPool.WrongState.selector);
        pool.stakePool(poolId, true, STAKE);
    }

    // -------------------------------------------------------------------------
    // Test 12 — closePool: reverts before eventStart
    // -------------------------------------------------------------------------

    function test_closePool_revertsBeforeEventStart() public {
        uint256 poolId = _defaultCreatePool();

        vm.expectRevert(CloutPool.WrongState.selector);
        pool.closePool(poolId);
    }

    // -------------------------------------------------------------------------
    // Helpers for NC-012A tests
    // -------------------------------------------------------------------------

    /// Creates pool, stakes staker1 NO, warps to eventStart, closes.
    /// Returns poolId with: host YES=STAKE, staker1 NO=STAKE.
    function _createAndClosePoolWithNoStaker() internal returns (uint256 poolId) {
        poolId = _defaultCreatePool();

        vm.prank(staker1);
        pool.stakePool(poolId, false, STAKE);

        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.eventStart);
        pool.closePool(poolId);
        vm.warp(p.eventEnd);
    }

    /// Creates pool, stakes count NO stakers (staker1..staker5), closes, returns poolId.
    function _createAndClosePoolWithMultipleNoStakers(uint256 count) internal returns (uint256 poolId) {
        poolId = _defaultCreatePool();

        address[5] memory stakers = [staker1, staker2, staker3, staker4, staker5];
        for (uint256 i = 0; i < count; i++) {
            vm.prank(stakers[i]);
            pool.stakePool(poolId, false, STAKE);
        }

        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.eventStart);
        pool.closePool(poolId);
        vm.warp(p.eventEnd);
    }

    // -------------------------------------------------------------------------
    // Test 13 (NC-012A #1) — resolvePool: success yesWins
    // -------------------------------------------------------------------------

    function test_resolvePool_success_yesWins() public {
        uint256 poolId = _createAndClosePoolWithNoStaker();

        vm.expectEmit(true, false, false, true);
        emit PoolResolved(poolId, true, block.timestamp);
        vm.prank(resolver);
        pool.resolvePool(poolId, true);

        CloutPool.Pool memory p2 = pool.getPool(poolId);
        assertEq(uint8(p2.state), uint8(CloutPool.PoolState.SUBMITTED));
        assertEq(p2.resolvedAt, block.timestamp);
        assertEq(p2.losingStakerCount, pool.noStakerCount(poolId));
        assertTrue(p2.yesWins);
    }

    // -------------------------------------------------------------------------
    // Test 14 (NC-012A #2) — resolvePool: success noWins
    // -------------------------------------------------------------------------

    function test_resolvePool_success_noWins() public {
        uint256 poolId = _createAndClosePoolWithNoStaker();

        vm.expectEmit(true, false, false, true);
        emit PoolResolved(poolId, false, block.timestamp);
        vm.prank(resolver);
        pool.resolvePool(poolId, false);

        CloutPool.Pool memory p2 = pool.getPool(poolId);
        assertEq(uint8(p2.state), uint8(CloutPool.PoolState.SUBMITTED));
        assertEq(p2.losingStakerCount, pool.yesStakerCount(poolId));
        assertFalse(p2.yesWins);
    }

    // -------------------------------------------------------------------------
    // Test 15 (NC-012A #3) — resolvePool: reverts not resolver
    // -------------------------------------------------------------------------

    function test_resolvePool_revertsNotResolver() public {
        uint256 poolId = _createAndClosePoolWithNoStaker();

        vm.prank(staker1);
        vm.expectRevert(CloutPool.NotResolver.selector);
        pool.resolvePool(poolId, true);
    }

    // -------------------------------------------------------------------------
    // Test 16 (NC-012A #4) — resolvePool: reverts wrong state (OPEN)
    // -------------------------------------------------------------------------

    function test_resolvePool_revertsWrongState_open() public {
        uint256 poolId = _defaultCreatePool();

        vm.prank(resolver);
        vm.expectRevert(CloutPool.WrongState.selector);
        pool.resolvePool(poolId, true);
    }

    // -------------------------------------------------------------------------
    // Test 17 (NC-012A #5) — resolvePool: zero losing stakers → immediate FINALIZED
    // -------------------------------------------------------------------------

    function test_resolvePool_zeroLosingStakers_immediateFinalize() public {
        // Pool with only YES stakers (host); no NO stakers
        uint256 poolId = _defaultCreatePool();
        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.eventStart);
        pool.closePool(poolId);
        vm.warp(p.eventEnd);

        vm.expectEmit(true, false, false, true);
        emit PoolResolved(poolId, true, block.timestamp);
        vm.expectEmit(true, false, false, true);
        emit PoolFinalized(poolId, true);

        vm.prank(resolver);
        pool.resolvePool(poolId, true);

        CloutPool.Pool memory p2 = pool.getPool(poolId);
        assertEq(uint8(p2.state), uint8(CloutPool.PoolState.FINALIZED));
        assertEq(p2.losingStakerCount, 0);
    }

    // -------------------------------------------------------------------------
    // Test 18 (NC-012A #6) — resolvePool: reverts after resolveBy
    // -------------------------------------------------------------------------

    function test_resolvePool_revertsAfterResolveBy() public {
        uint256 poolId = _createAndClosePoolWithNoStaker();

        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.resolveBy + 1);

        vm.prank(resolver);
        vm.expectRevert(CloutPool.ResolverDeadlinePassed.selector);
        pool.resolvePool(poolId, true);
    }

    // -------------------------------------------------------------------------
    // Test 19 (NC-012A #7) — disputePool: single flag below threshold
    // -------------------------------------------------------------------------

    function test_disputePool_success_flagCounted_belowThreshold() public {
        uint256 poolId = _createAndClosePoolWithMultipleNoStakers(5);

        vm.prank(resolver);
        pool.resolvePool(poolId, true); // YES wins, NO side loses (5 stakers)

        vm.expectEmit(true, true, false, true);
        emit PoolDisputeFlagged(poolId, staker1, 1);
        vm.prank(staker1);
        pool.disputePool(poolId);

        CloutPool.Pool memory p = pool.getPool(poolId);
        assertEq(p.flagCount, 1);
        assertEq(uint8(p.state), uint8(CloutPool.PoolState.SUBMITTED)); // threshold not met
    }

    // -------------------------------------------------------------------------
    // Test 20 (NC-012A #8) — disputePool: threshold met → DISPUTED
    // -------------------------------------------------------------------------

    function test_disputePool_thresholdMet_triggersDisputed() public {
        uint256 poolId = _createAndClosePoolWithMultipleNoStakers(5);

        vm.prank(resolver);
        pool.resolvePool(poolId, true); // YES wins, 5 NO losers

        // 2 flags: 2*10000=20000 > 5*2000=10000 → threshold met
        vm.prank(staker1);
        pool.disputePool(poolId);

        vm.expectEmit(true, false, false, false);
        emit PoolDisputeTriggered(poolId);
        vm.prank(staker2);
        pool.disputePool(poolId);

        CloutPool.Pool memory p = pool.getPool(poolId);
        assertEq(uint8(p.state), uint8(CloutPool.PoolState.DISPUTED));
        assertEq(p.flagCount, 2);
    }

    // -------------------------------------------------------------------------
    // Test 21 (NC-012A #9) — disputePool: winning side staker reverts
    // -------------------------------------------------------------------------

    function test_disputePool_revertsWinningSideStaker() public {
        uint256 poolId = _createAndClosePoolWithNoStaker();

        vm.prank(resolver);
        pool.resolvePool(poolId, true); // YES wins; host is YES staker

        vm.prank(host);
        vm.expectRevert(CloutPool.NotLosingStaker.selector);
        pool.disputePool(poolId);
    }

    // -------------------------------------------------------------------------
    // Test 22 (NC-012A #10) — disputePool: already flagged reverts AlreadyFlagged
    // -------------------------------------------------------------------------

    function test_disputePool_revertsAlreadyFlagged() public {
        // Need 5 NO losers so first flag (1*10000 = 10000, NOT > 5*2000 = 10000) doesn't trigger DISPUTED
        uint256 poolId = _createAndClosePoolWithMultipleNoStakers(5);

        vm.prank(resolver);
        pool.resolvePool(poolId, true);

        vm.prank(staker1);
        pool.disputePool(poolId);

        vm.prank(staker1);
        vm.expectRevert(CloutPool.AlreadyFlagged.selector);
        pool.disputePool(poolId);
    }

    // -------------------------------------------------------------------------
    // Test 23 (NC-012A #11) — disputePool: window expired reverts
    // -------------------------------------------------------------------------

    function test_disputePool_revertsWindowExpired() public {
        uint256 poolId = _createAndClosePoolWithNoStaker();

        vm.prank(resolver);
        pool.resolvePool(poolId, true);

        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.resolvedAt + 86400 + 1);

        vm.prank(staker1);
        vm.expectRevert(CloutPool.DisputeWindowExpired.selector);
        pool.disputePool(poolId);
    }

    // -------------------------------------------------------------------------
    // Test 24 (NC-012A #12) — disputePool: wrong state (OPEN) reverts
    // -------------------------------------------------------------------------

    function test_disputePool_revertsWrongState_open() public {
        uint256 poolId = _defaultCreatePool();

        vm.prank(staker1);
        vm.expectRevert(CloutPool.WrongState.selector);
        pool.disputePool(poolId);
    }

    // -------------------------------------------------------------------------
    // Test 25 (NC-012A #13) — finalizePool: success after 24h
    // -------------------------------------------------------------------------

    function test_finalizePool_success() public {
        uint256 poolId = _createAndClosePoolWithNoStaker();

        vm.prank(resolver);
        pool.resolvePool(poolId, true);

        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.resolvedAt + 86400 + 1);

        vm.expectEmit(true, false, false, true);
        emit PoolFinalized(poolId, true);
        pool.finalizePool(poolId);

        CloutPool.Pool memory p2 = pool.getPool(poolId);
        assertEq(uint8(p2.state), uint8(CloutPool.PoolState.FINALIZED));
    }

    // -------------------------------------------------------------------------
    // Test 26 (NC-012A #14) — finalizePool: reverts before window expires
    // -------------------------------------------------------------------------

    function test_finalizePool_revertsBeforeWindow() public {
        uint256 poolId = _createAndClosePoolWithNoStaker();

        vm.prank(resolver);
        pool.resolvePool(poolId, true);

        vm.expectRevert(CloutPool.DisputeWindowOpen.selector);
        pool.finalizePool(poolId);
    }

    // -------------------------------------------------------------------------
    // Test 27 (NC-012A #15) — finalizePool: reverts on DISPUTED state
    // -------------------------------------------------------------------------

    function test_finalizePool_revertsDisputedState() public {
        uint256 poolId = _createAndClosePoolWithMultipleNoStakers(5);

        vm.prank(resolver);
        pool.resolvePool(poolId, true);

        // Trigger dispute
        vm.prank(staker1);
        pool.disputePool(poolId);
        vm.prank(staker2);
        pool.disputePool(poolId); // triggers DISPUTED

        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.resolvedAt + 86400 + 1);

        vm.expectRevert(CloutPool.WrongState.selector);
        pool.finalizePool(poolId);
    }

    // -------------------------------------------------------------------------
    // Test 28 (NC-012A #16) — adminResolvePool: success
    // -------------------------------------------------------------------------

    function test_adminResolvePool_success() public {
        uint256 poolId = _createAndClosePoolWithMultipleNoStakers(5);

        vm.prank(resolver);
        pool.resolvePool(poolId, true);

        vm.prank(staker1);
        pool.disputePool(poolId);
        vm.prank(staker2);
        pool.disputePool(poolId); // triggers DISPUTED

        vm.expectEmit(true, false, false, true);
        emit PoolFinalized(poolId, false); // admin overrides to false
        pool.adminResolvePool(poolId, false);

        CloutPool.Pool memory p = pool.getPool(poolId);
        assertEq(uint8(p.state), uint8(CloutPool.PoolState.FINALIZED));
        assertFalse(p.yesWins);
    }

    // -------------------------------------------------------------------------
    // Test 29 (NC-012A #17) — adminResolvePool: non-admin reverts
    // -------------------------------------------------------------------------

    function test_adminResolvePool_revertsNotAdmin() public {
        uint256 poolId = _createAndClosePoolWithMultipleNoStakers(5);

        vm.prank(resolver);
        pool.resolvePool(poolId, true);

        vm.prank(staker1);
        pool.disputePool(poolId);
        vm.prank(staker2);
        pool.disputePool(poolId);

        vm.prank(staker1);
        vm.expectRevert();
        pool.adminResolvePool(poolId, false);
    }

    // -------------------------------------------------------------------------
    // Test 30 (NC-012A #18) — adminResolvePool: wrong state (SUBMITTED) reverts
    // -------------------------------------------------------------------------

    function test_adminResolvePool_revertsWrongState_submitted() public {
        uint256 poolId = _createAndClosePoolWithNoStaker();

        vm.prank(resolver);
        pool.resolvePool(poolId, true); // state = SUBMITTED

        vm.expectRevert(CloutPool.WrongState.selector);
        pool.adminResolvePool(poolId, false);
    }

    // -------------------------------------------------------------------------
    // Helpers for NC-012B tests
    // -------------------------------------------------------------------------

    /// Setup: host YES=STAKE, staker1 NO=STAKE, closed, resolver submits YES, finalized.
    /// Pool: yesWins=true, state=FINALIZED, totalYes=STAKE, totalNo=STAKE.
    function _createFinalizedPool_yesWins() internal returns (uint256 poolId) {
        poolId = _defaultCreatePool();
        vm.prank(staker1);
        pool.stakePool(poolId, false, STAKE);
        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.eventStart);
        pool.closePool(poolId);
        vm.warp(p.eventEnd);
        vm.prank(resolver);
        pool.resolvePool(poolId, true);
        CloutPool.Pool memory p2 = pool.getPool(poolId);
        vm.warp(p2.resolvedAt + 86400 + 1);
        pool.finalizePool(poolId);
    }

    /// Setup: host YES=STAKE, staker1 YES=STAKE, staker2 NO=STAKE, closed, NO wins, finalized.
    /// Pool: yesWins=false, state=FINALIZED, totalYes=2*STAKE, totalNo=STAKE.
    function _createFinalizedPool_noWins() internal returns (uint256 poolId) {
        poolId = _defaultCreatePool();
        vm.prank(staker1);
        pool.stakePool(poolId, true, STAKE);
        vm.prank(staker2);
        pool.stakePool(poolId, false, STAKE);
        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.eventStart);
        pool.closePool(poolId);
        vm.warp(p.eventEnd);
        vm.prank(resolver);
        pool.resolvePool(poolId, false);
        CloutPool.Pool memory p2 = pool.getPool(poolId);
        vm.warp(p2.resolvedAt + 86400 + 1);
        pool.finalizePool(poolId);
    }

    /// Setup: host YES=STAKE, staker1 NO=STAKE, closed. Does NOT resolve.
    /// Pool: state=CLOSED.
    function _createClosedPool_notResolved() internal returns (uint256 poolId) {
        poolId = _defaultCreatePool();
        vm.prank(staker1);
        pool.stakePool(poolId, false, STAKE);
        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.eventStart);
        pool.closePool(poolId);
    }

    // -------------------------------------------------------------------------
    // Test 31 (NC-012B #1) — claimPoolWinnings: YES wins, fee order and payout
    // -------------------------------------------------------------------------

    function test_claimPoolWinnings_yesWins_feeOrderAndPayout() public {
        uint256 poolId = _createFinalizedPool_yesWins();
        // totalYes=100e6, totalNo=100e6, totalPool=200e6
        // protocolFee = 200e6 * 250 / 10000 = 5e6
        // hostCommission = 100e6 * 500 / 10000 = 5e6  (hostCommissionBps=500)
        // netLosingPool = 100e6 - 5e6 - 5e6 = 90e6
        // host is last YES winner (yesStakerCount=1): winShare = 90e6
        // payout = 100e6 + 90e6 = 190e6

        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 hostBefore     = token.balanceOf(host);

        vm.expectEmit(true, true, false, true);
        emit WinningsClaimed(poolId, host, 190 * 1e6);
        vm.prank(host);
        pool.claimPoolWinnings(poolId);

        assertEq(token.balanceOf(treasury), treasuryBefore + 5 * 1e6);
        // host receives commission (5e6) + payout (190e6) = 195e6
        assertEq(token.balanceOf(host), hostBefore + 195 * 1e6);
        assertTrue(pool.feesPaid(poolId));
        assertEq(pool.snapshotProtocolFee(poolId), 5 * 1e6);
        assertEq(pool.snapshotHostCommission(poolId), 5 * 1e6);

        // staker1 (NO loser) cannot claim
        vm.prank(staker1);
        vm.expectRevert(CloutPool.NotWinningStaker.selector);
        pool.claimPoolWinnings(poolId);
    }

    // -------------------------------------------------------------------------
    // Test 31B (NC-012B) — claimPoolWinnings: zero-loser pool, no fee
    // -------------------------------------------------------------------------

    function test_claimPoolWinnings_zeroLoserPool_noFee() public {
        // Pool with only host YES stake; no NO stakers → immediate FINALIZED on resolve
        uint256 poolId = _defaultCreatePool();
        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.eventStart);
        pool.closePool(poolId);
        vm.warp(p.eventEnd);
        vm.prank(resolver);
        pool.resolvePool(poolId, true); // losingCount=0 → immediate FINALIZED

        uint256 hostBefore     = token.balanceOf(host);
        uint256 treasuryBefore = token.balanceOf(treasury);

        vm.expectEmit(true, true, false, true);
        emit WinningsClaimed(poolId, host, STAKE);
        vm.prank(host);
        pool.claimPoolWinnings(poolId);

        assertEq(token.balanceOf(host), hostBefore + STAKE);
        assertEq(token.balanceOf(treasury), treasuryBefore); // no fee taken
        assertEq(token.balanceOf(address(pool)), 0);          // contract fully drained
        assertEq(pool.snapshotProtocolFee(poolId), 0);
        assertEq(pool.snapshotHostCommission(poolId), 0);
    }

    // -------------------------------------------------------------------------
    // Test 32 (NC-012B #2) — claimPoolWinnings: NO wins, no commission (I-12)
    // -------------------------------------------------------------------------

    function test_claimPoolWinnings_noWins_noCommission() public {
        uint256 poolId = _createFinalizedPool_noWins();
        // totalYes=200e6, totalNo=100e6, totalPool=300e6
        // protocolFee = 300e6 * 250 / 10000 = 7500000
        // hostCommission = 0 (NO wins, I-12)
        // netLosingPool = 200e6 - 7500000 = 192500000
        // staker2 (only NO staker, last): winShare = 192500000
        // payout = 100e6 + 192500000 = 292500000

        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 staker2Before  = token.balanceOf(staker2);

        vm.prank(staker2);
        pool.claimPoolWinnings(poolId);

        assertEq(token.balanceOf(treasury), treasuryBefore + 7500000);
        assertEq(token.balanceOf(staker2), staker2Before + 292500000);
        assertEq(pool.snapshotHostCommission(poolId), 0);

        // host (YES loser) cannot claim
        vm.prank(host);
        vm.expectRevert(CloutPool.NotWinningStaker.selector);
        pool.claimPoolWinnings(poolId);

        // staker1 (YES loser) cannot claim
        vm.prank(staker1);
        vm.expectRevert(CloutPool.NotWinningStaker.selector);
        pool.claimPoolWinnings(poolId);
    }

    // -------------------------------------------------------------------------
    // Test 33 (NC-012B #3) — claimPoolWinnings: proportional payout, 3 YES stakers (I-14)
    // -------------------------------------------------------------------------

    function test_claimPoolWinnings_proportional_threeStakers() public {
        uint256 poolId = _defaultCreatePool(); // host YES=100e6
        vm.prank(staker1);
        pool.stakePool(poolId, true, 200 * 1e6);  // staker1 YES=200e6
        vm.prank(staker2);
        pool.stakePool(poolId, true, 300 * 1e6);  // staker2 YES=300e6
        vm.prank(staker3);
        pool.stakePool(poolId, false, 100 * 1e6); // staker3 NO=100e6

        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.eventStart);
        pool.closePool(poolId);
        vm.warp(p.eventEnd);
        vm.prank(resolver);
        pool.resolvePool(poolId, true);
        CloutPool.Pool memory p2 = pool.getPool(poolId);
        vm.warp(p2.resolvedAt + 86400 + 1);
        pool.finalizePool(poolId);

        // totalYes=600e6, totalNo=100e6, totalPool=700e6
        // protocolFee = 700e6 * 250 / 10000 = 17500000
        // hostCommission = 600e6 * 500 / 10000 = 30000000
        // netLosingPool = 100e6 - 47500000 = 52500000
        // host (not last): winShare = mulDiv(100e6, 52500000, 600e6) = 8750000
        // staker1 (not last): winShare = mulDiv(200e6, 52500000, 600e6) = 17500000
        // staker2 (last): winShare = 52500000 - 8750000 - 17500000 = 26250000

        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 hostBefore     = token.balanceOf(host);
        uint256 staker1Before  = token.balanceOf(staker1);
        uint256 staker2Before  = token.balanceOf(staker2);

        vm.prank(host);
        pool.claimPoolWinnings(poolId);

        vm.prank(staker1);
        pool.claimPoolWinnings(poolId);

        vm.prank(staker2);
        pool.claimPoolWinnings(poolId);

        assertEq(token.balanceOf(treasury), treasuryBefore + 17500000);
        // host receives commission (30e6) + payout (100e6 + 8750000)
        assertEq(token.balanceOf(host), hostBefore + 30000000 + 108750000);
        assertEq(token.balanceOf(staker1), staker1Before + 217500000);
        assertEq(token.balanceOf(staker2), staker2Before + 326250000);
        assertEq(token.balanceOf(address(pool)), 0);
    }

    // -------------------------------------------------------------------------
    // Test 34 (NC-012B #4) — claimPoolWinnings: rounding dust absorbed by last claimer
    // -------------------------------------------------------------------------

    function test_claimPoolWinnings_roundingDust() public {
        // Create pool with non-uniform YES stakes to induce rounding
        vm.prank(host);
        uint256 poolId = pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500 * 1e6,
            1000 * 1e6,
            500,         // hostCommissionBps
            101 * 1e6    // initialYesStake
        );

        vm.prank(staker1);
        pool.stakePool(poolId, true, 99 * 1e6);   // staker1 YES=99e6

        vm.prank(staker2);
        pool.stakePool(poolId, false, 57 * 1e6);  // staker2 NO=57e6

        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.eventStart);
        pool.closePool(poolId);
        vm.warp(p.eventEnd);
        vm.prank(resolver);
        pool.resolvePool(poolId, true);
        CloutPool.Pool memory p2 = pool.getPool(poolId);
        vm.warp(p2.resolvedAt + 86400 + 1);
        pool.finalizePool(poolId);

        uint256 contractBefore = token.balanceOf(address(pool));
        assertEq(contractBefore, 257 * 1e6);

        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 hostBefore     = token.balanceOf(host);
        uint256 staker1Before  = token.balanceOf(staker1);

        vm.prank(host);
        pool.claimPoolWinnings(poolId);

        vm.prank(staker1);
        pool.claimPoolWinnings(poolId);

        // Contract fully drained
        assertEq(token.balanceOf(address(pool)), 0);

        // Conservation: all outflows sum to total pool
        uint256 hostGain     = token.balanceOf(host) - hostBefore;
        uint256 staker1Gain  = token.balanceOf(staker1) - staker1Before;
        uint256 treasuryGain = token.balanceOf(treasury) - treasuryBefore;
        assertEq(hostGain + staker1Gain + treasuryGain, 257 * 1e6);
    }

    // -------------------------------------------------------------------------
    // Test 35 (NC-012B #5) — claimPoolWinnings: reverts from wrong states
    // -------------------------------------------------------------------------

    function test_claimPoolWinnings_revertsWrongState() public {
        // Sub-case A: OPEN
        uint256 poolId = _defaultCreatePool();
        vm.prank(host);
        vm.expectRevert(CloutPool.WrongState.selector);
        pool.claimPoolWinnings(poolId);

        // Sub-case B: CLOSED
        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.eventStart);
        pool.closePool(poolId);
        vm.prank(host);
        vm.expectRevert(CloutPool.WrongState.selector);
        pool.claimPoolWinnings(poolId);

        // Sub-case C: SUBMITTED
        uint256 poolId2 = _createAndClosePoolWithNoStaker();
        vm.prank(resolver);
        pool.resolvePool(poolId2, true);
        vm.prank(host);
        vm.expectRevert(CloutPool.WrongState.selector);
        pool.claimPoolWinnings(poolId2);

        // Sub-case D: DISPUTED
        uint256 poolId3 = _createAndClosePoolWithMultipleNoStakers(5);
        vm.prank(resolver);
        pool.resolvePool(poolId3, true);
        vm.prank(staker1);
        pool.disputePool(poolId3);
        vm.prank(staker2);
        pool.disputePool(poolId3); // triggers DISPUTED
        vm.prank(host);
        vm.expectRevert(CloutPool.WrongState.selector);
        pool.claimPoolWinnings(poolId3);
    }

    // -------------------------------------------------------------------------
    // Test 36 (NC-012B #6) — claimPoolWinnings: reverts AlreadyClaimed
    // -------------------------------------------------------------------------

    function test_claimPoolWinnings_revertsAlreadyClaimed() public {
        uint256 poolId = _createFinalizedPool_yesWins();

        vm.prank(host);
        pool.claimPoolWinnings(poolId);

        vm.prank(host);
        vm.expectRevert(CloutPool.AlreadyClaimed.selector);
        pool.claimPoolWinnings(poolId);
    }

    // -------------------------------------------------------------------------
    // Test 37 (NC-012B #7) — claimPoolWinnings: reverts NotWinningStaker
    // -------------------------------------------------------------------------

    function test_claimPoolWinnings_revertsNotWinningStaker() public {
        uint256 poolId = _createFinalizedPool_yesWins();
        // yesWins=true; host=YES (winner), staker1=NO (loser)

        // staker2 has no stake at all
        vm.prank(staker2);
        vm.expectRevert(CloutPool.NotWinningStaker.selector);
        pool.claimPoolWinnings(poolId);

        // staker1 is on the losing NO side
        vm.prank(staker1);
        vm.expectRevert(CloutPool.NotWinningStaker.selector);
        pool.claimPoolWinnings(poolId);
    }

    // -------------------------------------------------------------------------
    // Test 38 (NC-012B #8) — voidPool: resolver timeout from CLOSED
    // -------------------------------------------------------------------------

    function test_voidPool_resolveByTimeout() public {
        uint256 poolId = _createClosedPool_notResolved();
        CloutPool.Pool memory p = pool.getPool(poolId);

        vm.warp(p.resolveBy + 1);

        vm.expectEmit(true, false, false, false);
        emit PoolVoided(poolId);
        pool.voidPool(poolId);

        CloutPool.Pool memory p2 = pool.getPool(poolId);
        assertEq(uint8(p2.state), uint8(CloutPool.PoolState.VOIDED));
    }

    // -------------------------------------------------------------------------
    // Test 39 (NC-012B #9) — voidPool: OPEN with no audience stakers
    // -------------------------------------------------------------------------

    function test_voidPool_noStakers() public {
        uint256 poolId = _defaultCreatePool(); // only host staked YES
        CloutPool.Pool memory p = pool.getPool(poolId);

        vm.warp(p.eventStart);

        vm.expectEmit(true, false, false, false);
        emit PoolVoided(poolId);
        pool.voidPool(poolId);

        CloutPool.Pool memory p2 = pool.getPool(poolId);
        assertEq(uint8(p2.state), uint8(CloutPool.PoolState.VOIDED));
    }

    // -------------------------------------------------------------------------
    // Test 39B (NC-012B) — voidPool: host staked both sides, no audience
    // -------------------------------------------------------------------------

    function test_voidPool_noStakers_hostStakedBothSides() public {
        uint256 poolId = _defaultCreatePool(); // host YES=STAKE

        // Host also stakes NO — still only host in the pool
        vm.prank(host);
        pool.stakePool(poolId, false, STAKE);

        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.eventStart);

        vm.expectEmit(true, false, false, false);
        emit PoolVoided(poolId);
        pool.voidPool(poolId);

        CloutPool.Pool memory p2 = pool.getPool(poolId);
        assertEq(uint8(p2.state), uint8(CloutPool.PoolState.VOIDED));

        // Host claims both sides back, no fee
        uint256 hostBefore = token.balanceOf(host);
        vm.prank(host);
        pool.claimPoolWinnings(poolId);

        assertEq(token.balanceOf(host), hostBefore + STAKE + STAKE);
        assertEq(token.balanceOf(address(pool)), 0);
    }

    // -------------------------------------------------------------------------
    // Test 40 (NC-012B #10) — voidPool: reverts NotVoidable
    // -------------------------------------------------------------------------

    function test_voidPool_revertsNotVoidable() public {
        // Sub-case A: OPEN before eventStart
        uint256 poolId = _defaultCreatePool();
        vm.expectRevert(CloutPool.NotVoidable.selector);
        pool.voidPool(poolId);

        // Sub-case B: CLOSED before resolveBy
        uint256 poolId2 = _createClosedPool_notResolved();
        // resolveBy has not passed yet
        vm.expectRevert(CloutPool.NotVoidable.selector);
        pool.voidPool(poolId2);

        // Sub-case C: SUBMITTED pool
        uint256 poolId3 = _createAndClosePoolWithNoStaker();
        vm.prank(resolver);
        pool.resolvePool(poolId3, true); // state = SUBMITTED
        vm.expectRevert(CloutPool.NotVoidable.selector);
        pool.voidPool(poolId3);

        // Sub-case D: OPEN with another YES staker (yesStakerCount=2)
        uint256 poolId4 = _defaultCreatePool();
        vm.prank(staker1);
        pool.stakePool(poolId4, true, STAKE); // yesStakerCount=2
        CloutPool.Pool memory p4 = pool.getPool(poolId4);
        vm.warp(p4.eventStart);
        vm.expectRevert(CloutPool.NotVoidable.selector);
        pool.voidPool(poolId4);
    }

    // -------------------------------------------------------------------------
    // Test 41 (NC-012B #11) — voidPool: refund YES staker via claimPoolWinnings
    // -------------------------------------------------------------------------

    function test_voidPool_refundClaim_yesStaker() public {
        uint256 poolId = _createClosedPool_notResolved();
        // host staked YES=STAKE; staker1 staked NO=STAKE
        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.resolveBy + 1);
        pool.voidPool(poolId);

        uint256 hostBefore = token.balanceOf(host);

        vm.expectEmit(true, true, false, true);
        emit WinningsClaimed(poolId, host, STAKE);
        vm.prank(host);
        pool.claimPoolWinnings(poolId);

        assertEq(token.balanceOf(host), hostBefore + STAKE);
    }

    // -------------------------------------------------------------------------
    // Test 42 (NC-012B #12) — voidPool: refund NO staker via claimPoolWinnings
    // -------------------------------------------------------------------------

    function test_voidPool_refundClaim_noStaker() public {
        uint256 poolId = _createClosedPool_notResolved();
        CloutPool.Pool memory p = pool.getPool(poolId);
        vm.warp(p.resolveBy + 1);
        pool.voidPool(poolId);

        uint256 staker1Before = token.balanceOf(staker1);

        vm.expectEmit(true, true, false, true);
        emit WinningsClaimed(poolId, staker1, STAKE);
        vm.prank(staker1);
        pool.claimPoolWinnings(poolId);

        assertEq(token.balanceOf(staker1), staker1Before + STAKE);
    }

    // -------------------------------------------------------------------------
    // Test 43 (NC-012B #13) — claimPoolWinnings: reverts on CLOSED (before void)
    // -------------------------------------------------------------------------

    function test_claimPoolWinnings_revertsBeforeVoid() public {
        uint256 poolId = _createClosedPool_notResolved();
        // state = CLOSED, not yet voided

        vm.prank(staker1);
        vm.expectRevert(CloutPool.WrongState.selector);
        pool.claimPoolWinnings(poolId);
    }
}
