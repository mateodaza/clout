# Clout — Task Backlog

All planned tasks. `queue-tasks.sh` reads this to suggest what to add to TASK_QUEUE.md.

Tasks marked MANUAL are skipped by Nightcrawler — Mateo executes them.

Source: GLOBAL_PLAN.md + RESEARCH.md

---

## Completed

#### NC-001 [x] Project scaffold, Foundry init, MockStablecoin
- **Dependencies:** None

#### NC-002 [x] CloutEscrow.sol initial setup and smoke tests
- **Dependencies:** NC-001

#### NC-003 [x] CloutEscrow core structs, enums, and createChallenge()
- **Dependencies:** NC-001

---

## CloutEscrow — Remaining Functions

#### NC-004 [ ] Implement acceptChallenge() and voidChallenge()
- **Dependencies:** NC-003
- **Acceptance criteria:**
  - `acceptChallenge()`: validate caller is designated opponent, challenge in CREATED state, transfer matching stake via safeTransferFrom, state → ACCEPTED, emit ChallengeAccepted event, update opponent WalletRecord entry stats
  - `voidChallenge()`: creator can void if CREATED and 48h elapsed since createdAt, either party can void if ACCEPTED and 48h elapsed since acceptedAt, refund stakes to both parties, state → VOIDED, emit ChallengeVoided event
  - Tests: happy path accept, wrong opponent revert, wrong state revert, void before timeout revert, void after timeout, void refunds both parties, WalletRecord updated on accept
- **Constraints:** nonReentrant on both, SafeERC20 for transfers, use vm.warp for timeout tests, use vm.prank for caller tests

#### NC-005 [ ] Implement submitResult() and confirmResult()
- **Dependencies:** NC-004
- **Acceptance criteria:**
  - `submitResult()`: either creator or opponent can submit, challenge must be ACCEPTED, stores Outcome + submittedBy + submittedAt, state → SUBMITTED, emit ResultSubmitted event
  - `confirmResult()`: only the non-submitter can confirm, must match submitted outcome, state → FINALIZED with confirmedOutcome, emit ResultConfirmed event
  - Auto-accept: if 24h passes after submitResult with no confirm/dispute, submitted result stands (enforced via finalizeResult or separate timeout check)
  - Tests: submit by creator, submit by opponent, confirm matching outcome, confirm mismatched outcome revert, only non-submitter can confirm, double submit revert, submit wrong state revert
- **Constraints:** nonReentrant, block.timestamp for 24h window, Outcome enum validation

#### NC-006 [ ] Implement disputeResult() and dispute entry logic
- **Dependencies:** NC-005
- **Acceptance criteria:**
  - `disputeResult()`: only the non-submitter can dispute (I-2), challenge must be SUBMITTED, state → DISPUTED, stores disputedAt timestamp, emit ResultDisputed event
  - Revert if caller is the submitter
  - Revert if not in SUBMITTED state
  - Revert if 24h confirm window already passed (auto-accept takes precedence)
  - Tests: dispute by non-submitter, dispute by submitter revert, dispute after 24h revert, dispute wrong state revert
- **Constraints:** nonReentrant, enforce I-2 invariant strictly

#### NC-007 [ ] Implement resolveDispute() with resolver and admin fallback
- **Dependencies:** NC-006
- **Acceptance criteria:**
  - `resolveDispute()`: designated resolver submits verdict (Outcome), challenge must be DISPUTED, state → RESOLVED, stores resolvedAt timestamp, emit DisputeResolved event
  - If no designated resolver (address(0)), only admin can resolve
  - Resolver timeout: if 48h passes since disputedAt with no resolution, admin becomes sole resolver
  - Admin can always resolve after resolver timeout
  - `resolvedChallenges` mapping tracks resolver → count for collusion detection
  - Add `resolvedAt` field to Challenge struct if not present
  - Tests: resolver resolves, admin resolves after timeout, resolver tries after timeout revert, non-resolver revert, wrong state revert, resolvedChallenges counter increments
- **Constraints:** nonReentrant, block.timestamp for 48h timeout, I-3 already enforced at creation

#### NC-008 [ ] Implement appealResolution() and finalizeResolution()
- **Dependencies:** NC-007
- **Acceptance criteria:**
  - `appealResolution()`: either creator or opponent can appeal within 24h of resolvedAt, challenge must be RESOLVED, state stays RESOLVED but sets appealedAt flag/timestamp, emit ResolutionAppealed event
  - If appealed: admin must re-resolve within 48h, use resolveDispute or separate adminResolve
  - Admin timeout on appeal: if 48h passes after appeal with no admin action → VOIDED (I-7), refund both, emit AdminTimeoutVoided event
  - `finalizeResolution()`: permissionless, callable after 24h appeal window if no appeal filed, state → FINALIZED, emit ResolutionFinalized event
  - Tests: appeal within window, appeal after window revert, finalize after no appeal, finalize during appeal window revert, admin timeout → void, admin resolves appeal
- **Constraints:** nonReentrant on state-changing functions, block.timestamp, I-7 invariant (admin timeout = VOIDED, never picks winner)

