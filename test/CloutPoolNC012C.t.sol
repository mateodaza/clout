// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CloutPool} from "../src/CloutPool.sol";
import {MockStablecoin} from "../src/MockStablecoin.sol";

contract CloutPoolNC012CTest is Test {
    CloutPool pool;
    MockStablecoin token;

    address admin    = address(this);
    address host     = address(0xA0);
    address resolver = address(0xB0);
    address staker1  = address(0xC0);
    address staker2  = address(0xD0);
    address staker3  = address(0xE0);
    address treasury = address(0xFEE1);

    uint256 constant STAKE = 100 * 1e6; // 100 USDC (6 decimals)

    function setUp() public {
        token = new MockStablecoin();
        pool  = new CloutPool();

        pool.addWhitelistedToken(address(token));
        pool.setTreasury(treasury);

        token.mint(host,    10_000e6);
        token.mint(staker1, 10_000e6);
        token.mint(staker2, 10_000e6);
        token.mint(staker3, 10_000e6);

        vm.prank(host);
        token.approve(address(pool), type(uint256).max);
        vm.prank(staker1);
        token.approve(address(pool), type(uint256).max);
        vm.prank(staker2);
        token.approve(address(pool), type(uint256).max);
        vm.prank(staker3);
        token.approve(address(pool), type(uint256).max);
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    /// @dev Creates a default pool: host YES=STAKE, resolver=resolver, 1d/2d/3d timestamps, caps 500e6/1000e6, commission 5%.
    function _defaultCreatePool() internal returns (uint256 poolId) {
        vm.prank(host);
        poolId = pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,  // eventStart
            block.timestamp + 2 days,  // eventEnd
            block.timestamp + 3 days,  // resolveBy
            500e6,                     // perWalletCap
            1000e6,                    // totalPoolCap
            500,                       // hostCommissionBps (5%)
            STAKE                      // initialYesStake = 100e6
        );
    }

    /// @dev Creates pool (host YES=STAKE), adds staker1 NO=STAKE, then closes at eventStart.
    function _createAndClose() internal returns (uint256 poolId) {
        poolId = _defaultCreatePool();
        vm.prank(staker1);
        pool.stakePool(poolId, false, STAKE);
        vm.warp(pool.getPool(poolId).eventStart);
        pool.closePool(poolId);
    }

    /// @dev _createAndClose → resolver resolves → warp past dispute window → finalizePool.
    function _createCloseAndResolve(bool yesWins) internal returns (uint256 poolId) {
        poolId = _createAndClose();
        vm.prank(resolver);
        pool.resolvePool(poolId, yesWins);
        uint256 resolvedAt = pool.getPool(poolId).resolvedAt;
        vm.warp(resolvedAt + 86401);
        pool.finalizePool(poolId);
    }

    // ─── Test 1: I-8 — host must stake YES ───────────────────────────────────

    function test_invariant_I8_hostMustStakeYes() public {
        // Sub-case A: zero initialYesStake reverts ZeroStake
        vm.prank(host);
        vm.expectRevert(CloutPool.ZeroStake.selector);
        pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500e6,
            1000e6,
            500,
            0
        );

        // Sub-case B: non-zero initialYesStake succeeds → pool is OPEN
        uint256 poolId = _defaultCreatePool();
        CloutPool.Pool memory p = pool.getPool(poolId);
        assertEq(uint8(p.state), uint8(CloutPool.PoolState.OPEN));
        assertEq(p.yesTotal, STAKE);
    }

    // ─── Test 2: I-9 — host cannot be resolver ────────────────────────────────

    function test_invariant_I9_hostCannotBeResolver() public {
        // Sub-case A: resolver == host → HostIsResolver
        vm.prank(host);
        vm.expectRevert(CloutPool.HostIsResolver.selector);
        pool.createPool(
            host,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500e6,
            1000e6,
            500,
            STAKE
        );

        // Sub-case B: resolver == address(0) → ZeroResolver
        vm.prank(host);
        vm.expectRevert(CloutPool.ZeroResolver.selector);
        pool.createPool(
            address(0),
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500e6,
            1000e6,
            500,
            STAKE
        );
    }

    // ─── Test 3: I-10 — per-wallet cap enforced ──────────────────────────────

    function test_invariant_I10_perWalletCapEnforced() public {
        // Sub-case A: single stake exceeds perWalletCap → PerWalletCapExceeded
        vm.prank(host);
        uint256 poolIdA = pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            200e6,   // perWalletCap = 200e6
            1000e6,
            500,
            STAKE    // host YES=100e6 (within cap)
        );
        vm.prank(staker1);
        vm.expectRevert(CloutPool.PerWalletCapExceeded.selector);
        pool.stakePool(poolIdA, false, 201e6); // 201e6 > 200e6

        // Sub-case B: cumulative stake exceeds cap → PerWalletCapExceeded
        vm.prank(host);
        uint256 poolIdB = pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            200e6,   // perWalletCap = 200e6
            1000e6,
            500,
            STAKE
        );
        vm.prank(staker1);
        pool.stakePool(poolIdB, false, 150e6); // OK: 150e6 <= 200e6
        vm.prank(staker1);
        vm.expectRevert(CloutPool.PerWalletCapExceeded.selector);
        pool.stakePool(poolIdB, false, 51e6);  // cumulative 201e6 > 200e6
    }

    // ─── Test 4: I-11 — total pool cap enforced ──────────────────────────────

    function test_invariant_I11_totalPoolCapEnforced() public {
        // totalPoolCap = 300e6, host YES=100e6
        vm.prank(host);
        uint256 poolId = pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500e6,
            300e6,   // totalPoolCap = 300e6
            500,
            STAKE    // host YES=100e6 → totalPool=100e6
        );
        // staker1 stakes 100e6 NO → totalPool=200e6 (OK)
        vm.prank(staker1);
        pool.stakePool(poolId, false, STAKE);
        // staker2 tries 101e6 YES → totalPool would be 301e6 > 300e6
        vm.prank(staker2);
        vm.expectRevert(CloutPool.TotalCapExceeded.selector);
        pool.stakePool(poolId, true, 101e6);
    }

    // ─── Test 5: I-12 — host commission only on YES win ──────────────────────

    function test_invariant_I12_commissionOnlyOnYesWin() public {
        // Part A — YES wins: host YES=100e6, staker1 NO=100e6
        {
            uint256 poolId = _createCloseAndResolve(true);
            vm.prank(host);
            pool.claimPoolWinnings(poolId);
            // commission = 100e6 * 500 / 10000 = 5,000,000
            assertEq(pool.snapshotHostCommission(poolId), 5_000_000);
        }

        // Part B — NO wins: host YES=100e6, staker1 YES=100e6, staker2 NO=100e6
        {
            vm.prank(host);
            uint256 poolId = pool.createPool(
                resolver,
                address(token),
                block.timestamp + 1 days,
                block.timestamp + 2 days,
                block.timestamp + 3 days,
                500e6,
                1000e6,
                500,
                STAKE // host YES=100e6
            );
            vm.prank(staker1);
            pool.stakePool(poolId, true, STAKE);  // staker1 YES=100e6
            vm.prank(staker2);
            pool.stakePool(poolId, false, STAKE); // staker2 NO=100e6

            vm.warp(pool.getPool(poolId).eventStart);
            pool.closePool(poolId);

            vm.prank(resolver);
            pool.resolvePool(poolId, false); // NO wins
            vm.warp(pool.getPool(poolId).resolvedAt + 86401);
            pool.finalizePool(poolId);

            // staker2 is the only NO winner (last)
            uint256 staker2Before = token.balanceOf(staker2);
            vm.prank(staker2);
            pool.claimPoolWinnings(poolId);

            // I-12: hostCommission == 0 on NO win (set at first claim)
            assertEq(pool.snapshotHostCommission(poolId), 0);

            // Math: totalPool=300e6, fee=7,500,000, netLosingPool=192,500,000
            // staker2 is last → payout = 100e6 + 192,500,000 = 292,500,000
            assertEq(token.balanceOf(staker2), staker2Before + 292_500_000);

            // Losers cannot claim
            vm.prank(host);
            vm.expectRevert(CloutPool.NotWinningStaker.selector);
            pool.claimPoolWinnings(poolId);

            vm.prank(staker1);
            vm.expectRevert(CloutPool.NotWinningStaker.selector);
            pool.claimPoolWinnings(poolId);
        }
    }

    // ─── Test 6: I-13 — protocol fee on non-void outcomes, NOT on void ───────

    function test_invariant_I13_protocolFeeOnNonVoid() public {
        // Part A — YES wins: host YES=100e6, staker1 NO=100e6
        {
            uint256 poolId = _createCloseAndResolve(true);
            uint256 treasuryBefore = token.balanceOf(treasury);
            vm.prank(host);
            pool.claimPoolWinnings(poolId);
            // fee = 200e6 * 250 / 10000 = 5,000,000
            assertEq(token.balanceOf(treasury), treasuryBefore + 5_000_000);
        }

        // Part B — NO wins: host YES=100e6, staker1 YES=100e6, staker2 NO=100e6
        {
            vm.prank(host);
            uint256 poolId = pool.createPool(
                resolver,
                address(token),
                block.timestamp + 1 days,
                block.timestamp + 2 days,
                block.timestamp + 3 days,
                500e6,
                1000e6,
                500,
                STAKE
            );
            vm.prank(staker1);
            pool.stakePool(poolId, true, STAKE);
            vm.prank(staker2);
            pool.stakePool(poolId, false, STAKE);

            vm.warp(pool.getPool(poolId).eventStart);
            pool.closePool(poolId);

            vm.prank(resolver);
            pool.resolvePool(poolId, false);
            vm.warp(pool.getPool(poolId).resolvedAt + 86401);
            pool.finalizePool(poolId);

            uint256 treasuryBefore = token.balanceOf(treasury);
            vm.prank(staker2);
            pool.claimPoolWinnings(poolId);
            // fee = 300e6 * 250 / 10000 = 7,500,000
            assertEq(token.balanceOf(treasury), treasuryBefore + 7_500_000);
        }

        // Part C — VOIDED (resolver timeout from CLOSED): no fee (I-13)
        {
            vm.prank(host);
            uint256 poolId = pool.createPool(
                resolver,
                address(token),
                block.timestamp + 1 days,
                block.timestamp + 2 days,
                block.timestamp + 3 days,
                500e6,
                1000e6,
                500,
                STAKE
            );
            vm.prank(staker1);
            pool.stakePool(poolId, false, STAKE);

            vm.warp(pool.getPool(poolId).eventStart);
            pool.closePool(poolId);

            vm.warp(pool.getPool(poolId).resolveBy + 1);
            pool.voidPool(poolId);

            uint256 treasuryBefore = token.balanceOf(treasury);
            vm.prank(host);
            pool.claimPoolWinnings(poolId);
            vm.prank(staker1);
            pool.claimPoolWinnings(poolId);

            // No fee on void (I-13)
            assertEq(token.balanceOf(treasury), treasuryBefore);
        }
    }

    // ─── Test 7: I-14 — proportional payout, exact checks, 3+ stakers ───────

    function test_invariant_I14_proportionalPayoutThreeStakers() public {
        // host YES=100e6, staker1 YES=200e6, staker2 YES=300e6, staker3 NO=150e6
        vm.prank(host);
        uint256 poolId = pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500e6,
            1000e6,
            500,
            STAKE // host YES=100e6
        );
        vm.prank(staker1);
        pool.stakePool(poolId, true, 200e6); // YES=200e6
        vm.prank(staker2);
        pool.stakePool(poolId, true, 300e6); // YES=300e6
        vm.prank(staker3);
        pool.stakePool(poolId, false, 150e6); // NO=150e6

        vm.warp(pool.getPool(poolId).eventStart);
        pool.closePool(poolId);

        // losingStakerCount = noStakerCount = 1 → SUBMITTED
        vm.prank(resolver);
        pool.resolvePool(poolId, true);
        vm.warp(pool.getPool(poolId).resolvedAt + 86401);
        pool.finalizePool(poolId);

        // Math:
        //   totalYes=600e6, totalNo=150e6, totalPool=750e6
        //   fee = 750e6*250/10000 = 18,750,000
        //   commission = 600e6*500/10000 = 30,000,000
        //   combinedFees = 48,750,000 < 150e6 (no clamp)
        //   netLosingPool = 150e6 - 48,750,000 = 101,250,000
        //   totalWinningSide = 600e6, 3 YES winners

        uint256 treasuryBefore = token.balanceOf(treasury);

        // host claims first (winner #0, not last)
        //   commission: 30,000,000 (separate transfer to host)
        //   winShare = mulDiv(100e6, 101,250,000, 600e6) = 16,875,000
        //   payout = 100e6 + 16,875,000 = 116,875,000
        //   host total = 30,000,000 + 116,875,000 = 146,875,000
        uint256 hostBefore = token.balanceOf(host);
        vm.prank(host);
        pool.claimPoolWinnings(poolId);
        assertEq(token.balanceOf(host), hostBefore + 30_000_000 + 116_875_000);

        // staker1 claims (winner #1, not last)
        //   winShare = mulDiv(200e6, 101,250,000, 600e6) = 33,750,000
        //   payout = 200e6 + 33,750,000 = 233,750,000
        uint256 staker1Before = token.balanceOf(staker1);
        vm.prank(staker1);
        pool.claimPoolWinnings(poolId);
        assertEq(token.balanceOf(staker1), staker1Before + 233_750_000);

        // staker2 claims last (winner #2)
        //   winShare = 101,250,000 - 16,875,000 - 33,750,000 = 50,625,000
        //   payout = 300e6 + 50,625,000 = 350,625,000
        uint256 staker2Before = token.balanceOf(staker2);
        vm.prank(staker2);
        pool.claimPoolWinnings(poolId);
        assertEq(token.balanceOf(staker2), staker2Before + 350_625_000);

        assertEq(token.balanceOf(treasury), treasuryBefore + 18_750_000);
        assertEq(token.balanceOf(address(pool)), 0);
    }

    // ─── Test 8: solvency — pool_balance >= unclaimed obligations at each step ─

    function test_solvency_afterEachStateChange() public {
        // Setup: host YES=100e6, staker1 NO=100e6, staker2 NO=100e6
        // Dispute path: resolver says YES, staker1 flags → DISPUTED, admin resolves NO
        //
        // Pre-computed payouts (NO wins):
        //   totalPool=300e6, fee=7,500,000, netLosingPool=92,500,000, totalWinningSide(NO)=200e6
        //   staker1 payout = 146,250,000; staker2 payout = 146,250,000

        // Step 1: createPool (host YES=100e6) — unclaimedObligation=100e6
        vm.prank(host);
        uint256 poolId = pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500e6,
            1000e6,
            500,
            STAKE
        );
        assertGe(token.balanceOf(address(pool)), 100e6);

        // Step 2: staker1 stakes NO=100e6 — unclaimedObligation=200e6
        vm.prank(staker1);
        pool.stakePool(poolId, false, STAKE);
        assertGe(token.balanceOf(address(pool)), 200e6);

        // Step 3: staker2 stakes NO=100e6 — unclaimedObligation=300e6
        vm.prank(staker2);
        pool.stakePool(poolId, false, STAKE);
        assertGe(token.balanceOf(address(pool)), 300e6);

        // Step 4: closePool — unclaimedObligation=300e6
        vm.warp(pool.getPool(poolId).eventStart);
        pool.closePool(poolId);
        assertGe(token.balanceOf(address(pool)), 300e6);

        // Step 5: resolvePool(true=YES) → SUBMITTED — unclaimedObligation=300e6
        vm.prank(resolver);
        pool.resolvePool(poolId, true);
        assertGe(token.balanceOf(address(pool)), 300e6);

        // Step 6: staker1 disputes (1 flag; 1*10000=10000 > 2*2000=4000 → threshold met → DISPUTED)
        vm.prank(staker1);
        pool.disputePool(poolId);
        assertEq(uint8(pool.getPool(poolId).state), uint8(CloutPool.PoolState.DISPUTED));
        assertGe(token.balanceOf(address(pool)), 300e6);

        // Step 7: adminResolvePool(false=NO) → FINALIZED
        // unclaimedObligation = staker1_payout + staker2_payout = 292,500,000
        pool.adminResolvePool(poolId, false);
        assertEq(uint8(pool.getPool(poolId).state), uint8(CloutPool.PoolState.FINALIZED));
        assertGe(token.balanceOf(address(pool)), 292_500_000);

        // Step 8: staker1 claims (fee=7,500,000 paid here, payout=146,250,000)
        // pool_balance = 300e6 - 7,500,000 - 146,250,000 = 146,250,000
        // unclaimedObligation = staker2_payout = 146,250,000
        vm.prank(staker1);
        pool.claimPoolWinnings(poolId);
        assertGe(token.balanceOf(address(pool)), 146_250_000);

        // Step 9: staker2 claims (last) — unclaimedObligation=0
        vm.prank(staker2);
        pool.claimPoolWinnings(poolId);
        assertEq(token.balanceOf(address(pool)), 0);
    }

    // ─── Test 9: full lifecycle — YES wins, 3 wallets ─────────────────────────

    function test_integration_fullLifecycle_yesWins_3wallets() public {
        // host YES=100e6, staker1 NO=100e6, staker2 NO=200e6
        vm.prank(host);
        uint256 poolId = pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500e6,
            1000e6,
            500,
            STAKE // host YES=100e6
        );
        vm.prank(staker1);
        pool.stakePool(poolId, false, STAKE);  // NO=100e6
        vm.prank(staker2);
        pool.stakePool(poolId, false, 200e6);  // NO=200e6

        vm.warp(pool.getPool(poolId).eventStart);
        pool.closePool(poolId);

        // losingStakerCount = noStakerCount = 2 → SUBMITTED
        vm.prank(resolver);
        pool.resolvePool(poolId, true);
        vm.warp(pool.getPool(poolId).resolvedAt + 86401);
        pool.finalizePool(poolId);

        // Math:
        //   totalYes=100e6, totalNo=300e6, totalPool=400e6
        //   fee = 10,000,000; commission = 5,000,000
        //   netLosingPool = 300e6 - 15,000,000 = 285,000,000
        //   host is the only YES staker (last): winShare=285,000,000; payout=385,000,000
        //   host total: commission(5,000,000) + payout(385,000,000) = 390,000,000

        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 hostBefore     = token.balanceOf(host);

        vm.prank(host);
        pool.claimPoolWinnings(poolId);

        assertEq(token.balanceOf(host),          hostBefore + 390_000_000);
        assertEq(token.balanceOf(treasury),      treasuryBefore + 10_000_000);
        assertEq(token.balanceOf(address(pool)), 0);

        // Losers cannot claim
        vm.prank(staker1);
        vm.expectRevert(CloutPool.NotWinningStaker.selector);
        pool.claimPoolWinnings(poolId);

        vm.prank(staker2);
        vm.expectRevert(CloutPool.NotWinningStaker.selector);
        pool.claimPoolWinnings(poolId);
    }

    // ─── Test 10: full lifecycle — NO wins, 3 wallets ────────────────────────

    function test_integration_fullLifecycle_noWins_3wallets() public {
        // host YES=100e6, staker1 YES=100e6, staker2 NO=100e6, staker3 NO=200e6
        vm.prank(host);
        uint256 poolId = pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500e6,
            1000e6,
            500,
            STAKE // host YES=100e6
        );
        vm.prank(staker1);
        pool.stakePool(poolId, true, STAKE);   // YES=100e6
        vm.prank(staker2);
        pool.stakePool(poolId, false, STAKE);  // NO=100e6
        vm.prank(staker3);
        pool.stakePool(poolId, false, 200e6);  // NO=200e6

        vm.warp(pool.getPool(poolId).eventStart);
        pool.closePool(poolId);

        // losingStakerCount = yesStakerCount = 2 → SUBMITTED
        vm.prank(resolver);
        pool.resolvePool(poolId, false);
        vm.warp(pool.getPool(poolId).resolvedAt + 86401);
        pool.finalizePool(poolId);

        // Math:
        //   totalYes=200e6, totalNo=300e6, totalPool=500e6
        //   fee = 12,500,000; commission = 0 (NO wins, I-12)
        //   netLosingPool = 200e6 - 12,500,000 = 187,500,000
        //   totalWinningSide = 300e6 (2 NO winners)
        //   staker2 (not last): mulDiv(100e6, 187,500,000, 300e6)=62,500,000; payout=162,500,000
        //   staker3 (last): 187,500,000 - 62,500,000 = 125,000,000; payout=325,000,000

        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 staker2Before  = token.balanceOf(staker2);
        uint256 staker3Before  = token.balanceOf(staker3);

        vm.prank(staker2);
        pool.claimPoolWinnings(poolId);
        // I-12: commission == 0 on NO win (verified after first claim sets the snapshot)
        assertEq(pool.snapshotHostCommission(poolId), 0);

        vm.prank(staker3);
        pool.claimPoolWinnings(poolId);

        assertEq(token.balanceOf(staker2),       staker2Before + 162_500_000);
        assertEq(token.balanceOf(staker3),       staker3Before + 325_000_000);
        assertEq(token.balanceOf(treasury),      treasuryBefore + 12_500_000);
        assertEq(token.balanceOf(address(pool)), 0);

        // Losers cannot claim
        vm.prank(host);
        vm.expectRevert(CloutPool.NotWinningStaker.selector);
        pool.claimPoolWinnings(poolId);

        vm.prank(staker1);
        vm.expectRevert(CloutPool.NotWinningStaker.selector);
        pool.claimPoolWinnings(poolId);
    }

    // ─── Test 11: dispute path — threshold met → admin resolves ──────────────

    function test_integration_disputePath_adminResolves() public {
        // host YES=100e6, staker1 NO=100e6, staker2 NO=100e6
        vm.prank(host);
        uint256 poolId = pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500e6,
            1000e6,
            500,
            STAKE
        );
        vm.prank(staker1);
        pool.stakePool(poolId, false, STAKE);
        vm.prank(staker2);
        pool.stakePool(poolId, false, STAKE);

        vm.warp(pool.getPool(poolId).eventStart);
        pool.closePool(poolId);

        // Resolver says YES wins → losingStakerCount=2 → SUBMITTED
        vm.prank(resolver);
        pool.resolvePool(poolId, true);
        assertEq(uint8(pool.getPool(poolId).state), uint8(CloutPool.PoolState.SUBMITTED));

        // staker1 flags: 1*10000=10000 > 2*2000=4000 → threshold met → DISPUTED
        vm.prank(staker1);
        pool.disputePool(poolId);
        assertEq(uint8(pool.getPool(poolId).state), uint8(CloutPool.PoolState.DISPUTED));
        assertEq(token.balanceOf(address(pool)), 300e6);

        // Admin resolves NO → FINALIZED
        pool.adminResolvePool(poolId, false);
        assertEq(uint8(pool.getPool(poolId).state), uint8(CloutPool.PoolState.FINALIZED));

        // Math (NO wins):
        //   totalPool=300e6, fee=7,500,000, netLosingPool=92,500,000, totalWinningSide(NO)=200e6
        //   staker1 (not last): mulDiv(100e6, 92,500,000, 200e6)=46,250,000; payout=146,250,000
        //   staker2 (last): 92,500,000 - 46,250,000 = 46,250,000; payout=146,250,000

        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 staker1Before  = token.balanceOf(staker1);
        uint256 staker2Before  = token.balanceOf(staker2);

        vm.prank(staker1);
        pool.claimPoolWinnings(poolId);
        vm.prank(staker2);
        pool.claimPoolWinnings(poolId);

        assertEq(token.balanceOf(staker1),       staker1Before + 146_250_000);
        assertEq(token.balanceOf(staker2),       staker2Before + 146_250_000);
        assertEq(token.balanceOf(treasury),      treasuryBefore + 7_500_000);
        assertEq(token.balanceOf(address(pool)), 0);
    }

    // ─── Test 12: void path — resolver timeout (CLOSED → VOIDED) ─────────────

    function test_integration_voidPath_resolverTimeout() public {
        // host YES=100e6, staker1 NO=100e6, staker2 NO=100e6
        vm.prank(host);
        uint256 poolId = pool.createPool(
            resolver,
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            500e6,
            1000e6,
            500,
            STAKE
        );
        vm.prank(staker1);
        pool.stakePool(poolId, false, STAKE);
        vm.prank(staker2);
        pool.stakePool(poolId, false, STAKE);

        vm.warp(pool.getPool(poolId).eventStart);
        pool.closePool(poolId);

        // Warp past resolveBy → voidPool (CLOSED → VOIDED)
        vm.warp(pool.getPool(poolId).resolveBy + 1);
        pool.voidPool(poolId);
        assertEq(uint8(pool.getPool(poolId).state), uint8(CloutPool.PoolState.VOIDED));

        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 hostBefore     = token.balanceOf(host);
        uint256 staker1Before  = token.balanceOf(staker1);
        uint256 staker2Before  = token.balanceOf(staker2);

        // All stakers claim full refund
        vm.prank(host);
        pool.claimPoolWinnings(poolId);
        assertEq(token.balanceOf(host), hostBefore + STAKE);

        vm.prank(staker1);
        pool.claimPoolWinnings(poolId);
        assertEq(token.balanceOf(staker1), staker1Before + STAKE);

        vm.prank(staker2);
        pool.claimPoolWinnings(poolId);
        assertEq(token.balanceOf(staker2), staker2Before + STAKE);

        // No fee on void (I-13)
        assertEq(token.balanceOf(treasury),      treasuryBefore);
        assertEq(token.balanceOf(address(pool)), 0);

        // Double-claim reverts
        vm.prank(host);
        vm.expectRevert(CloutPool.AlreadyClaimed.selector);
        pool.claimPoolWinnings(poolId);
    }

    // ─── Test 13: void path — no audience stakers (OPEN → VOIDED) ───────────

    function test_integration_voidPath_noStakers() public {
        // Only host stakes YES=100e6, no other stakers
        uint256 poolId = _defaultCreatePool();

        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 hostBefore     = token.balanceOf(host);

        // Solvency check 1: after create, pool holds host's stake (unclaimedObligation=100e6)
        assertGe(token.balanceOf(address(pool)), 100e6);

        // Warp to eventStart — pool still OPEN, only host staked YES
        vm.warp(pool.getPool(poolId).eventStart);

        // voidPool from OPEN state (condition 2: yesStakerCount==1, noStakerCount==0)
        pool.voidPool(poolId);

        assertEq(uint8(pool.getPool(poolId).state), uint8(CloutPool.PoolState.VOIDED));

        // Solvency check 2: pool still holds the unclaimed stake
        assertGe(token.balanceOf(address(pool)), 100e6);

        // Host claims full refund
        vm.prank(host);
        pool.claimPoolWinnings(poolId);

        // Solvency check 3: pool is empty (unclaimedObligation=0)
        assertEq(token.balanceOf(address(pool)), 0);

        // No fee on void (I-13)
        assertEq(token.balanceOf(treasury), treasuryBefore);

        // Host received exact stake back
        assertEq(token.balanceOf(host), hostBefore + STAKE);

        // Double-claim reverts
        vm.prank(host);
        vm.expectRevert(CloutPool.AlreadyClaimed.selector);
        pool.claimPoolWinnings(poolId);
    }
}
