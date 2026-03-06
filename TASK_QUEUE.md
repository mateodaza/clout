# Task Queue — Clout

> This file is consumed by Nightcrawler. Tasks are executed in order, respecting dependencies.
> Only Mateo adds or reorders tasks. Nightcrawler marks completion status.
> Tasks use stable IDs (NC-001, NC-002, etc.) that never change when tasks are reordered.

## ⚠️ CRITICAL CONTEXT: Monorepo Refactor (2026-03-03)

Mateo restructured the repo into a turborepo monorepo. **All paths have changed:**

| Before | After |
|--------|-------|
| `src/` | `packages/contracts/src/` |
| `test/` | `packages/contracts/test/` |
| `script/` | `packages/contracts/script/` |
| `foundry.toml` | `packages/contracts/foundry.toml` |
| `frontend/` (NC-014) | `apps/web/` (already scaffolded by Mateo) |

**New packages:**
- `packages/types/` — `@clout/types` with shared TS types (ChallengeState, Outcome, Challenge, WalletRecord, PoolState, Pool). Import via `import { Challenge } from "@clout/types"`.
- `apps/web/` — `@clout/web` with Next.js 16.1.6, React 19.2.3, Tailwind 4, TypeScript 5.9.3. Already depends on `@clout/types`.

**Build/test:**
- From root: `pnpm turbo test`, `pnpm turbo build`, `pnpm turbo dev`
- From `packages/contracts/`: `forge build`, `forge test -v` (182 tests, all passing)

**Audit fixes applied by Mateo:**
- P2: .gitignore dedup, P4: orphan header removed, P5: lifecycle function reorder, P7: comment fix, P15: EventNotEnded check in resolvePool

## Status Legend
- [ ] Queued
- [ ] In Progress (session: {session-id})
- [x] Completed (session: {session-id}, commit: {hash})
- [!] Blocked
- [?] Needs Clarification
- [🔒] Locked
- [⛓️] DEP_BLOCKED
- [—] Skipped
- [🚧] MANUAL (Mateo-only, Nightcrawler skips)

---

## Phase 1: Foundation (Day 1)

#### NC-001 [x] Initialize Foundry project with OpenZeppelin dependencies
- **What:** Create Foundry project structure. Install OpenZeppelin contracts (IERC20, ReentrancyGuard, Ownable). Configure foundry.toml: Solidity 0.8.20, optimizer 200 runs, evm_version cancun. Create folder structure: `src/`, `test/`, `script/`.
- **Acceptance criteria:**
  - `forge build` compiles with zero errors and zero warnings
  - OpenZeppelin imports resolve correctly
  - foundry.toml has correct Solidity version, optimizer, and EVM version
- **Dependencies:** None
- **Constraints:** Use `forge install` for OpenZeppelin, not npm. Remappings in remappings.txt.

#### NC-002 [x] Implement MockStablecoin.sol
- **What:** ERC-20 token with 6 decimals for testnet use. Public `mint(address to, uint256 amount)` function (anyone can mint on testnet). Name: "Mock USDC", symbol: "mUSDC".
- **Acceptance criteria:**
  - Contract compiles
  - `decimals()` returns 6
  - Anyone can call `mint()` and receive tokens
  - Standard ERC-20 functions work (transfer, approve, transferFrom)
  - Basic test: mint → check balance → transfer → check balance
- **Dependencies:** NC-001
- **Constraints:** Keep it minimal. ~30 lines. Inherits OpenZeppelin ERC20.

#### NC-003 [x] Implement CloutEscrow.sol core structs and createChallenge
- **What:** Define Challenge struct, ChallengeState enum (CREATED, ACCEPTED, SUBMITTED, DISPUTED, RESOLVED, FINALIZED, VOIDED), Outcome enum (NONE, CREATOR_WIN, OPPONENT_WIN, DRAW, INVALID), and WalletRecord struct per RESEARCH.md §7. Implement `createChallenge()` function: validates inputs (non-zero stake, valid token, opponent != creator, designatedResolver != creator, designatedResolver != opponent), transfers stake from creator via `transferFrom`, stores challenge, emits `ChallengeCreated` event. Implement stablecoin whitelist: `addWhitelistedToken()`, `removeWhitelistedToken()`, `isWhitelisted()` (admin only). Update WalletRecord entry stats on create: increment `challengesEntered`, accumulate `totalStaked`, set `firstChallengeAt` if zero, update `lastChallengeAt`.
- **Acceptance criteria:**
  - All structs and enums match RESEARCH.md §7 exactly
  - `createChallenge()` transfers tokens and stores challenge in CREATED state
  - Reverts on: zero stake, non-whitelisted token, opponent == creator, opponent == address(0), designatedResolver == creator, designatedResolver == opponent (invariant I-3)
  - ChallengeCreated event emitted with all fields
  - Stablecoin whitelist works (add, remove, check)
  - Challenge counter increments
  - WalletRecord entry stats updated for creator on create
  - ReentrancyGuard on createChallenge (transfers tokens)
  - Tests: create success, create reverts (all invalid inputs including resolver == creator/opponent), whitelist management, WalletRecord entry update
- **Dependencies:** NC-001, NC-002
- **Constraints:** Use `mapping(uint256 => Challenge) public challenges` for storage. Use `uint256 public challengeCount` as counter. Token address is a parameter.

#### NC-004 [x] Implement acceptChallenge and voidChallenge (timeout)
- **What:** `acceptChallenge(uint256 challengeId)`: validates caller is the designated opponent, challenge is in CREATED state, transfers matching stake, updates state to ACCEPTED, emits event. Update WalletRecord entry stats on accept: increment `challengesEntered`, accumulate `totalStaked`, set `firstChallengeAt` if zero, update `lastChallengeAt`. Void logic for CREATED state: if 48h elapsed since creation and no acceptance, anyone can call `voidChallenge()` to refund creator. Void logic for ACCEPTED state: if 48h elapsed since acceptance and no result submitted, either party can call `voidChallenge()` to refund both. Update WalletRecord completion stats on void (no win increment).
- **Acceptance criteria:**
  - acceptChallenge transfers matching stake, sets state to ACCEPTED
  - Reverts: wrong opponent, wrong state, insufficient allowance
  - ChallengeAccepted event emitted
  - WalletRecord entry stats updated for opponent on accept
  - voidChallenge from CREATED: works after 48h, refunds creator
  - voidChallenge from ACCEPTED: works after 48h, refunds both
  - voidChallenge reverts before timeout expires
  - ChallengeVoided event emitted
  - WalletRecord completion stats updated on void
  - ReentrancyGuard on acceptChallenge and voidChallenge (both transfer tokens)
  - Tests: accept success, accept reverts, void from CREATED, void from ACCEPTED, void too early, WalletRecord updates
- **Dependencies:** NC-003
- **Constraints:** Use `block.timestamp` for timeout checks. 48 hours = 172800 seconds. Use constants for timeout values.

---

## Phase 2: Resolution Pipeline (Days 2-3)

#### NC-005 [x] Implement submitResult and confirmResult
- **What:** `submitResult(uint256 challengeId, Outcome outcome)`: either creator or opponent submits result (CREATOR_WIN, OPPONENT_WIN, or DRAW). Stores submitter address and submitted outcome. Sets state to SUBMITTED. Starts 24h confirmation window. `confirmResult(uint256 challengeId)`: callable only by the party who did NOT submit. If they confirm the same outcome → state moves to FINALIZED. Auto-accept: if 24h passes after submission with no confirm or dispute, the submitted result auto-accepts. Implement a `finalizeSubmission(uint256 challengeId)` function anyone can call after 24h to trigger this.
- **Acceptance criteria:**
  - submitResult: only creator or opponent can call. Only from ACCEPTED state. NONE and INVALID are not valid submissions from players.
  - confirmResult: only non-submitter can call. Only from SUBMITTED state. Sets state to FINALIZED.
  - finalizeSubmission: permissionless, works after 24h timeout, sets state to FINALIZED with submitted result
  - Reverts: wrong caller, wrong state, submit NONE/INVALID, confirm before submit, finalize before 24h
  - Events: ResultSubmitted, ResultConfirmed, ChallengeFinalizedByTimeout
  - Tests: submit/confirm happy path, auto-accept after 24h, all reverts
- **Dependencies:** NC-004
- **Constraints:** Store `submittedBy` address to enforce only-non-submitter can confirm/dispute. 24 hours = 86400 seconds.

#### NC-006 [x] Implement disputeResult and resolveDispute
- **What:** `disputeResult(uint256 challengeId)`: only the non-submitter can call from SUBMITTED state. Sets state to DISPUTED. Stores `disputedAt` timestamp. Increments WalletRecord `challengesDisputed` for the disputer. `resolveDispute(uint256 challengeId, Outcome outcome)`: callable by designated resolver (if set and within 48h of disputedAt) or admin. Submits verdict (any Outcome including INVALID). Sets state to RESOLVED. Stores `resolvedAt` timestamp. Starts 24h appeal window. Resolver timeout: if designated resolver doesn't act within 48h of disputedAt, resolution falls back to admin-only — implement `resolveDisputeAsAdmin(uint256 challengeId, Outcome outcome)` callable only by admin, only from DISPUTED state, only after 48h resolver timeout. Track resolver decisions in `resolvedChallenges` mapping for collusion detection.
- **Acceptance criteria:**
  - disputeResult: only non-submitter, only from SUBMITTED state
  - ResultDisputed event emitted
  - WalletRecord `challengesDisputed` incremented for disputer
  - resolveDispute: only resolver or admin, only from DISPUTED state
  - Resolver can submit any Outcome (CREATOR_WIN, OPPONENT_WIN, DRAW, INVALID)
  - resolvedChallenges mapping updated for resolver address
  - After 48h resolver timeout, only admin can resolve (resolveDisputeAsAdmin)
  - resolveDisputeAsAdmin reverts if called before 48h timeout, or if resolver != address(0) and resolver hasn't timed out
  - DisputeResolved event emitted with resolver address and outcome
  - Tests: dispute flow, resolver resolves, admin resolves after resolver timeout, resolver tracking, admin cannot resolve early when resolver is set