#### NC-009 [ ] Implement claimWinnings() with all payout paths
- **Dependencies:** NC-008
- **Acceptance criteria:**
  - `claimWinnings()`: challenge must be FINALIZED or VOIDED, caller must be creator or opponent
  - CREATOR_WIN: winner gets (2 * stake) minus protocol fee
  - OPPONENT_WIN: winner gets (2 * stake) minus protocol fee
  - DRAW: each gets stake minus (protocolFee / 2) — I-4
  - INVALID: full refund to both, no fee — I-4
  - VOIDED: full refund to both, no fee — I-4
  - Protocol fee: `(2 * stake) * feeBps / 10000`, sent to treasury address
  - Prevent double claim (track claimed status per challenge per party)
  - Update WalletRecord completion stats on claim: challengesCompleted++, challengesWon++ if winner — I-5
  - Update WalletRecord on void: challengesCompleted++ — I-5
  - Emit WinningsClaimed event with amount, fee, outcome
  - Tests: claim creator win, claim opponent win, claim draw split, claim invalid refund, claim voided refund, double claim revert, claim before finalized revert, protocol fee accuracy, treasury receives fee, WalletRecord updates correctly
- **Constraints:** nonReentrant, SafeERC20, CEI pattern (checks-effects-interactions), I-1 solvency invariant

#### NC-010 [ ] Protocol fee configuration and treasury management
- **Dependencies:** NC-003
- **Acceptance criteria:**
  - `setProtocolFee(uint256 newFeeBps)`: onlyOwner, max 1000 bps (10%), emit ProtocolFeeUpdated
  - `setTreasury(address newTreasury)`: onlyOwner, non-zero address, emit TreasuryUpdated
  - `protocolFeeBps` public view, `treasury` public view
  - `getWalletRecord(address)` public view returns WalletRecord
  - Constructor sets initial fee (250 bps) and treasury address
  - Tests: set fee, set fee over max revert, set treasury, set treasury zero revert, non-owner reverts, view functions return correct values
- **Constraints:** onlyOwner access control, basis points math (10000 = 100%)

#### NC-011 [ ] CloutEscrow integration tests and edge cases
- **Dependencies:** NC-009, NC-010
- **Acceptance criteria:**
  - Full lifecycle integration test: create → accept → submit → confirm → claim (happy path)
  - Full dispute lifecycle: create → accept → submit → dispute → resolve → finalize → claim
  - Full appeal lifecycle: create → accept → submit → dispute → resolve → appeal → admin resolve → claim
  - Timeout cascade: create → 48h → void → claim refund
  - Edge cases: claim from wrong challenge, unauthorized caller on every function, state machine skip attempt (e.g., resolve without dispute), multiple active challenges same players
  - Invariant test: I-1 solvency — contract balance >= sum of locked stakes at all times
  - Fuzz test: createChallenge with random valid inputs
  - Target: 30+ total CloutEscrow tests
- **Constraints:** Use vm.warp for all timeouts, vm.prank for caller spoofing, vm.expectRevert for revert checks, vm.expectEmit for event checks

---

## CloutPool

#### NC-012 [ ] CloutPool.sol core structs and createPool()
- **Dependencies:** NC-011
- **Acceptance criteria:**
  - Pool struct: host, token, totalYes, totalNo, perWalletCap, totalPoolCap, hostCommissionBps, designatedResolver, eventStart, resolveBy, state, outcome, createdAt
  - PoolState enum: OPEN, CLOSED, SUBMITTED, DISPUTED, FINALIZED, VOIDED
  - `createPool()`: host creates pool with parameters, must stake YES side (I-8), host cannot be resolver (I-9), emit PoolCreated event
  - Stake tracking: mapping(uint256 => mapping(address => StakeInfo)) with YES/NO amounts per user
  - poolCount counter, pools mapping
  - Tests: create pool happy path, host not staking YES revert, host is resolver revert, zero stake revert, event emission, pool counter increment
- **Constraints:** Ownable, ReentrancyGuard, SafeERC20, share whitelisted tokens with CloutEscrow or accept same IERC20 pattern

#### NC-013 [ ] Implement stakePool() and closePool()
- **Dependencies:** NC-012
- **Acceptance criteria:**
  - `stakePool()`: user stakes YES or NO, pool must be OPEN, enforce per-wallet cap (I-10), enforce total pool cap (I-11), transfer tokens, update totals, emit PoolStaked event
  - `closePool()`: callable after eventStart timestamp, state → CLOSED, emit PoolClosed event. Also callable by admin before eventStart if needed.
  - Revert staking after pool closed
  - Tests: stake YES, stake NO, exceed per-wallet cap revert, exceed total pool cap revert, stake after close revert, close at eventStart, close before eventStart revert (unless admin)
- **Constraints:** nonReentrant, SafeERC20, block.timestamp for eventStart

