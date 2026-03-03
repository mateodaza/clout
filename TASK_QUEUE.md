# Task Queue — Clout

> This file is consumed by Nightcrawler. Tasks are executed in order, respecting dependencies.
> Only Mateo adds or reorders tasks. Nightcrawler marks completion status.
> Tasks use stable IDs (NC-001, NC-002, etc.) that never change when tasks are reordered.

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

#### NC-010 [ ] CloutEscrow comprehensive test suite + invariant checks
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

#### NC-G1 [ ] Gate 1: CloutEscrow complete
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

#### NC-011 [ ] Implement CloutPool.sol core (create, stake, close)
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

#### NC-012A [ ] Implement CloutPool resolution and dispute
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

#### NC-012B [ ] Implement CloutPool payouts
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

#### NC-012C [ ] CloutPool comprehensive test suite + invariant checks
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

#### NC-G2 [ ] Gate 2: Both contracts pass tests locally
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

#### NC-013 [ ] Create Anvil-verified deployment script
- **What:** Foundry deployment script (`script/Deploy.s.sol`) that deploys: 1) MockStablecoin, 2) CloutEscrow, 3) CloutPool. Then configures: whitelist MockStablecoin on both contracts, set protocol fee to 250 bps, set treasury address. Logs all deployed addresses. Create `DEPLOYMENTS.md` template with placeholders for Fuji addresses. Script must work on local Anvil — this is the Nightcrawler-executable scope. Fuji broadcast is a manual step for Mateo.
- **Acceptance criteria:**
  - Script deploys all 3 contracts in correct order
  - Constructor args: owner = `vm.envAddress("OWNER_ADDRESS")`, treasury = `vm.envAddress("TREASURY_ADDRESS")`, feeBps = `vm.envUint("FEE_BPS")` (default 250)
  - Configuration calls succeed: whitelist MockStablecoin on both contracts, set protocol fee, set treasury
  - All addresses logged to console
  - Script works on local Anvil: `forge script script/Deploy.s.sol --fork-url http://localhost:8545 --broadcast`
  - DEPLOYMENTS.md has structured placeholders for Fuji addresses, verified-on links, and tx hashes
  - `.env.example` created with `OWNER_ADDRESS`, `TREASURY_ADDRESS`, `FEE_BPS`, `PRIVATE_KEY`, `FUJI_RPC_URL` (all placeholder values)
  - Owner == deployer initially. No ownership transfer in script (Mateo does this manually if needed).
- **Dependencies:** NC-G2
- **Constraints:** Use `forge script` with `vm.envAddress`/`vm.envUint` for all configurable values. NEVER hardcode keys or addresses. Anvil testing only — Nightcrawler does NOT broadcast to Fuji.

---

## Phase 6: Frontend (Days 7-8)

#### NC-014 [ ] Initialize Next.js frontend with wallet connection
- **What:** Next.js app (in `frontend/` subdirectory) with Tailwind CSS, wagmi v2, viem, RainbowKit (or similar wallet connector). Configure for Avalanche Fuji network. Import contract ABIs from Foundry artifacts (`out/` directory). Environment variables for contract addresses (`NEXT_PUBLIC_ESCROW_ADDRESS`, `NEXT_PUBLIC_POOL_ADDRESS`, `NEXT_PUBLIC_TOKEN_ADDRESS`) and Fuji RPC (`NEXT_PUBLIC_RPC_URL`). Create `.env.example` with placeholder values.
- **Acceptance criteria:**
  - `pnpm dev` runs without errors
  - Wallet connection component renders and connects (tested visually against Anvil if possible)
  - Contract ABIs imported and typed (generated from Foundry `out/` artifacts)
  - Fuji chain configured in wagmi config (chain ID 43113)
  - Basic layout with navigation: Challenges, Pools
  - `.env.example` with all required env vars documented
- **Dependencies:** NC-013
- **Constraints:** Keep dependencies minimal. No state management library — wagmi hooks are sufficient. Tailwind for styling, no component library needed for MVP.

#### NC-015A [ ] Build PvP Escrow challenge list and create pages
- **What:** Two pages: `/challenges` (list active challenges from contract reads — loop over `challengeCount`, read each challenge, filter by state), `/challenges/create` (form: opponent address, stake amount, token select, game description, resolver address — calls `approve` then `createChallenge`).
- **Acceptance criteria:**
  - `/challenges` page lists challenges with: ID, creator, opponent, stake, state badge, game
  - List reads directly from contract (no indexer)
  - `/challenges/create` form validates: non-empty opponent, positive stake, valid addresses
  - Form calls `approve` then `createChallenge` with loading/success/error states
  - Transaction hash shown on success
  - Tests: not required for frontend (manual verification by Mateo)
- **Dependencies:** NC-014
- **Constraints:** Read challenge data directly from contract. Keep UI functional, not polished.