- **Dependencies:** NC-005
- **Constraints:** If `designatedResolver == address(0)`, only admin can resolve (no timeout needed). Resolver timeout = 48h = 172800 seconds from `disputedAt`.

#### NC-007 [x] Implement appealResolution and finalizeResolution
- **What:** `appealResolution(uint256 challengeId)`: either player can appeal a resolver's decision within 24h of RESOLVED state (`resolvedAt`). Sets `appealed = true`, emits event. Escalates to admin review. `finalizeResolution(uint256 challengeId)`: permissionless call after 24h appeal window with no appeal → auto-finalizes resolver's decision, sets state to FINALIZED. If appeal was filed, admin has 48h to review and make final decision via `adminFinalizeAppeal(uint256 challengeId, Outcome outcome)` → sets FINALIZED. Admin timeout void: implement `voidByAdminTimeout(uint256 challengeId)`: permissionless, callable if appeal was filed AND 48h elapsed since appeal with no admin action → auto-void (both refunded, VOIDED state).
- **Acceptance criteria:**
  - appealResolution: only creator or opponent, only within 24h of `resolvedAt`, only from RESOLVED state
  - ResolutionAppealed event emitted
  - finalizeResolution: permissionless after 24h with no appeal, sets FINALIZED
  - ResolutionFinalized event emitted
  - adminFinalizeAppeal: admin only, after appeal filed, sets FINALIZED with admin's outcome
  - voidByAdminTimeout: permissionless, after appeal + 48h admin timeout, sets VOIDED, refunds both
  - ChallengeVoidedByAdminTimeout event emitted
  - Admin's decision on appeal is final — no further appeals
  - Tests: no appeal → auto-finalize, appeal → admin decides, appeal → admin timeout → void (both refunded), appeal too late reverts, admin acts before timeout
- **Dependencies:** NC-006
- **Constraints:** Track appeal state with `bool appealed` and `uint256 resolvedAt` fields on Challenge struct. 24h = 86400 seconds. 48h = 172800 seconds.

---

## Phase 3: Payouts + Hardening (Day 4)

#### NC-008 [x] Implement claimWinnings and fee routing
- **What:** `claimWinnings(uint256 challengeId)`: callable by EITHER creator or opponent when state is FINALIZED or VOIDED. This is a settlement function — one call distributes ALL owed payouts atomically and marks the challenge as `claimed`. Calculates protocol fee (configurable basis points, default 250 = 2.5%). Fee calculation: `protocolFee = (2 * stake) * feeBps / 10000`. Transfers:
  - CREATOR_WIN: `(2 * stake - protocolFee)` to creator, `protocolFee` to treasury
  - OPPONENT_WIN: `(2 * stake - protocolFee)` to opponent, `protocolFee` to treasury
  - DRAW: each gets `(stake - protocolFee/2)`, `protocolFee` to treasury. Rounding remainder (smallest token unit) goes to creator
  - INVALID: each gets original `stake` back, no fee, no treasury transfer
  - VOIDED: each gets original `stake` back (if both staked) or creator only (if CREATED→VOIDED), no fee
  Configurable: `setProtocolFee(uint256 bps)`, `setTreasury(address)` (admin only). Update WalletRecord completion stats: increment `challengesCompleted` for both, increment `challengesWon` for winner (DRAW counts as completed but not won for either).
- **Acceptance criteria:**
  - Either participant can call. One call settles all transfers atomically. Challenge marked `claimed` after.
  - CREATOR_WIN: creator receives `(2 * stake - fee)`, opponent receives 0, treasury receives fee
  - OPPONENT_WIN: opponent receives `(2 * stake - fee)`, creator receives 0, treasury receives fee
  - DRAW: each receives `(stake - fee/2)`, treasury receives fee, creator gets rounding dust
  - INVALID: each receives original stake, no fee taken
  - VOIDED: each receives original stake (or creator-only for CREATED→VOIDED), no fee
  - Reverts: not FINALIZED/VOIDED, already claimed
  - Does NOT revert on caller identity — either participant may trigger settlement
  - Double-claim prevention (challenge marked as claimed)
  - WalletRecord completion stats updated for both participants
  - Events: WinningsClaimed(challengeId, outcome, creatorPayout, opponentPayout, protocolFee)
  - ReentrancyGuard on claimWinnings (transfers tokens)
  - Tests: all 5 outcome types (WIN/WIN/DRAW/INVALID/VOIDED), fee calculation with exact balance checks, double claim revert, either-party-can-call, WalletRecord updates
- **Dependencies:** NC-007
- **Constraints:** Use basis points (10000 = 100%). Handle DRAW rounding: give any remainder (smallest token unit) to creator.

#### NC-009 [x] Implement WalletRecord view and integration hardening
- **What:** Expose `getWalletRecord(address)` view function returning all WalletRecord fields. Verify that WalletRecord updates are correctly integrated into all mutating functions (create, accept, claim, void, dispute — implemented in prior tasks). Write focused tests for the complete WalletRecord lifecycle across multiple challenges.
- **Acceptance criteria:**
  - getWalletRecord returns correct data for: challengesEntered, challengesCompleted, challengesWon, challengesDisputed, totalStaked, firstChallengeAt, lastChallengeAt
  - Entry stats (challengesEntered, totalStaked, firstChallengeAt, lastChallengeAt) updated on createChallenge and acceptChallenge (implemented in NC-003, NC-004)
  - Completion stats (challengesCompleted, challengesWon) updated on claimWinnings/voidChallenge (implemented in NC-008, NC-004)
  - challengesDisputed incremented on disputeResult (implemented in NC-006)
  - firstChallengeAt only set once (first create or accept) — never overwritten
  - lastChallengeAt updates on every create or accept
  - Tests: multi-challenge lifecycle (create, accept, submit, confirm, claim) checking WalletRecord after each step for both players. Minimum 3 test functions.
- **Dependencies:** NC-008
- **Constraints:** WalletRecord updates happen inside the relevant mutating functions, not in separate transactions. This task focuses on the view function and integration tests — the updates themselves are already in NC-003, NC-004, NC-006, NC-008.

#### NC-010 [x] CloutEscrow comprehensive test suite + invariant checks
- **What:** Full integration tests covering every path through the state machine. Should include: happy path (create → accept → submit → confirm → claim for each outcome), dispute path (dispute → resolve → finalize), appeal path (dispute → resolve → appeal → admin decides), all timeout paths (6 timeouts: 48h create, 48h accept, 24h confirm auto-accept, 48h resolver, 24h appeal, 48h admin), edge cases (double claim, wrong caller, wrong state, zero stake). Named invariant tests for I-1 through I-7. Target: 15+ individual test functions.
- **Acceptance criteria:**
  - 15+ test functions, all passing
  - Every state transition tested (valid and invalid)
  - Every timeout tested with vm.warp()
  - Every payout scenario tested with exact token balance checks (verifying balances before and after, including treasury)
  - Every revert condition tested with vm.expectRevert()
  - Invariant I-1 (solvency): `token.balanceOf(escrow) >= sum of locked stakes` verified after each state change in integration tests
  - Invariant I-2 (non-submitter disputes): tested — submitter calling disputeResult reverts
  - Invariant I-3 (resolver != participant): tested — createChallenge with resolver == creator/opponent reverts
  - Invariant I-4 (payout correctness): DRAW 50/50 minus fee, INVALID/VOIDED full refund — tested with exact amounts
  - Invariant I-5 (WalletRecord timing): completion stats only update on claim/void — tested
  - Invariant I-6 (no state skip): calling functions from invalid states reverts — tested per transition
  - Invariant I-7 (admin timeout → VOIDED): admin timeout never picks a winner — tested
  - `forge test -v` shows all tests passing
- **Dependencies:** NC-008, NC-009
- **Constraints:** Use Foundry's Test base. setUp() deploys MockStablecoin + CloutEscrow, mints tokens to test addresses, approves escrow. Use vm.prank() for caller spoofing. Use vm.warp() for time manipulation.

---

## GATE 1 CHECKPOINT

#### NC-G1 [x] Gate 1: CloutEscrow complete
- **What:** Verify Gate 1 pass criteria from GLOBAL_PLAN.md. This is a validation-only task — no new code. Run `forge build` (zero warnings), run `forge test -v` (all pass, 15+ tests), verify all 9 gate criteria are met by reading test output and contract source.
- **Acceptance criteria:**
  - `forge build` compiles with zero errors and zero warnings
  - `forge test -v` shows 15+ tests passing
  - Full state machine works: CREATED → ACCEPTED → SUBMITTED → FINALIZED
  - Dispute path works: SUBMITTED → DISPUTED → RESOLVED → FINALIZED
  - All 6 timeout specifications functional
  - Payout logic correct for all 5 outcomes
  - Protocol fee deducted correctly
  - WalletRecord updates on claim/void
  - Designated resolver flow works
