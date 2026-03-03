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

    CloutPool pool;
    MockStablecoin token;

    address admin    = address(this);
    address host     = address(0xA0);
    address resolver = address(0xB0);
    address staker1  = address(0xC0);
    address staker2  = address(0xD0);
    address treasury = address(0xFEE1);

    uint256 constant STAKE = 100 * 1e6; // 100 USDC (6 decimals)

    function setUp() public {
        token = new MockStablecoin();
        pool  = new CloutPool();

        pool.addWhitelistedToken(address(token));
        pool.setTreasury(treasury);

        // Mint and approve for all actors
        address[5] memory actors = [host, resolver, staker1, staker2, treasury];
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
}