#### NC-015B [ ] Build PvP Escrow challenge detail page
- **What:** `/challenges/[id]` page: reads challenge by ID, shows all fields (creator, opponent, stake, state, outcome, timestamps, resolver). Dynamic action buttons based on state and connected wallet: Accept (CREATED, if wallet == opponent), Submit Result (ACCEPTED, if wallet == creator or opponent), Confirm (SUBMITTED, if wallet == non-submitter), Dispute (SUBMITTED, if wallet == non-submitter), Claim (FINALIZED/VOIDED, if wallet == creator or opponent), Resolve (DISPUTED, if wallet == resolver or admin), Appeal (RESOLVED, if wallet == creator or opponent). Each button calls the corresponding contract function.
- **Acceptance criteria:**
  - Detail page shows all challenge fields and current state
  - Correct action buttons appear per state per caller role (at least 7 action buttons total)
  - Each action button calls the right contract function with correct args
  - Transactions show pending/success/error states
  - Page refreshes state after successful transaction
- **Dependencies:** NC-015A
- **Constraints:** One component per action. Keep rendering logic state-driven (switch on ChallengeState enum).

#### NC-016A [ ] Build Challenge Pools list and create pages
- **What:** Two pages: `/pools` (list active pools from contract reads), `/pools/create` (form: event description, eventStart, eventEnd, resolveBy timestamps, resolver address, per-wallet cap, total cap, host commission bps, initial YES stake — calls `approve` then `createPool`).
- **Acceptance criteria:**
  - `/pools` page lists pools with: ID, host, state, YES/NO totals, event times
  - `/pools/create` form validates timestamps (eventStart > now, eventStart < eventEnd < resolveBy), caps > 0, commission bps <= 10000
  - Form calls `approve` then `createPool`
  - Transaction states shown
- **Dependencies:** NC-014
- **Constraints:** Read pool data from contract directly. Same patterns as NC-015A.

#### NC-016B [ ] Build Challenge Pools detail page
- **What:** `/pools/[id]` page: shows pool state, YES/NO totals, user's stake, event times, resolver. Action buttons: Stake YES / Stake NO (OPEN, if under caps), Resolve (CLOSED, if wallet == resolver), Flag Dispute (SUBMITTED, if wallet on losing side), Claim (FINALIZED, if wallet is staker), Admin Resolve (DISPUTED, if wallet == admin).
- **Acceptance criteria:**
  - Detail page shows all pool fields, YES/NO totals, user's current stake
  - Correct action buttons per state per role
  - Stake buttons enforce cap display (show remaining allowance)
  - Resolver sees resolve button when pool is CLOSED
  - Transactions show pending/success/error states
- **Dependencies:** NC-016A
- **Constraints:** Same patterns as NC-015B.

---

## Phase 7: Manual Integration + Demo (Day 9)

> **NOTE:** NC-020 through NC-022 are MANUAL tasks executed by Mateo, not Nightcrawler.
> Nightcrawler must skip these (they are marked 🚧 MANUAL).

#### NC-020 [🚧] MANUAL — Deploy to Fuji and verify
- **What:** Mateo deploys using the script from NC-013: `forge script script/Deploy.s.sol --broadcast --rpc-url $FUJI_RPC_URL --private-key $PRIVATE_KEY`. Verify all contracts on Snowtrace. Fund test wallets with Fuji AVAX and MockStablecoin. Record deployed addresses in DEPLOYMENTS.md. Update frontend `.env` with real addresses.
- **Acceptance criteria:**
  - All 3 contracts deployed and verified on Snowtrace
  - DEPLOYMENTS.md updated with real addresses and tx hashes
  - Frontend `.env` updated with deployed addresses
  - Test wallets funded
- **Dependencies:** NC-013, NC-016B
- **Constraints:** MANUAL — Nightcrawler cannot execute (requires private key and Fuji RPC access). Skip automatically.

#### NC-021 [🚧] MANUAL — End-to-end integration testing on Fuji
- **What:** Mateo tests full lifecycle of both rails through the frontend on Fuji testnet. PvP: create → accept → submit → confirm → claim. Pool: create → stake (multiple wallets) → close → resolve → claim. Document any bugs found in a `BUGS.md` file.
- **Acceptance criteria:**
  - PvP lifecycle completes without errors through frontend
  - Pool lifecycle completes without errors through frontend
  - Token balances update correctly after claims
  - No transaction reverts on valid paths
  - BUGS.md created with any issues found
- **Dependencies:** NC-020
- **Constraints:** MANUAL — requires browser wallet interaction on Fuji. At least 2 wallet addresses.

#### NC-022 [🚧] MANUAL — Bug fixes, demo prep, submission
- **What:** Fix bugs from NC-021. Prepare demo script. Update README. Final Fuji smoke test. Submit to Build Games.
- **Acceptance criteria:**
  - Critical bugs fixed
  - README complete with setup instructions and deployed addresses
  - Demo script documented
  - `forge test` still passes
  - Submitted to Build Games Stage 2
- **Dependencies:** NC-021
- **Constraints:** MANUAL — Mateo executes. Nightcrawler may assist with bug fixes if specific fix tasks are added to the queue.