- **Dependencies:** NC-010
- **Constraints:** No code changes. Read-only validation. If ANY criteria is not met, mark as BLOCKED and escalate to WhatsApp with the specific failing criterion. Downstream tasks (NC-011+) must not run if this gate fails.

---

## Phase 4: Challenge Pools (Day 5)

#### NC-011 [x] Implement CloutPool.sol core (create, stake, close)
- **What:** New contract. Pool struct with: host, resolver, token, event timestamps (eventStart, eventEnd, resolveBy), per-wallet cap, total pool cap, host commission bps, state (OPEN, CLOSED, SUBMITTED, DISPUTED, FINALIZED, VOIDED). `createPool()`: host creates pool, must stake YES side, cannot be own resolver (invariant I-9), validates timestamps (eventStart > block.timestamp, eventStart < eventEnd, eventEnd < resolveBy). `stakePool()`: anyone stakes YES or NO, per-wallet cap (I-10) and total cap (I-11) enforced. `closePool()`: permissionless, transitions OPEN → CLOSED after eventStart. Stablecoin whitelist (same pattern as CloutEscrow — admin only). Pool counter for IDs.
- **Acceptance criteria:**
  - createPool: host stakes YES (I-8), cannot set self as resolver (I-9), validates all timestamps
  - PoolCreated event emitted with all fields
  - stakePool: enforces per-wallet cap (I-10) and total pool cap (I-11), tracks YES/NO totals separately
  - Staked event emitted
  - closePool: transitions OPEN → CLOSED, no more staking after close
  - PoolClosed event emitted
  - Reverts: host is resolver, host doesn't stake YES, stake exceeds per-wallet cap, stake exceeds total cap, stake after close, invalid timestamps
  - ReentrancyGuard on createPool and stakePool (both transfer tokens)
  - Tests for all of the above (minimum 8 test functions)
- **Dependencies:** NC-G1
- **Constraints:** Ownable (same admin pattern as CloutEscrow). Separate contract file. Uses same whitelisted token pattern (duplicate the whitelist or share via inheritance — implementer's choice, but must work).

#### NC-012A [x] Implement CloutPool resolution and dispute
- **What:** `resolvePool(uint256 poolId, bool yesWins)`: designated resolver submits YES or NO outcome. Only from CLOSED state. Sets state to SUBMITTED. Stores `resolvedAt` timestamp. 24h dispute window begins. Resolver timeout: if resolveBy timestamp passes with no resolution → void path (separate task NC-012C). `disputePool(uint256 poolId)`: losing-side stakers can flag within 24h of resolution. Track flags per wallet (one flag per wallet). Dispute threshold: `flags * 10000 > losingStakerCount * 2000` (equivalent to >20%). `losingStakerCount` is snapshotted at resolution time. If threshold met, state → DISPUTED, admin must resolve. If zero losing stakers, pool finalizes immediately with no dispute path. `finalizePool(uint256 poolId)`: permissionless after 24h with dispute threshold NOT met → FINALIZED. Admin resolution after dispute: `adminResolvePool(uint256 poolId, bool yesWins)` → FINALIZED.
- **Acceptance criteria:**
  - resolvePool: only resolver, only from CLOSED state
  - PoolResolved event emitted
  - disputePool: only losing-side stakers, one flag per wallet, only within 24h of resolvedAt
  - PoolDisputeFlagged event emitted per flag
  - Dispute threshold calculation: `flags * 10000 > losingStakerCount * 2000`
  - losingStakerCount snapshotted at resolution (count of unique wallets on losing side)
  - Zero losing stakers → immediate finalization, no dispute path
  - If threshold met → DISPUTED state, PoolDisputeTriggered event
  - finalizePool: permissionless after 24h, only if threshold NOT met → FINALIZED
  - PoolFinalized event emitted
  - adminResolvePool: admin only, only from DISPUTED → FINALIZED
  - Tests: resolver resolves, dispute flags counted, threshold met → admin review, threshold not met → finalize, zero losing stakers → immediate finalize
- **Dependencies:** NC-011
- **Constraints:** Use `mapping(uint256 => mapping(address => bool))` for per-wallet dispute flags. Snapshot losing staker count at resolution time (store as field on Pool struct).

#### NC-012B [x] Implement CloutPool payouts
- **What:** `claimPoolWinnings(uint256 poolId)`: callable by any staker when pool is FINALIZED. Settlement per staker: winners receive original stake PLUS pro-rata share of net losing pool. Fee deduction order: 1) `protocolFee = (totalYes + totalNo) * feeBps / 10000` → treasury. 2) If YES wins: `hostCommission = totalYes * hostBps / 10000` → host (I-12: commission only on YES). 3) `netLosingPool = totalLosingSide - protocolFee_share - hostCommission_share`. 4) `payout = myStake + (myStake * netLosingPool) / totalWinningSide`. Track `claimed` per staker. Last claimer absorbs rounding dust.
  Void paths: implement `voidPool(uint256 poolId)`: permissionless, callable when resolveBy timeout passes with no resolution from CLOSED state, OR when OPEN and eventStart passes with no stakers besides host. Refunds all stakers pro-rata. No fee, no commission on void.
- **Acceptance criteria:**
  - claimPoolWinnings: only from FINALIZED state, only for stakers, only once per staker
  - Payout formula: `payout = myStake + (myStake / totalWinningSide) * netLosingPool`
  - Fee deduction order verified with exact balance checks:
    1. Protocol fee deducted first from total pool
    2. Host commission deducted second (only on YES wins) (I-12)
    3. Net losing pool distributed proportionally to winners
    4. Winners receive original stake back
  - Protocol fee on all non-void outcomes (I-13)
  - Last claimer gets any rounding dust
  - WinningsClaimed event emitted per staker with amounts
  - voidPool: permissionless after resolveBy timeout, refunds all, no fee
  - PoolVoided event emitted
  - Reverts: not finalized, already claimed, not a staker, void too early
  - ReentrancyGuard on claimPoolWinnings and voidPool (both transfer tokens)
  - Tests: YES wins (with commission), NO wins (no commission), void (resolveBy timeout), void (no stakers), proportional payout math with 3+ stakers, exact fee order verification, rounding with odd amounts
- **Dependencies:** NC-012A
- **Constraints:** Use mulDiv pattern for proportional math: `(myStake * netLosingPool) / totalWinningSide`. Commission bps set at pool creation time and immutable.

#### NC-012C [x] CloutPool comprehensive test suite + invariant checks
- **What:** Full integration tests covering every CloutPool path. Pool lifecycle: create → stake (multiple wallets YES/NO) → close → resolve → finalize → claim. Dispute path. Void paths (timeout, no stakers). Named invariant tests for I-8 through I-14. Target: 10+ individual test functions.
- **Acceptance criteria:**
  - 10+ test functions, all passing
  - Invariant I-8 (host stakes YES): tested — createPool without YES stake reverts
  - Invariant I-9 (host != resolver): tested — createPool with host as resolver reverts
  - Invariant I-10 (per-wallet cap): tested — stakePool exceeding cap reverts
  - Invariant I-11 (total pool cap): tested — stakePool exceeding total cap reverts
  - Invariant I-12 (commission only on YES): tested — NO wins produce zero commission
  - Invariant I-13 (protocol fee on all non-void): tested — fee deducted on YES and NO wins, not on void
  - Invariant I-14 (proportional payout + stake back): tested with 3+ stakers, exact balance checks
  - Solvency check: `token.balanceOf(pool) >= sum of all unclaimed stakes` after every state change
  - Full lifecycle integration test with 3+ wallets
  - `forge test -v` shows all tests passing
- **Dependencies:** NC-012B
- **Constraints:** setUp() deploys MockStablecoin + CloutPool, mints tokens to test addresses (minimum 4: admin, host, staker1, staker2), approves pool. Use vm.prank() and vm.warp().

---

## GATE 2 CHECKPOINT

#### NC-G2 [x] Gate 2: Both contracts pass tests locally (session: nightcrawler/dev, commit: 1564aa55fc6265d6f83da826175947fb80aa84ab)
- **What:** Verify Gate 2 pass criteria from GLOBAL_PLAN.md. Run `forge build` (zero warnings), run `forge test -v` (all pass for both contracts). Verify pool lifecycle, caps, commission, dispute threshold all work.
- **Acceptance criteria:**
  - `forge build` compiles with zero warnings
  - `forge test -v` shows all CloutEscrow AND CloutPool tests passing
  - Pool lifecycle verified: OPEN → CLOSED → SUBMITTED → FINALIZED
  - Host commission verified on YES wins only
  - Per-wallet and total pool caps enforced
  - Dispute threshold mechanism works
- **Dependencies:** NC-012C
- **Constraints:** No code changes. Read-only validation. If ANY criteria not met, mark BLOCKED and escalate. Downstream tasks (NC-013+) must not run if this gate fails.

---

## Phase 5: Deployment Script (Day 6)