#### NC-014 [ ] Implement resolvePool() and pool dispute threshold
- **Dependencies:** NC-013
- **Acceptance criteria:**
  - `resolvePool()`: designated resolver submits YES or NO outcome, pool must be CLOSED, state → SUBMITTED, emit PoolResolved event
  - Resolver timeout: if resolveBy timestamp passes with no resolution → VOIDED, all refunded
  - Dispute threshold: if >20% of losing side stakers flag dispute → DISPUTED, admin resolves
  - `disputePoolResult()`: losing staker can flag, track flag count
  - Admin resolves disputed pools
  - VOIDED on no stakers
  - Tests: resolve happy path, resolver timeout → void, dispute threshold triggers, admin resolves dispute, void on no stakers
- **Constraints:** nonReentrant, block.timestamp, only resolver or admin can resolve

#### NC-015 [ ] Implement claimPoolWinnings() with proportional payout and host commission
- **Dependencies:** NC-014
- **Acceptance criteria:**
  - `claimPoolWinnings()`: pool must be FINALIZED or VOIDED, caller must have stakes
  - Fee deduction order per GLOBAL_PLAN: 1) protocolFee from total pool, 2) hostCommission from YES pool on YES win only (I-12), 3) proportional split of net losing pool to winners (I-14)
  - Payout formula: `payout = myStake + (myStake / totalWinningSide) * netLosingPool`
  - VOIDED: full refund of all stakes, no fees
  - Protocol fee on all non-void outcomes (I-13)
  - Prevent double claim
  - Last claimer absorbs rounding dust
  - Emit PoolWinningsClaimed event
  - Tests: claim winning side, claim losing side (gets nothing extra), host commission only on YES win, proportional split accuracy with multiple stakers, voided refund, double claim revert, fee calculation accuracy, rounding dust to last claimer
- **Constraints:** nonReentrant, SafeERC20, CEI pattern, careful with division rounding (always round down for user, contract keeps dust)

#### NC-016 [ ] CloutPool integration tests and edge cases
- **Dependencies:** NC-015
- **Acceptance criteria:**
  - Full pool lifecycle: create → stake (multiple users) → close → resolve → claim
  - Dispute lifecycle: create → stake → close → resolve → dispute threshold → admin resolve → claim
  - Void paths: timeout, no stakers after open
  - Edge cases: stake after close, claim before finalized, unauthorized resolver
  - Target: 15+ CloutPool tests
- **Constraints:** Use vm.warp, vm.prank, vm.deal for funding test accounts

---

## Deployment

#### NC-017 [ ] MANUAL — Base Sepolia deployment script and contract verification
- **Dependencies:** NC-016
- **Acceptance criteria:**
  - Forge deployment script: MockStablecoin → CloutEscrow → CloutPool
  - Configure: whitelist mock stablecoin, set protocol fee 250 bps, set treasury
  - Deploy to Base Sepolia via `forge script --broadcast --rpc-url base-sepolia`
  - Verify all contracts on Basescan
  - Record addresses in DEPLOYMENTS.md
  - Fund test wallets with Base Sepolia ETH and mock stablecoins
- **Constraints:** Requires RPC endpoint and deployer private key — MANUAL only

---

## Frontend

#### NC-018 [ ] MANUAL — Next.js project scaffold with wallet connection
- **Dependencies:** NC-017
- **Acceptance criteria:**
  - Next.js + Tailwind + wagmi + viem
  - Wallet connection via RainbowKit (Core wallet, MetaMask, injected)
  - ABI generation from Foundry artifacts
  - Base Sepolia network configuration
- **Constraints:** MANUAL — frontend is Mateo's domain

#### NC-019 [ ] MANUAL — Challenge list and create challenge UI
- **Dependencies:** NC-018
- **Acceptance criteria:**
  - `/challenges` page: list active challenges from contract events
  - `/challenges/create` page: create challenge form
- **Constraints:** MANUAL

#### NC-020 [ ] MANUAL — Challenge detail page with action components
- **Dependencies:** NC-019
- **Acceptance criteria:**
  - `/challenges/[id]` page: state display, action buttons per state
  - Actions: Accept, Submit, Confirm, Dispute, Claim
- **Constraints:** MANUAL

#### NC-021 [ ] MANUAL — Pool pages (list, create, detail, stake, claim)
- **Dependencies:** NC-018
- **Acceptance criteria:**
  - `/pools`, `/pools/create`, `/pools/[id]` pages
  - Stake YES/NO, resolve (for resolver), claim
- **Constraints:** MANUAL

#### NC-022 [ ] MANUAL — End-to-end Base Sepolia integration testing
- **Dependencies:** NC-020, NC-021
- **Acceptance criteria:**
  - Full PvP lifecycle through frontend on Base Sepolia
  - Full Pool lifecycle through frontend on Base Sepolia
- **Constraints:** MANUAL

#### NC-023 [ ] MANUAL — Demo prep and demo prep
- **Dependencies:** NC-022
- **Acceptance criteria:**
  - Demo script, video material, README with setup instructions
  - Final Base Sepolia smoke test
  - Submit to internal review
- **Constraints:** MANUAL — deadline March 9