#### NC-013 [x] Create Anvil-verified deployment script
- **What:** Foundry deployment script (`packages/contracts/script/Deploy.s.sol`) that deploys: 1) MockStablecoin, 2) CloutEscrow, 3) CloutPool. Then configures: whitelist MockStablecoin on both contracts, set protocol fee to 250 bps, set treasury address. Logs all deployed addresses. Create `DEPLOYMENTS.md` template (at repo root) with placeholders for Base Sepolia addresses. Script must work on local Anvil — this is the Nightcrawler-executable scope. Base Sepolia broadcast is a manual step for Mateo.
- **Acceptance criteria:**
  - Script deploys all 3 contracts in correct order
  - Constructor args: owner = `vm.envAddress("OWNER_ADDRESS")`, treasury = `vm.envAddress("TREASURY_ADDRESS")`, feeBps = `vm.envUint("FEE_BPS")` (default 250)
  - Configuration calls succeed: whitelist MockStablecoin on both contracts, set protocol fee, set treasury
  - All addresses logged to console
  - Script works on local Anvil: `cd packages/contracts && forge script script/Deploy.s.sol --fork-url http://localhost:8545 --broadcast`
  - DEPLOYMENTS.md (repo root) has structured placeholders for Base Sepolia addresses, verified-on links, and tx hashes
  - `packages/contracts/.env.example` created with `OWNER_ADDRESS`, `TREASURY_ADDRESS`, `FEE_BPS`, `PRIVATE_KEY`, `BASE_SEPOLIA_RPC_URL` (all placeholder values)
  - Owner == deployer initially. No ownership transfer in script (Mateo does this manually if needed).
- **Dependencies:** NC-G2
- **Constraints:** Use `forge script` with `vm.envAddress`/`vm.envUint` for all configurable values. NEVER hardcode keys or addresses. Anvil testing only — Nightcrawler does NOT broadcast to Base Sepolia. **Path:** all Foundry files are in `packages/contracts/`.

---

## Phase 6: Frontend (Days 7-8)

> **⚠️ MONOREPO CONTEXT:** The frontend is at `apps/web/` (NOT `frontend/`). It's a Next.js 16.1.6 app with React 19.2.3, Tailwind 4, TypeScript 5.9.3. It already depends on `@clout/types` (workspace package). Use `@clout/types` for all domain type imports (ChallengeState, Outcome, Challenge, WalletRecord, PoolState, Pool). ABIs must be imported from `../../packages/contracts/out/` artifacts or copied into a shared location. Run `pnpm dev` from repo root (turbo) or `pnpm dev` from `apps/web/`.

#### NC-014 [x] Initialize Next.js frontend with wallet connection (REPLACED by Mateo's turborepo refactor)
- **Status:** Mateo scaffolded `apps/web/` with Next.js 16.1.6 during the turborepo refactor. NC-014's original `frontend/` output is superseded. **Nightcrawler: skip this task, proceed to NC-014B.**

#### NC-014B [x] Set up wagmi + viem + wallet connection in apps/web/
- **What:** Install and configure wagmi v2 + viem in the existing `apps/web/` Next.js app. **NO RainbowKit** — use wagmi's built-in connectors: `coinbaseWallet` (Smart Wallet with account abstraction), `walletConnect`, and `injected` (MetaMask). Configure for Base Sepolia testnet (chain ID 84532). Extract ABI JSON for CloutEscrow, CloutPool, MockStablecoin from `packages/contracts/out/<Contract>.sol/<Contract>.json` (the `abi` field only) and write them as typed `as const` exports in `apps/web/src/lib/contracts.ts`. Create `apps/web/src/lib/wagmi.ts` with chain config and all 3 connectors. Create `apps/web/src/components/Providers.tsx` (`"use client"`) that wraps children in `WagmiProvider` + `QueryClientProvider`. Import `Providers` in `apps/web/src/app/layout.tsx` (layout stays a Server Component). Build a custom `ConnectWallet` component (`apps/web/src/components/ConnectWallet.tsx`, `"use client"`) using wagmi hooks: `useConnect` (show connector buttons when disconnected), `useAccount` (show truncated address when connected), `useDisconnect` (disconnect button). Add `ConnectWallet` to the layout nav.
- **Acceptance criteria:**
  - `pnpm turbo build` (from repo root) completes with zero errors
  - `ConnectWallet` component renders in the layout nav
  - Three connector options shown: Coinbase Wallet (Smart Wallet), WalletConnect, MetaMask (injected)
  - Connected state shows truncated address + disconnect button
  - `apps/web/src/lib/contracts.ts` exports typed `as const` ABI constants for all 3 contracts + contract addresses from env vars
  - `apps/web/src/lib/wagmi.ts` exports wagmi config with Base Sepolia (chain ID 84532) and all 3 connectors
  - `apps/web/.env.example` with `NEXT_PUBLIC_ESCROW_ADDRESS`, `NEXT_PUBLIC_POOL_ADDRESS`, `NEXT_PUBLIC_TOKEN_ADDRESS`, `NEXT_PUBLIC_RPC_URL`, `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`
  - All domain types imported from `@clout/types` (no local redefinitions)
  - Basic nav layout with links: Home, Challenges, Pools
- **Dependencies:** NC-G2
- **Constraints:** `apps/web/` already exists — do NOT run `create-next-app`. Install with `pnpm add wagmi viem @tanstack/react-query --filter @clout/web`. App Router is at `apps/web/src/app/`. **CRITICAL: `layout.tsx` must remain a Server Component — put all wagmi providers in a separate `Providers.tsx` with `"use client"` at the top. Do NOT install RainbowKit or any wallet UI library.** For `coinbaseWallet` connector, set `preference: 'smartWalletOnly'` to enable account abstraction. Verify with `pnpm turbo build` from repo root.

#### NC-015A [x] Build PvP Escrow challenge list and create pages
- **What:** Two pages in `apps/web/src/app/`: `/challenges` (list active challenges — loop `challengeCount`, read each via `getChallenge`, filter by state), `/challenges/create` (form: opponent address, stake amount, game description, resolver address — calls `approve` then `createChallenge`).
- **Acceptance criteria:**
  - `/challenges` lists challenges with: ID, creator, opponent, stake, state badge, game description
  - List reads directly from contract (no indexer)
  - `/challenges/create` form validates: non-empty opponent, positive stake, valid addresses
  - Form calls `approve` then `createChallenge` with loading/success/error states
  - Transaction hash shown on success
  - `ChallengeState` from `@clout/types` used for state labels/badges
- **Dependencies:** NC-014B
- **Constraints:** Read challenge data directly from contract. Keep UI functional, not polished. Pages at `apps/web/src/app/challenges/` and `apps/web/src/app/challenges/create/`. **Approve-then-write pattern:** use `useWriteContract` for `approve`, then `useWaitForTransactionReceipt` to wait for confirmation, THEN fire the second `useWriteContract` for `createChallenge`. Do NOT fire both writes simultaneously. For the list page, read `challengeCount` first, then batch-read challenges with `useReadContracts` (multicall). Verify with `pnpm turbo build` from repo root.

#### NC-015B [x] Build PvP Escrow challenge detail page
- **What:** `/challenges/[id]` page: reads challenge by ID, shows all fields. Dynamic action buttons per state and connected wallet: Accept (CREATED, caller == opponent), Submit Result (ACCEPTED, caller == creator or opponent), Confirm (SUBMITTED, caller == non-submitter), Dispute (SUBMITTED, caller == non-submitter), Claim (FINALIZED/VOIDED, caller == creator or opponent), Resolve Dispute (DISPUTED, caller == resolver or admin), Appeal (RESOLVED, caller == creator or opponent). Each button calls the corresponding contract function.
- **Acceptance criteria:**
  - Shows all challenge fields and current state
  - Correct action buttons appear per state per caller role (at least 7 total)
  - Each button calls the right contract function with correct args
  - Transactions show pending/success/error states
  - Page re-fetches challenge state after successful transaction
  - `ChallengeState` and `Outcome` from `@clout/types` used for state-driven rendering
- **Dependencies:** NC-015A
- **Constraints:** State-driven rendering via switch on `ChallengeState`. Page at `apps/web/src/app/challenges/[id]/`. **Approve-then-write for Accept:** the Accept action transfers tokens, so use `approve` → `useWaitForTransactionReceipt` → `acceptChallenge` (same sequential pattern as NC-015A). **Re-fetch after transaction:** after any successful write transaction, re-fetch the challenge data so the UI updates to show new state and correct action buttons. Verify with `pnpm turbo build` from repo root.

#### NC-016A [x] Build Challenge Pools list and create pages
- **What:** Two pages in `apps/web/src/app/`: `/pools` (list active pools), `/pools/create` (form: event description, eventStart, eventEnd, resolveBy as datetime inputs, resolver address, per-wallet cap, total cap, host commission bps, initial YES stake — calls `approve` then `createPool`).
- **Acceptance criteria:**
  - `/pools` lists pools with: ID, host, state, YES total, NO total, event start/end
  - `/pools/create` form validates: eventStart > now, eventStart < eventEnd < resolveBy, caps > 0, commission bps <= 10000
  - Form calls `approve` then `createPool`
  - Transaction states shown
  - `PoolState` from `@clout/types` used for state labels/badges
- **Dependencies:** NC-014B
- **Constraints:** Read pool data directly from contract. Pages at `apps/web/src/app/pools/` and `apps/web/src/app/pools/create/`. **Same approve-then-write pattern as NC-015A:** `approve` → wait for receipt → `createPool`. Convert datetime inputs to unix timestamps (`Math.floor(new Date(value).getTime() / 1000)`). Read `poolCount` first, batch-read pools with `useReadContracts`. Verify with `pnpm turbo build` from repo root.

#### NC-016B [x] Build Challenge Pools detail page
- **What:** `/pools/[id]` page: shows pool state, YES/NO totals, user's current stake, event times, resolver. Action buttons: Stake YES / Stake NO (OPEN, under caps), Resolve (CLOSED, caller == resolver), Flag Dispute (SUBMITTED, caller on losing side), Claim (FINALIZED, caller is staker), Admin Resolve (DISPUTED, caller == admin). Stake buttons show remaining cap.
- **Acceptance criteria:**
  - Shows all pool fields, YES/NO totals, user's stake
  - Correct action buttons per state per role
  - Stake buttons show remaining allowance (walletCap minus user's current stake)
  - All buttons call correct contract functions
  - Transactions show pending/success/error states
  - `PoolState` from `@clout/types` used for state-driven rendering
- **Dependencies:** NC-016A
- **Constraints:** Page at `apps/web/src/app/pools/[id]/`. **Losing side detection:** read `getPool(poolId)` for `pool.yesWins` (set after SUBMITTED state) and `getStakes(poolId, connectedAddress)` for the user's `yesStake` and `noStake`. User is on losing side if: `pool.yesWins && noStake > 0` OR `!pool.yesWins && yesStake > 0`. Only show Flag Dispute button for losing-side stakers within 24h of `pool.resolvedAt`. **Stake side:** use `getStakes(poolId, address)` — returns `(yesStake, noStake)` — to determine if user is a staker and which side. Verify with `pnpm turbo build` from repo root.

#### NC-017 [x] Build home page and wallet record display
- **What:** Two things: 1) A home page (`/`) that explains what Clout is — brief product description, two cards linking to Challenges and Pools, a connected-wallet stats summary. 2) A wallet record component (reusable) that reads `getWalletRecord(address)` from CloutEscrow and displays: challenges entered, completed, won, disputed, total staked, first/last challenge timestamps. Show this component on the home page for the connected wallet.
- **Acceptance criteria:**
  - Home page renders without wallet connection (shows connect prompt)
  - Home page renders wallet record stats when connected
  - WalletRecord component reads from `CloutEscrow.getWalletRecord`
  - Stats shown: entered, completed, won, disputed, totalStaked, firstChallengeAt (human-readable date)
  - Two nav cards linking to `/challenges` and `/pools`
  - `WalletRecord` type imported from `@clout/types`
  - `pnpm turbo build` passes
- **Dependencies:** NC-015A
- **Constraints:** WalletRecord component should be reusable (`apps/web/src/components/WalletRecord.tsx`). Keep the home page minimal — this is an MVP, not a landing page.

#### NC-018 [x] Global UI polish: loading states, errors, empty states
- **What:** Audit all pages built in NC-015A/B, NC-016A/B, NC-017 and add: 1) Loading skeletons or spinners while contract reads are pending. 2) Error messages when transactions fail (show revert reason if available). 3) Empty state messages when lists are empty ("No challenges yet — create one"). 4) Consistent state badge styling across challenges and pools (color-coded: OPEN=green, SUBMITTED=yellow, DISPUTED=red, FINALIZED=blue, VOIDED=gray). 5) Disable action buttons while a transaction is pending (prevent double-submit).
- **Acceptance criteria:**
  - All list pages show a loading state while data loads
  - All list pages show an empty state when no items exist
  - All action buttons show a pending state during transaction and disable re-clicks
  - All errors surface a readable message (not a raw hex revert)
  - State badges are consistently color-coded across challenges and pools
  - `pnpm turbo build` passes
- **Dependencies:** NC-016B, NC-017
- **Constraints:** No new pages — polish only. Keep changes in existing components/pages. If a specific page is already handling errors well, skip it.

---

## Phase 6B: Frontend Polish (Day 7)

> Fresh commits in the public repo. Meaningful improvements, not padding.

#### NC-023 [x] Extract contract ABIs to separate JSON files
- **What:** `apps/web/src/lib/contracts.ts` is 3011 lines with full ABIs inline as `as const` objects. Extract each ABI to its own file: `apps/web/src/lib/abis/CloutEscrow.json`, `CloutPool.json`, `MockStablecoin.json`. Update `contracts.ts` to import from the JSON files and re-export. Keep the typed `as const` assertion. The file should drop to ~50 lines (imports + address exports + re-exports).
- **Acceptance criteria:**
  - Three ABI JSON files in `apps/web/src/lib/abis/`
  - `contracts.ts` imports and re-exports ABIs with `as const` typing
  - `contracts.ts` under 80 lines
  - All existing imports of ABIs from `contracts.ts` still work unchanged
  - `pnpm turbo build` passes with zero errors
- **Dependencies:** NC-018
- **Constraints:** Do NOT change the ABI content — extract as-is. Existing consuming code must not require changes.

#### NC-024 [x] Add transaction toast notification system
- **What:** Create a minimal toast/notification component (`apps/web/src/components/Toast.tsx`) for transaction feedback. States: pending ("Transaction submitted..."), confirmed ("Transaction confirmed"), failed ("Transaction failed: {reason}"). Show on every write transaction across all pages. Use a React context provider (`apps/web/src/contexts/ToastContext.tsx`) so any page can trigger a toast. Extract revert reasons from wagmi errors when available. Auto-dismiss success toasts after 5 seconds. Error toasts persist until dismissed.
- **Acceptance criteria:**
  - Toast component renders at viewport bottom-right, above page content
  - Three visual states: pending (yellow/spinner), confirmed (green/check), failed (red/x)
  - All existing write operations (create challenge, accept, stake, claim, etc.) trigger toasts
  - Failed transactions show human-readable revert reason when available
  - Success toasts auto-dismiss after 5 seconds
  - Error toasts have a dismiss button
  - `pnpm turbo build` passes
- **Dependencies:** NC-023
- **Constraints:** No external toast library — keep it lightweight. Use Tailwind for styling. Context provider goes inside the existing `Providers.tsx` wrapper.

#### NC-025 [x] Mobile-responsive pass on all pages
- **What:** Audit all pages (home, challenges list/create/detail, pools list/create/detail) for mobile viewport (375px width). Fix: nav collapse to hamburger or stacked layout, form inputs full-width on mobile, list cards stack vertically, action buttons full-width on mobile, table-like layouts become card layouts on small screens. Use Tailwind responsive prefixes (`sm:`, `md:`).
- **Acceptance criteria:**
  - All pages render without horizontal overflow at 375px viewport width
  - Nav is usable on mobile (hamburger menu or stacked links)
  - Forms are usable on mobile (full-width inputs, properly sized touch targets)
  - Challenge/pool lists stack vertically on mobile
  - Detail page action buttons are full-width on mobile
  - No text truncation that hides critical information
  - `pnpm turbo build` passes
- **Dependencies:** NC-024
- **Constraints:** Mobile-first adjustments only — don't redesign. Use Tailwind responsive classes. Test mentally against 375px (iPhone SE) and 768px (tablet) breakpoints.

#### NC-026 [x] Add meta tags, OG images, and favicon
- **What:** Use Next.js Metadata API to add proper `<title>`, `<meta description>`, and Open Graph tags to all routes. Root layout gets default metadata. Each route segment gets specific titles (`Challenges | Clout`, `Create Pool | Clout`, etc.). Add a simple favicon (can be a text-based SVG favicon via `app/icon.svg`). Add `robots.txt` and `sitemap.xml` via Next.js conventions (`app/robots.ts`, `app/sitemap.ts`).
- **Acceptance criteria:**
  - Every page has a unique `<title>` and `<meta description>`
  - Root layout has Open Graph metadata (title, description, type: "website")
  - Favicon renders in browser tab
  - `robots.txt` accessible at `/robots.txt`
  - `sitemap.xml` accessible at `/sitemap.xml` with all routes
  - `pnpm turbo build` passes
- **Dependencies:** NC-025
- **Constraints:** Use Next.js `metadata` export or `generateMetadata` — no `<Head>` components. Keep OG descriptions short and descriptive for external reviewers. SVG favicon preferred (no image asset needed).

---

## Phase 6C: UX & Functionality Gaps (Day 8)

> Addressing Codex review feedback + remaining UX gaps before Base Sepolia deployment.

#### NC-027 [x] Make challenge/pool list rows clickable links to detail pages
- **What:** On `/challenges`, wrap each challenge card/row in a `<Link href="/challenges/{id}">` so clicking anywhere on the row navigates to the detail page. Same for `/pools` — each pool card/row links to `/pools/{id}`. Add hover state (subtle background change) to indicate clickability. Cursor should be `pointer` on hover.
- **Acceptance criteria:**
  - Clicking a challenge row navigates to `/challenges/[id]`
  - Clicking a pool row navigates to `/pools/[id]`
  - Hover state visible on both (background shift or border highlight)
  - Cursor changes to pointer on hover
  - Existing action buttons inside rows (if any) still work without triggering navigation
  - `pnpm turbo build` passes
- **Dependencies:** NC-026
- **Constraints:** Use Next.js `Link` component. Don't break existing card layout. If rows contain buttons, use `e.stopPropagation()` on button clicks to prevent double navigation.

#### NC-028 [x] Add a global loading skeleton component
- **What:** Create a reusable `Skeleton` component (`apps/web/src/components/Skeleton.tsx`) — a pulsing gray rectangle with configurable width/height. Use it to replace any raw "Loading..." text across all list pages (`/challenges`, `/pools`) and detail pages (`/challenges/[id]`, `/pools/[id]`). Show skeleton cards (3-4 placeholder rows) while contract reads are pending.
- **Acceptance criteria:**
  - `Skeleton` component accepts `width`, `height`, `className` props
  - Pulsing animation via Tailwind `animate-pulse`
  - `/challenges` shows 3 skeleton cards while loading
  - `/pools` shows 3 skeleton cards while loading
  - Detail pages show skeleton layout while loading (header + content blocks)
  - No "Loading..." raw text remains anywhere
  - `pnpm turbo build` passes
- **Dependencies:** NC-027
- **Constraints:** Pure Tailwind — no animation libraries. Keep the skeleton shapes simple (rectangles). One component, reused everywhere.

#### NC-029 [x] Add "Connect Wallet" prompts on action-gated pages
- **What:** On detail pages (`/challenges/[id]`, `/pools/[id]`), if the user is not connected, show a clear "Connect your wallet to interact" message where action buttons would normally appear. On create pages (`/challenges/create`, `/pools/create`), show the same prompt above the form with the form inputs disabled. Import and render the existing `ConnectWallet` component inline so the user can connect without scrolling to the nav.
- **Acceptance criteria:**
  - Disconnected users see a connect prompt instead of action buttons on detail pages
  - Disconnected users see a connect prompt above disabled forms on create pages
  - The `ConnectWallet` component is rendered inline in the prompt area
  - After connecting, action buttons / form inputs appear immediately (reactive)
  - `pnpm turbo build` passes
- **Dependencies:** NC-028
- **Constraints:** Reuse the existing `ConnectWallet` component — don't build a new one. Use wagmi's `useAccount` to check connection status.

#### NC-030 [x] Add timestamp formatting and countdown displays
- **What:** All unix timestamps displayed in the app (challenge creation time, pool eventStart/eventEnd/resolveBy, WalletRecord firstChallengeAt/lastChallengeAt) should be formatted as human-readable dates. Create a utility `formatTimestamp(unix: bigint): string` in `apps/web/src/lib/utils.ts`. For active timeouts (24h confirm window, 48h dispute window, etc.), show a countdown: "Expires in 23h 14m" or "Expired" if past. Create a `Countdown` component that updates every minute.
- **Acceptance criteria:**
  - All raw unix timestamps replaced with human-readable dates (e.g., "Mar 5, 2026 at 3:14 PM")
  - Active timeout windows show countdown ("Expires in Xh Ym")
  - Countdown updates every 60 seconds without full page re-render
  - Expired timeouts show "Expired" in red
  - `formatTimestamp` utility is reusable and handles BigInt input
  - `pnpm turbo build` passes
- **Dependencies:** NC-029
- **Constraints:** No date library (use `Intl.DateTimeFormat` and manual math for countdown). `Countdown` component uses `useEffect` + `setInterval` (60s). Clean up interval on unmount.

---

## Phase 7: Manual Integration + Demo (Day 9)

> **NOTE:** NC-020 through NC-022 are MANUAL tasks executed by Mateo, not Nightcrawler.
> Nightcrawler must skip these (they are marked 🚧 MANUAL).

#### NC-020 [🚧] MANUAL — Deploy to Base Sepolia and verify
- **What:** Mateo deploys using the script from NC-013: `forge script script/Deploy.s.sol --broadcast --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY`. Verify all contracts on Basescan. Fund test wallets with Base Sepolia ETH and MockStablecoin. Record deployed addresses in DEPLOYMENTS.md. Update frontend `.env` with real addresses.
- **Acceptance criteria:**
  - All 3 contracts deployed and verified on Basescan
  - DEPLOYMENTS.md updated with real addresses and tx hashes
  - Frontend `.env` updated with deployed addresses
  - Test wallets funded
- **Dependencies:** NC-013, NC-016B
- **Constraints:** MANUAL — Nightcrawler cannot execute (requires private key and Base Sepolia RPC access). Skip automatically.

#### NC-021 [🚧] MANUAL — End-to-end integration testing on Base Sepolia
- **What:** Mateo tests full lifecycle of both rails through the frontend on Base Sepolia testnet. PvP: create → accept → submit → confirm → claim. Pool: create → stake (multiple wallets) → close → resolve → claim. Document any bugs found in a `BUGS.md` file.
- **Acceptance criteria:**
  - PvP lifecycle completes without errors through frontend
  - Pool lifecycle completes without errors through frontend
  - Token balances update correctly after claims
  - No transaction reverts on valid paths
  - BUGS.md created with any issues found
- **Dependencies:** NC-020
- **Constraints:** MANUAL — requires browser wallet interaction on Base Sepolia. At least 2 wallet addresses.

#### NC-022 [🚧] MANUAL — Bug fixes, demo prep, submission
- **What:** Fix bugs from NC-021. Prepare demo script. Update README. Final Base Sepolia smoke test. Submit for internal review.
- **Acceptance criteria:**
  - Critical bugs fixed
  - README complete with setup instructions and deployed addresses
  - Demo script documented
  - `forge test` still passes
  - Internal review complete
- **Dependencies:** NC-021
- **Constraints:** MANUAL — Mateo executes. Nightcrawler may assist with bug fixes if specific fix tasks are added to the queue.

---

## Phase 8: Production Polish + Features (Post-Deploy)

> **CONTEXT:** Contracts are live on Base Sepolia. Frontend `.env` has real addresses. The app works end-to-end. This phase focuses on making the product feel real — design, UX, missing features, and hardening.

#### NC-031 [x] Add a faucet / mint page for testnet tokens
- **What:** Create `/faucet` page that lets connected users mint MockStablecoin (mUSDC) to themselves. Form: amount input (default 1000), "Mint" button. Calls `MockStablecoin.mint(connectedAddress, amount * 10^6)`. Shows current mUSDC balance before and after. Include a note: "This is testnet mUSDC — no real value."
- **Acceptance criteria:**
  - `/faucet` page renders with amount input and mint button
  - Minting works and updates displayed balance
  - Shows current mUSDC balance of connected wallet
  - Disabled / prompt when not connected
  - Transaction pending/success/error states
  - Nav link added: "Faucet"
  - `pnpm turbo build` passes
- **Dependencies:** NC-030
- **Constraints:** Page at `apps/web/src/app/faucet/`. Use `useWriteContract` + `useWaitForTransactionReceipt`. Read balance with `useReadContract` on `balanceOf`. Re-fetch balance after mint. Import `mockStablecoinAbi` and `TOKEN_ADDRESS` from `@/lib/contracts`.

#### NC-032 [x] Add token balance display to nav and action pages
- **What:** Show the connected user's mUSDC balance in the nav bar next to the wallet address (e.g., "0x265b…bb32 | 1,000.00 mUSDC"). Also show balance on create pages (`/challenges/create`, `/pools/create`) above the stake input so users know how much they can stake. Format with 2 decimal places and comma separators.
- **Acceptance criteria:**
  - Nav shows mUSDC balance next to address when connected
  - Create pages show balance above stake input
  - Balance formatted: "1,000.00 mUSDC"
  - Balance updates after transactions (mint, create, stake)
  - `pnpm turbo build` passes
- **Dependencies:** NC-031
- **Constraints:** Read from `MockStablecoin.balanceOf(address)`. Use `useReadContract` with `watch: true` or refetch after writes. Format with `Intl.NumberFormat`.

#### NC-033 [x] Add challenge/pool status filters and sorting
- **What:** On `/challenges` list page, add filter buttons: "All", "Open" (CREATED), "Active" (ACCEPTED/SUBMITTED), "Resolved" (FINALIZED/VOIDED). On `/pools` list page, add filters: "All", "Open", "Closed", "Resolved". Default to "All". Add sort toggle: newest first / oldest first.
- **Acceptance criteria:**
  - Filter buttons render on both list pages
  - Clicking a filter shows only matching items
  - Active filter is visually highlighted
  - Sort toggle works (by ID descending/ascending)
  - "All" is the default
  - Empty state shown when filter yields no results
  - `pnpm turbo build` passes
- **Dependencies:** NC-030
- **Constraints:** Client-side filtering only (data is already loaded via multicall). Use state for active filter. Keep filter buttons as simple styled buttons, not a dropdown.

#### NC-034 [x] Add "My Challenges" and "My Pools" views
- **What:** On `/challenges` page, add a toggle: "All Challenges" / "My Challenges". "My Challenges" filters to challenges where connected wallet is creator OR opponent. On `/pools` page, same toggle: "All Pools" / "My Pools". "My Pools" filters to pools where the user has staked (yesStake > 0 or noStake > 0) — requires reading `getStakes(poolId, address)` for each pool.
- **Acceptance criteria:**
  - Toggle renders on both list pages (only when wallet connected)
  - "My Challenges" shows only challenges where user is creator or opponent
  - "My Pools" shows only pools where user has a stake
  - Toggle state preserved when navigating back to list
  - Shows "You have no challenges/pools yet" empty state
  - `pnpm turbo build` passes
- **Dependencies:** NC-033
- **Constraints:** For "My Pools", batch-read `getStakes` for all pools using `useReadContracts`. Only show toggle when wallet is connected. Works alongside the status filters from NC-033 (both can be active).

#### NC-035 [x] Add dark mode with system preference detection
- **What:** Implement dark mode using Tailwind's `dark:` variant. Detect system preference with `prefers-color-scheme` media query. Add a theme toggle button in the nav (sun/moon icon). Persist preference in `localStorage`. Apply dark variants to all existing pages: backgrounds, text, borders, badges, form inputs, buttons.
- **Acceptance criteria:**
  - Dark mode applies to all pages consistently
  - System preference detected on first visit
  - Toggle button in nav switches between light/dark
  - Preference persisted in localStorage
  - State badges retain their color meanings in dark mode
  - Form inputs and buttons are readable in both modes
  - No flash of wrong theme on page load
  - `pnpm turbo build` passes
- **Dependencies:** NC-030
- **Constraints:** Use Tailwind `dark:` classes. Add `darkMode: 'class'` to Tailwind config if needed. Theme provider in `Providers.tsx`. Use `suppressHydrationWarning` on `<html>` to prevent hydration mismatch. Inline script in `layout.tsx` `<head>` to set class before render (prevents flash).

#### NC-036 [x] Improve form validation and UX on create pages
- **What:** Enhance both create pages (`/challenges/create`, `/pools/create`) with: 1) Real-time validation as user types (debounced). 2) Check if user has sufficient mUSDC balance before allowing submit. 3) Show estimated gas cost. 4) Add "Max" button next to stake input that fills with user's full balance. 5) Disable submit if balance < stake amount. 6) Show allowance status — if already approved, skip approve step.
- **Acceptance criteria:**
  - Real-time validation on blur or after 500ms debounce
  - Insufficient balance warning shown inline
  - "Max" button fills stake with full mUSDC balance
  - Submit disabled when balance insufficient
  - If existing allowance >= stake, skip approve step (read `allowance(user, escrow)`)
  - `pnpm turbo build` passes
- **Dependencies:** NC-032
- **Constraints:** Read `balanceOf` and `allowance` with `useReadContract`. Debounce validation with `setTimeout` (no lodash). Skip approve only when `allowance >= stakeAmount` — otherwise do the full approve-then-write flow.

#### NC-037 [ ] Add transaction history to challenge and pool detail pages
- **What:** On `/challenges/[id]`, show a timeline of events: "Created by 0x265b…bb32 at Mar 5 3:14 PM", "Accepted by 0x1111…1111 at Mar 5 3:20 PM", etc. Derive from challenge timestamps (createdAt, acceptedAt, submittedAt, disputedAt, resolvedAt, appealedAt). On `/pools/[id]`, show: "Created by host", "Closed at eventStart", "Resolved: YES wins", etc. Style as a vertical timeline.
- **Acceptance criteria:**
  - Challenge detail shows chronological event timeline
  - Pool detail shows chronological event timeline
  - Only shows events that have occurred (skip zero timestamps)
  - Timestamps formatted with `formatTimestamp` from utils
  - Timeline styled as vertical line with dots/markers
  - `pnpm turbo build` passes
- **Dependencies:** NC-030
- **Constraints:** Derive all events from on-chain data (timestamps on the structs). No event log fetching needed. Reuse `formatTimestamp`. Simple vertical timeline with Tailwind — no timeline library.

#### NC-038 [ ] Add share / copy link buttons
- **What:** On challenge and pool detail pages, add a "Copy Link" button that copies the current URL to clipboard. Add a "Share on X" button that opens a pre-filled tweet: "I just [created/staked on] a challenge on Clout! [URL]". Show a brief "Copied!" tooltip on copy.
- **Acceptance criteria:**
  - "Copy Link" button on both detail pages
  - Copies current URL to clipboard via `navigator.clipboard.writeText`
  - Shows "Copied!" feedback for 2 seconds
  - "Share on X" button opens Twitter intent URL in new tab
  - Tweet text includes challenge/pool context and URL
  - `pnpm turbo build` passes
- **Dependencies:** NC-030
- **Constraints:** Twitter intent URL: `https://twitter.com/intent/tweet?text=...&url=...`. URL-encode the text. Use `encodeURIComponent`.

#### NC-039 [ ] Add comprehensive error boundaries
- **What:** Create a React error boundary component (`apps/web/src/components/ErrorBoundary.tsx`) that catches render errors and shows a fallback UI: "Something went wrong" with a "Try again" button (calls `reset()`). Wrap each page's client component in an error boundary. Also add specific handling for common contract errors: "User rejected transaction", "Insufficient funds for gas", "Execution reverted" — show user-friendly messages.
- **Acceptance criteria:**
  - ErrorBoundary component catches render errors
  - Fallback UI shows error message and reset button
  - Each page's client component wrapped in ErrorBoundary
  - Contract error messages mapped to user-friendly text
  - "User rejected" shows "Transaction cancelled" (not a scary error)
  - `pnpm turbo build` passes
- **Dependencies:** NC-030
- **Constraints:** Use React class component for error boundary (hooks can't catch render errors). Map error codes in `parseRevertReason` or a new `friendlyError` utility. Keep the fallback UI simple.

#### NC-040 [ ] Add README with setup instructions and architecture overview
- **What:** Rewrite `README.md` with: 1) One-line description. 2) Architecture diagram (mermaid in markdown). 3) Tech stack list. 4) Local development setup (prerequisites, install, env setup, dev server). 5) Contract deployment instructions. 6) Project structure (monorepo layout). 7) Testing instructions. 8) Deployed addresses (link to DEPLOYMENTS.md).
- **Acceptance criteria:**
  - README has all 8 sections
  - Architecture diagram shows: User → Frontend → wagmi → Base Sepolia → Contracts
  - Setup instructions work from a clean clone
  - Prerequisites listed: Node 20+, pnpm, Foundry
  - `pnpm install && pnpm turbo build` documented
  - Link to DEPLOYMENTS.md for live addresses
  - `pnpm turbo build` passes
- **Dependencies:** NC-030
- **Constraints:** Keep it concise — README, not a book. Mermaid diagram in markdown (GitHub renders it). Don't include private keys or real secrets in examples.


#### NC-041 [ ] Add Basescan links for all on-chain data
- **What:** Everywhere an address or transaction hash is displayed, make it a clickable link to Basescan. Addresses link to `https://sepolia.basescan.org/address/{addr}`. Tx hashes link to `https://sepolia.basescan.org/tx/{hash}`. Create a utility `basescanUrl(type: 'address' | 'tx', value: string): string` in `apps/web/src/lib/utils.ts`. Apply to: challenge detail (creator, opponent, resolver, token addresses), pool detail (host, resolver), tx hash displays after writes, WalletRecord component.
- **Acceptance criteria:**
  - All addresses on detail pages link to Basescan
  - All tx hashes shown after writes link to Basescan
  - Links open in new tab (`target="_blank" rel="noopener"`)
  - Utility function exported from `lib/utils.ts`
  - Addresses still show truncated but link to full address
  - `pnpm turbo build` passes
- **Dependencies:** NC-030
- **Constraints:** Base Sepolia explorer: `https://sepolia.basescan.org`. Make the base URL configurable via `NEXT_PUBLIC_EXPLORER_URL` env var (default to sepolia basescan). Add this var to `.env.example`.

#### NC-042 [ ] Add 404 and custom error pages
- **What:** Create custom Next.js error pages: `apps/web/src/app/not-found.tsx` (404) and `apps/web/src/app/error.tsx` (runtime errors). 404 page shows "Page not found" with link back to home. Error page shows "Something went wrong" with retry button. Both should match the app's visual style (nav visible, centered content).
- **Acceptance criteria:**
  - `/nonexistent-path` shows custom 404 page
  - 404 page has link to home
  - Error page has retry button
  - Both pages render within the app layout (nav visible)
  - `pnpm turbo build` passes
- **Dependencies:** NC-035
- **Constraints:** `not-found.tsx` is a Server Component. `error.tsx` must be a Client Component with `"use client"`. Follow Next.js 16 conventions.

#### NC-043 [ ] Add pool staking progress bars
- **What:** On `/pools/[id]` detail page, show visual progress bars for: 1) YES vs NO stake totals (horizontal bar, green=YES, red=NO, proportional width). 2) Total pool fill (current total / total cap, if cap exists). 3) Per-wallet remaining allowance (user's stake / wallet cap). Show percentages next to each bar.
- **Acceptance criteria:**
  - YES/NO bar shows proportional split with percentages
  - Total cap bar shows fill percentage
  - Per-wallet bar shows user's usage of their cap
  - Bars use Tailwind (green for YES, red for NO, blue for fill)
  - Handles edge cases: zero stakes (empty bar), no cap set (hide cap bar)
  - `pnpm turbo build` passes
- **Dependencies:** NC-030
- **Constraints:** Pure Tailwind for bars (colored divs with percentage widths). Calculate percentages in component. Handle division by zero.

#### NC-044 [ ] Add pool event countdown on list and detail pages
- **What:** On `/pools` list page, show time until eventStart for OPEN pools ("Starts in 2d 5h") and time until eventEnd for CLOSED pools ("Ends in 1d 3h"). On `/pools/[id]` detail page, show countdown for all relevant timestamps: eventStart, eventEnd, resolveBy. Use the existing `Countdown` component from NC-030. Past timestamps show "Started", "Ended", "Resolve deadline passed" respectively.
- **Acceptance criteria:**
  - Pool list shows countdown for eventStart/eventEnd per pool state
  - Pool detail shows countdowns for all three timestamps
  - Uses existing `Countdown` component
  - Past events show past-tense labels
  - `pnpm turbo build` passes
- **Dependencies:** NC-030
- **Constraints:** Reuse `Countdown` from NC-030. Pass `targetTimestamp` as BigInt. Component already handles expired state.

#### NC-045 [ ] Add keyboard shortcuts and accessibility improvements
- **What:** 1) Add keyboard shortcut: `Ctrl/Cmd + K` opens a quick-nav command palette (simple modal listing: Home, Challenges, Pools, Faucet, Create Challenge, Create Pool — clicking navigates). 2) Add `aria-label` attributes to all buttons and links. 3) Add focus-visible outlines for keyboard navigation. 4) Ensure all interactive elements are reachable via Tab.
- **Acceptance criteria:**
  - `Cmd+K` / `Ctrl+K` opens command palette overlay
  - Command palette lists all main navigation targets
  - Clicking an item navigates and closes palette
  - `Escape` closes palette
  - All buttons have `aria-label`
  - Focus-visible outlines visible on Tab navigation
  - `pnpm turbo build` passes
- **Dependencies:** NC-035
- **Constraints:** Command palette is a simple modal with `<dialog>` or a div with `role="dialog"`. No command palette library. Use `useEffect` for keyboard listener. Clean up on unmount.

#### NC-046 [ ] Add confirmation dialogs for high-stakes actions
- **What:** Before executing these actions, show a confirmation dialog: 1) Accept Challenge ("You are about to stake X mUSDC. Confirm?"). 2) Dispute Result ("Filing a dispute escalates to resolver/admin. Continue?"). 3) Claim Winnings ("Claim your winnings from this challenge/pool?"). Create a reusable `ConfirmDialog` component that accepts title, message, onConfirm, onCancel.
- **Acceptance criteria:**
  - ConfirmDialog component is reusable with title/message/callbacks
  - Accept, Dispute, and Claim actions show confirmation before executing
  - Dialog shows the specific amount/context
  - "Cancel" dismisses without action
  - "Confirm" proceeds with the transaction
  - Dialog is accessible (focus trap, Escape to close)
  - `pnpm turbo build` passes
- **Dependencies:** NC-039
- **Constraints:** Use `<dialog>` element or a modal div. No modal library. Keep it simple — not a full design system modal.

#### NC-047 [ ] Add SEO-optimized dynamic metadata for all pages
- **What:** Ensure every page has proper metadata using Next.js `generateMetadata` or static `metadata` export. Pages to check/add: `/faucet`, `/challenges` (count in description), `/pools` (count in description), `/challenges/[id]` (already done), `/pools/[id]` (add pool description/host). Add `canonical` URL to all pages. Add JSON-LD structured data to home page (WebApplication schema).
- **Acceptance criteria:**
  - All pages have `title` and `description` metadata
  - Dynamic pages include relevant context in description
  - `canonical` URL set on all pages
  - Home page has JSON-LD WebApplication schema
  - No duplicate titles across pages
  - `pnpm turbo build` passes
- **Dependencies:** NC-031
- **Constraints:** Use Next.js metadata API only. JSON-LD via `<script type="application/ld+json">` in a Server Component. Canonical URL from `NEXT_PUBLIC_APP_URL` env var.

#### NC-048 [ ] Add global notification for chain mismatch
- **What:** If the connected wallet is on the wrong chain (not Base Sepolia, chain ID 84532), show a persistent banner at the top of the page: "Wrong network — please switch to Base Sepolia" with a "Switch Network" button. The button calls `switchChain` from wagmi. Hide the banner when on the correct chain. All action buttons should be disabled when on wrong chain.
- **Acceptance criteria:**
  - Banner shows when connected to wrong chain
  - "Switch Network" button calls `useSwitchChain` from wagmi
  - Banner hides when on correct chain or disconnected
  - Action buttons disabled when on wrong chain
  - Banner is visually prominent (yellow/orange background)
  - `pnpm turbo build` passes
- **Dependencies:** NC-030
- **Constraints:** Use `useChainId` and `useSwitchChain` from wagmi. Target chain ID: 84532 (Base Sepolia). Banner component in layout, outside of `<main>`.

#### NC-049 [ ] Add recent activity feed to home page
- **What:** On the home page, below the WalletRecord, show a "Recent Activity" section. Read the last 5 challenges and last 5 pools (by ID, newest first) and display them as a combined feed sorted by creation time. Each entry shows: type (Challenge/Pool), ID, creator/host, stake/total, state badge, relative time ("2 hours ago"). Each entry links to its detail page.
- **Acceptance criteria:**
  - Home page shows "Recent Activity" section
  - Last 5 challenges + last 5 pools loaded and merged by time
  - Each entry shows type, ID, key info, state badge, relative time
  - Entries link to detail pages
  - Loading skeleton while fetching
  - Empty state if no challenges or pools exist
  - `pnpm turbo build` passes
- **Dependencies:** NC-033
- **Constraints:** Read `challengeCount` and `poolCount`, then batch-read the last 5 of each with `useReadContracts`. Merge and sort by timestamp. Relative time: use manual calculation ("Xh ago", "Xd ago") — no library.


#### NC-051 [ ] Add contract verification script for Basescan
- **What:** Create `packages/contracts/script/Verify.sh` that runs `forge verify-contract` for all 3 contracts on Base Sepolia. Use Basescan API. Script reads addresses from environment or accepts them as arguments. Document the verify command in `DEPLOYMENTS.md`. Add `BASESCAN_API_KEY` to `.env.example`.
- **Acceptance criteria:**
  - `Verify.sh` runs `forge verify-contract` for MockStablecoin, CloutEscrow, CloutPool
  - Uses `--chain base-sepolia` and `--etherscan-api-key`
  - `BASESCAN_API_KEY` added to `.env.example`
  - `DEPLOYMENTS.md` updated with verification instructions
  - Script is executable (`chmod +x`)
- **Dependencies:** NC-030
- **Constraints:** Use `forge verify-contract --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY`. Basescan uses the same API as Etherscan. Contract addresses should be read from env vars or passed as args.

#### NC-052 [ ] Add 18+ age gate on first visit
- **What:** On first visit, show a fullscreen modal: "You must be 18 or older to use Clout. This platform involves wagering with real digital assets." Two buttons: "I am 18+" (dismisses, sets `localStorage` flag) and "Exit" (redirects to google.com). The gate blocks ALL interaction until acknowledged. On subsequent visits, check `localStorage` — if already confirmed, don't show again.
- **Acceptance criteria:**
  - Fullscreen modal on first visit, blocks all content
  - "I am 18+" sets localStorage flag and dismisses
  - "Exit" redirects away from the site
  - Subsequent visits skip the gate (localStorage check)
  - Modal is not dismissible by clicking outside or pressing Escape
  - `pnpm turbo build` passes
- **Dependencies:** NC-035
- **Constraints:** Component at `apps/web/src/components/AgeGate.tsx` (`"use client"`). Render in `Providers.tsx` or layout. Use `localStorage.getItem('clout-age-verified')`. The modal must render ABOVE everything (z-50+). No scroll on body while modal is open.

#### NC-053 [ ] Add responsible gambling disclosures
- **What:** 1) Add a footer to the layout with: "Clout is a skill-based competition platform. Not available in all jurisdictions. 18+ only. Please wager responsibly." 2) On `/challenges/create` and `/pools/create` pages, add a small disclaimer below the submit button: "By creating this challenge/pool, you confirm you are 18+ and understand you may lose your staked tokens." 3) Add a `/terms` page with basic terms of use (not legal advice — placeholder structure).
- **Acceptance criteria:**
  - Footer visible on all pages with disclaimer text
  - Create pages show disclaimer below submit button
  - `/terms` page exists with placeholder ToS structure
  - Footer links to `/terms`
  - Footer styled subtly (small text, muted color)
  - `pnpm turbo build` passes
- **Dependencies:** NC-052
- **Constraints:** Footer in `layout.tsx` outside `<main>`. Terms page at `apps/web/src/app/terms/page.tsx` (Server Component with static content). Keep disclaimers factual and short — this is not legal counsel.

#### NC-054 [ ] Build a proper landing/hero section on home page
- **What:** Replace the current minimal home page with a proper hero section: 1) Large heading: "The conviction market for the creator economy". 2) Subheading: "Stake on outcomes. Build your track record. Prove your edge." 3) Two CTA buttons: "Browse Challenges" → `/challenges`, "Explore Pools" → `/pools`. 4) Below hero: stats section showing total challenges, total pools, total volume staked (read from contracts). 5) Keep WalletRecord section below for connected users.
- **Acceptance criteria:**
  - Hero section with heading, subheading, two CTA buttons
  - Stats section reads `challengeCount` from CloutEscrow and `poolCount` from CloutPool
  - Stats show: "X Challenges", "Y Pools" (volume requires summing stakes — skip if too complex, just show counts)
  - Responsive layout (stacks on mobile)
  - WalletRecord section preserved below for connected users
  - `pnpm turbo build` passes
- **Dependencies:** NC-035
- **Constraints:** No images or illustrations — text + layout only. Use Tailwind for all styling. Hero should feel bold but clean — large text, generous whitespace. Dark mode compatible.

