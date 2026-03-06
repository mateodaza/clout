# Clout — Global Plan (Nightcrawler-Ready)

**Version:** 1.0
**Date:** February 28, 2026
**Developer:** Mateo (solo — smart contracts, web app, deployment)
**Duration:** 9 days (Feb 28 → Mar 9)
**Target:** Internal MVP on Base Sepolia
**Target:** Working MVP on Base Sepolia testnet — PvP escrow + challenge pools, basic web app, one complete lifecycle per rail

---

## Source of Truth

All implementation references point to this document in the clutch repo:

| Document | Description |
|----------|-------------|
| `RESEARCH.md` | Full strategic specification (~1054 lines). Architecture target — what the system IS |
| `GLOBAL_PLAN.md` | This file. What to build WHEN. Nightcrawler's primary input. |
| `TASK_QUEUE.md` | Ordered tasks with NC-xxx IDs. Nightcrawler consumes this. |

This plan defines **what to build WHEN**. RESEARCH.md is the complete vision; this plan is the Base-Sepolia-testnet-first build order with accepted simplifications.

---

## Honest Assessment

9 days. Solo dev. Two contracts + web app + deployment. This works because:
1. Both contracts are escrow-pattern (well understood, no AMM math)
2. No proxy, no upgradeability, no governance — ship minimal
3. Manual resolution only (no oracles, no keeper, no API integration)
4. Frontend is a functional shell — not polished, just works
5. Foundry test suite written alongside contracts (not a separate phase)
6. Prior experience with EVM prediction market patterns (state machines, fee routing, RBAC)

**Where things will slip first:** Frontend polish and CloutPool. If behind, cut CloutPool features to absolute minimum (create + stake + resolve + claim) and polish the PvP escrow demo.

**The hard deadline:** March 9 is Stage 2 (MVP). No extensions. If it doesn't work on Base Sepolia by then, it doesn't ship.

---

## The 7 Simplifications

Every simplification reduces complexity while keeping both Rails in scope. Nothing is deleted — complexity is deferred to post-MVP.

| # | Simplification | Build Now | Defer to Later | RESEARCH.md Ref |
|---|---------------|-----------|--------------------------|-----------------|
| S1 | **Resolution: Manual only** | Submit/confirm/dispute + designated resolver + admin fallback. No auto-resolution. | Game API keepers, commit-reveal voting, UMA OOv3 | §10 |
| S2 | **Stablecoin: Mock ERC-20** | Deploy MockStablecoin.sol (6 decimals) on Base Sepolia. Accept any whitelisted IERC20. | Real USDT + USDC on mainnet | §7 |
| S3 | **Access control: Ownable** | Single owner for admin functions. Lightweight. | OpenZeppelin AccessControl with roles, multisig | §7 |
| S4 | **No conviction score on-chain** | Store WalletRecord struct (counters only). Score computed off-chain by frontend. | On-chain scoring, soulbound token, gating | §7 |
| S5 | **Pool mechanics: Minimal** | Fixed close time, per-wallet cap, total pool cap, proportional split, manual resolve. No AMM. | Uncapped pools, AMM pricing, automated resolution, discovery | §6 Rail B |
| S6 | **Frontend: Functional shell** | Create/join/submit/claim for both rails. No profiles, no leaderboard, no notifications. | Full UX, mobile optimization, social features | §6 |
| S7 | **No agent integration** | Contract is inherently agent-compatible (any wallet can call). No x402, no REST API. | x402, REST API, Coinbase Agentic Wallet integration | §9 |

---

## MVP-Critical Floor (CANNOT Be Cut)

Regardless of which gate is missed, these items must be delivered by March 9:

1. `CloutEscrow.sol` deployed on Base Sepolia — create, accept, submit, confirm, dispute, resolve, claim, void
2. Full PvP lifecycle demo: create challenge → accept → submit result → confirm → claim winnings
3. At least one dispute flow demonstrated: dispute → resolver decides → finalized
4. All timeout paths functional (48h create, 48h accept, 24h confirm, 48h resolver, 24h appeal, 48h admin)
5. DRAW and INVALID payout paths working
6. Protocol fee deducted correctly on settlement
7. Basic web app showing challenge list, create flow, and claim flow
8. 15+ Foundry tests passing

---

## Dependency Graph

```
Day 1-2:  Project scaffold + MockStablecoin + CloutEscrow core
            │
Day 3:    CloutEscrow resolution (dispute, resolve, appeal, timeouts)
            │
Day 4:    CloutEscrow payouts + fee routing + WalletRecord + tests
            │
         ══ GATE 1: CloutEscrow complete on local Foundry ══
            │
Day 5:    CloutPool.sol (create, stake, close, resolve, claim)
            │
         ══ GATE 2: Both contracts pass tests locally ══
            │
Day 6:    Base Sepolia deployment + verification
            │
Day 7:    Frontend shell (connect wallet, create challenge, lifecycle)
            │
Day 8:    Frontend CloutPool + integration testing on Base Sepolia
            │
Day 9:    Bug fixes, demo prep, submission
            │
         ══ GATE 3: MVP live on Base Sepolia, demo ready ══
```

**Critical path:** CloutEscrow → CloutPool → Base Sepolia deploy → Frontend → Demo

---

## Checkpoint Gates

### Gate 1 — End of Day 4

**Pass criteria:**
1. `CloutEscrow.sol` compiles with zero warnings
2. Full state machine works: CREATED → ACCEPTED → SUBMITTED → FINALIZED (mutual agreement path)
3. Dispute path works: SUBMITTED → DISPUTED → RESOLVED → FINALIZED (with appeal window)
4. All 6 timeout specifications functional (create 48h, accept 48h, confirm 24h, resolver 48h, admin 48h, appeal 24h)
5. Payout logic correct: CREATOR_WIN, OPPONENT_WIN, DRAW (50/50), INVALID (refund), VOIDED (refund)
6. Protocol fee deducted on WIN and DRAW, not on INVALID/VOIDED
7. WalletRecord struct updates on claim/void
8. 15+ Foundry tests passing
9. Designated resolver flow works (optional resolver, fallback to admin)

**If MISS:** Cut CloutPool entirely. Focus 100% on making PvP escrow bulletproof + frontend for one rail only. This is still a viable Stage 2 submission — PvP escrow alone demonstrates the conviction market thesis.

### Gate 2 — End of Day 5

**Pass criteria:**
1. `CloutPool.sol` compiles and passes 10+ tests
2. Pool lifecycle: OPEN → CLOSED → SUBMITTED → FINALIZED
3. Host commission paid only on YES wins
4. Per-wallet cap and total pool cap enforced
5. Host cannot be designated resolver (on-chain enforcement)
6. Host must stake YES side
7. Dispute threshold (>20% of losing stakers flag) works
8. VOIDED path works (timeout, no stakers)

**If MISS:** Ship CloutPool with reduced features — minimum: create pool, stake YES/NO, resolve, claim. Cut dispute threshold (admin-only resolution). Cut host commission (add post-competition).

### Gate 3 — End of Day 9

**Pass criteria:**
1. Both contracts deployed and verified on Base Sepolia (Basescan)
2. Frontend connects wallet, creates challenge, shows lifecycle
3. One complete PvP demo: create → accept → submit → confirm → claim
4. One complete Pool demo: create → stake → close → resolve → claim
5. Demo script ready for submission video

**If MISS:** This is the deadline. Ship whatever works. If frontend is broken, record a Foundry script demo showing contract interactions directly.

---

## Day-by-Day Breakdown

### Day 1 (Feb 28) — Project Scaffold + CloutEscrow Core

**Goal:** Foundry project compiles, MockStablecoin works, CloutEscrow core structs and create/accept flow functional.

| Task | RESEARCH.md Ref | Est. Hours |
|------|----------------|------------|
| Init Foundry project: `forge init`, Solidity 0.8.20, optimizer 200 | §7 | 1 |
| Install OpenZeppelin (IERC20, ReentrancyGuard, Ownable) | §7 | 0.5 |
| `MockStablecoin.sol`: ERC-20 with 6 decimals, public mint for testnet | §7 | 1 |
| Core structs: `Challenge`, `ChallengeState` enum, `Outcome` enum, `WalletRecord` | §7 | 1.5 |
| `createChallenge()`: validate inputs, transfer stake, emit event | §7 | 2 |
| `acceptChallenge()`: validate state + opponent, transfer matching stake | §7 | 1.5 |
| `voidChallenge()`: timeout-based void for CREATED and ACCEPTED states | §10 | 1.5 |
| Basic tests: create, accept, void-on-timeout | — | 2 |

**Risk:** None. Standard scaffolding + escrow pattern.

---

### Day 2 (Mar 1) — CloutEscrow Submit/Confirm + Dispute Entry

**Goal:** Mutual agreement path works end-to-end. Dispute trigger works.

| Task | RESEARCH.md Ref | Est. Hours |
|------|----------------|------------|
| `submitResult()`: either party submits outcome, starts 24h window | §7, §10 | 2 |
| `confirmResult()`: counterparty confirms same outcome → FINALIZED | §7, §10 | 1.5 |
| Auto-accept on 24h timeout (submitted result stands if no response) | §10 | 1.5 |
| `disputeResult()`: only non-submitter can dispute → DISPUTED | §7, §10 | 2 |
| Stablecoin whitelist: `addWhitelistedToken()`, `removeWhitelistedToken()` | §7 | 1 |
| Event emissions for all state transitions | §7 | 1 |
| Tests: submit/confirm flow, auto-accept, dispute trigger, only-non-submitter guard | — | 3 |

**Risk:** Low. The submit/confirm pattern is straightforward.

---

### Day 3 (Mar 2) — CloutEscrow Resolution + Appeals

**Goal:** Complete resolution pipeline: designated resolver, admin fallback, appeals, all timeouts.

| Task | RESEARCH.md Ref | Est. Hours |
|------|----------------|------------|
| `resolveDispute()`: designated resolver OR admin submits verdict | §10 | 2.5 |
| Resolver timeout (48h) → auto-fallback to admin | §10 | 1.5 |
| `appealResolution()`: either player appeals within 24h → escalate to admin | §10 | 2 |
| `finalizeResolution()`: permissionless call after 24h appeal window with no appeal | §10 | 1.5 |
| Admin timeout (48h after appeal) → auto-void, both refunded | §10 | 1.5 |
| Resolver tracking: `resolvedChallenges` mapping for collusion detection | §10 | 1 |
| Tests: full dispute cycle, resolver timeout, appeal flow, admin timeout, auto-finalize | — | 3 |

**Risk:** Medium. The appeal chain has multiple timeout paths. Test each one explicitly.

---

### Day 4 (Mar 3) — CloutEscrow Payouts + WalletRecord + Hardening

**Goal:** Money moves correctly. Reputation tracking works. GATE 1.

| Task | RESEARCH.md Ref | Est. Hours |
|------|----------------|------------|
| `claimWinnings()`: CREATOR_WIN/OPPONENT_WIN → winner gets pot minus fee | §10 | 2 |
| DRAW payout: 50/50 split minus fee (both players chose to play) | §10 | 1.5 |
| INVALID payout: full refund, no fee | §10 | 1 |
| Protocol fee routing: configurable basis points, sent to treasury address | §7 | 1.5 |
| WalletRecord updates on claimWinnings and voidChallenge | §7 | 1.5 |
| `getWalletRecord()` view function | §7 | 0.5 |
| Reentrancy guards on all external calls that transfer tokens | §7 | 1 |
| Edge case tests: double claim, claim wrong challenge, claim before finalized | — | 2 |
| Full lifecycle integration test: create → accept → submit → confirm → claim | — | 1 |

**GATE 1 CHECKPOINT:** CloutEscrow.sol complete. 15+ tests passing. All state transitions, timeouts, payouts, and edge cases covered.

---

### Day 5 (Mar 4) — CloutPool.sol

**Goal:** Challenge pools work end-to-end. GATE 2.

| Task | RESEARCH.md Ref | Est. Hours |
|------|----------------|------------|
| Core structs: `Pool`, `PoolState` enum, `Stake` tracking | §6 Rail B | 1.5 |
| `createPool()`: host creates with close time, event window, resolver, caps, commission rate | §6 Rail B | 2 |
| Host validation: must stake YES, cannot be own resolver | §6 Rail B | 1 |
| `stakePool()`: YES/NO stakes, per-wallet cap, total pool cap | §6 Rail B | 2 |
| `closePool()`: auto-close at eventStart (or callable after) | §6 Rail B | 1 |
| `resolvePool()`: designated resolver submits YES/NO | §6 Rail B | 1.5 |
| `claimPoolWinnings()`: proportional split of losing pool, host commission on YES win | §6 Rail B | 2 |
| Dispute threshold: >20% of losing stakers flag → admin review | §6 Rail B | 1.5 |
| VOIDED paths: timeout, no stakers | §6 Rail B | 1 |
| Tests: full pool lifecycle, host constraints, caps, commission, dispute threshold | — | 3 |

**GATE 2 CHECKPOINT:** Both contracts compile and pass tests. Ready for Base Sepolia deployment.

---

### Day 6 (Mar 5) — Base Sepolia Deployment

**Goal:** Contracts live on Base Sepolia. Verified on Basescan.

| Task | RESEARCH.md Ref | Est. Hours |
|------|----------------|------------|
| Deployment script: MockStablecoin → CloutEscrow → CloutPool | §7 | 2 |
| Configure: set admin, whitelist mock stablecoin, set protocol fee (250 bps = 2.5%) | §7 | 1 |
| Deploy to Base Sepolia via `forge script --broadcast --rpc-url base-sepolia` | — | 1 |
| Verify all contracts on Basescan | — | 1 |
| Smoke test on Base Sepolia: create challenge → accept → submit → confirm → claim | — | 2 |
| Record deployed addresses in `DEPLOYMENTS.md` | — | 0.5 |
| Fund test wallets with Base Sepolia ETH and mock stablecoins | — | 0.5 |

**Risk:** Low. Base Sepolia is stable. Foundry's forge script handles deployment well.

---

### Day 7 (Mar 6) — Frontend Shell (PvP Escrow)

**Goal:** Web app connects wallet, creates challenges, shows lifecycle.

| Task | RESEARCH.md Ref | Est. Hours |
|------|----------------|------------|
| Next.js project with Tailwind + wagmi + viem | §6 | 2 |
| Wallet connection (Core wallet / MetaMask / any injected) via RainbowKit or similar | §6 | 1.5 |
| ABI generation from Foundry artifacts → frontend | — | 1 |
| `/challenges` page: list active challenges from contract events | §6 | 2 |
| `/challenges/create` page: create challenge form (opponent, stake, game, resolver) | §6 | 2 |
| `/challenges/[id]` page: show challenge state, action buttons per state | §6 | 3 |
| Action components: Accept, Submit Result, Confirm, Dispute, Claim | §6 | 2 |

**Risk:** Medium. Frontend is the most likely place to slip. Keep it ugly-but-functional.

---

### Day 8 (Mar 7) — Frontend Pools + Integration

**Goal:** Pool UI works. Full integration tested on Base Sepolia.

| Task | RESEARCH.md Ref | Est. Hours |
|------|----------------|------------|
| `/pools` page: list active pools | §6 | 1.5 |
| `/pools/create` page: create pool form | §6 | 2 |
| `/pools/[id]` page: show pool state, stake YES/NO, claim | §6 | 3 |
| Pool action components: Stake, Resolve (for resolver), Claim | §6 | 2 |
| End-to-end Base Sepolia test: full PvP lifecycle through frontend | — | 2 |
| End-to-end Base Sepolia test: full Pool lifecycle through frontend | — | 2 |
| Fix bugs found during integration | — | 2 |

---

### Day 9 (Mar 8-9) — Polish + Demo + Submit

**Goal:** Demo-ready. Submission package complete.

| Task | RESEARCH.md Ref | Est. Hours |
|------|----------------|------------|
| Bug fixes from Day 8 testing | — | 3 |
| Demo script: step-by-step walkthrough of both rails | — | 1 |
| Record/prepare demo video material | §12 | 2 |
| Final Base Sepolia smoke test | — | 1 |
| Update README with setup instructions, deployed addresses | — | 1 |
| Submit to internal review | §12 | 1 |

---

## Contract Architecture Summary

### CloutEscrow.sol (~500-600 lines)

**Purpose:** 1v1 PvP match escrow with symmetric stakes.

**State machine:**
```
CREATED ──(accept)──→ ACCEPTED ──(submit)──→ SUBMITTED
  ↓ 48h                 ↓ 48h                    ↓
VOIDED               VOIDED              confirm → FINALIZED
                                         dispute → DISPUTED
                                         24h timeout → FINALIZED (auto-accept)
                                              ↓
                                         resolver resolves → RESOLVED
                                         48h resolver timeout → admin-only resolution
                                         (admin resolves from DISPUTED directly)
                                              ↓
                                         RESOLVED:
                                           24h no appeal → FINALIZED (permissionless call)
                                           appeal → admin reviews → FINALIZED
                                           48h admin timeout after appeal → VOIDED (refund both)
```

**Key invariants:**
- I-1: `token.balanceOf(contract) >= sum of all locked stakes` (solvency)
- I-2: Only non-submitter can dispute
- I-3: Resolver cannot be creator or opponent of the challenge
- I-4: DRAW pays 50/50 minus fee. INVALID/VOIDED pay full refund, no fee.
- I-5: WalletRecord has two update phases: entry stats (`challengesEntered`, `totalStaked`, `firstChallengeAt`, `lastChallengeAt`) update on create/accept; completion stats (`challengesCompleted`, `challengesWon`) update on claim/void only — never mid-dispute
- I-6: No state can be skipped (each transition validates current state)
- I-7: Admin timeout always results in VOIDED (refund), never a winner pick

### CloutPool.sol (~300-400 lines)

**Purpose:** 1-to-many challenge pools with asymmetric stakes.

**State machine:**
```
OPEN ──(eventStart)──→ CLOSED ──(resolve)──→ SUBMITTED
  ↓ no stakers            ↓ resolveBy timeout     ↓ 24h no dispute
VOIDED                  VOIDED                  FINALIZED
                                                 ↓ dispute threshold
                                               DISPUTED → admin → FINALIZED
```

**Key invariants:**
- I-8: Host must stake YES side
- I-9: Host cannot be designated resolver
- I-10: Per-wallet cap enforced on every stake
- I-11: Total pool cap enforced
- I-12: Host commission only on YES outcome
- I-13: Protocol fee on all non-void outcomes
- I-14: Proportional payout: `payout = myStake + (myStake / totalWinningSide) * netLosingPool` where `netLosingPool = totalLosingSide - protocolFee - hostCommission`. Winners receive original stake PLUS pro-rata share of net losing pool.

---

## Fee Structure

| Parameter | Value | Notes |
|-----------|-------|-------|
| Protocol fee | 250 bps (2.5%) | Configurable by admin. Deducted FIRST from total pool (both sides combined). |
| Host commission (Rail B) | Set per pool by host (e.g., 500 bps = 5%) | Only paid on YES wins. Deducted SECOND from the YES pool after protocol fee. |
| Fee on DRAW | Yes (players chose to play) | Split from both sides equally |
| Fee on INVALID | No | Not players' fault |
| Fee on VOIDED | No | Timeout or cancellation |
| Treasury address | Configurable | Set on deployment, changeable by admin |

**Fee deduction order (CloutPool):** 1) `protocolFee = (totalYes + totalNo) * feeBps / 10000` → sent to treasury. 2) If YES wins: `hostCommission = (totalYes - protocolFeeShareFromYes) * hostBps / 10000` → sent to host. 3) Remaining losing pool distributed proportionally to winners. 4) Winners also receive their original stake back. 5) Last claimer absorbs any rounding dust.

**Fee deduction (CloutEscrow):** `protocolFee = (2 * stake) * feeBps / 10000` → sent to treasury. Remainder goes to winner (or split 50/50 for DRAW). No host commission on PvP.

---

## Testing Strategy

| Category | Target | Notes |
|----------|--------|-------|
| CloutEscrow unit tests | 15+ | All state transitions, timeouts, payouts |
| CloutPool unit tests | 10+ | Pool lifecycle, caps, commission, dispute |
| Integration tests | 2+ | Full lifecycle per rail with MockStablecoin |
| Edge cases | 5+ | Double claim, wrong state, unauthorized caller |
| Invariant checks | Key 14 | Solvency, state consistency, payout correctness |

---

## Stablecoin Configuration

| Network | Token | Address | Decimals |
|---------|-------|---------|----------|
| Base Sepolia (testnet) | MockStablecoin | To be deployed | 6 |
| Base mainnet | USDT | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | 6 |
| Base mainnet | USDC | `0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA` | 6 |

Contract accepts any whitelisted `IERC20` — token address is a parameter per challenge/pool.

---

## Risk Matrix

| Risk | Prob | Impact | Mitigation | Day |
|------|------|--------|------------|-----|
| CloutEscrow takes longer than 4 days | MED | HIGH | Cut CloutPool (Gate 1 fallback). PvP escrow alone is a valid submission. | 1-4 |
| Frontend slips past Day 8 | HIGH | MED | Record Foundry script demo as backup. Contract interactions prove the MVP works. | 7-8 |
| Base Sepolia deployment issues | LOW | MED | Budget 2h for debugging. Foundry forge script is reliable. | 6 |
| Timeout logic has edge cases | MED | HIGH | Test every timeout path explicitly. Each one is a separate test. | 3-4 |
| Appeal chain creates reentrancy risk | LOW | HIGH | ReentrancyGuard on all external calls. No ETH transfers — ERC-20 only. | 3 |
| MockStablecoin doesn't behave like real USDT | LOW | LOW | 6 decimals, standard ERC-20. Good enough for demo. | 1 |

---

## Post-MVP Roadmap (Not In Scope)

These are scoped in RESEARCH.md but explicitly deferred:

| Feature | When | RESEARCH.md Ref |
|---------|------|-----------------|
| Real USDT + USDC on mainnet | Post-competition | §7 |
| Conviction Score on-chain (soulbound) | v2 | §7 |
| Game API auto-resolution | v2 per-game | §8, §10 |
| x402 agent convenience layer | v2 | §9 |
| Commit-reveal voting for disputes | v2 | §10 |
| UMA OOv3 integration | v3 | §10 |
| Open Markets (Rail C, CTF-based) | v2 | §6 |
| Leaderboard, profiles, social features | v2 | §6 |
| Mobile optimization | v2 | §6 |
| OpenZeppelin AccessControl with roles | Post-competition | §7 |

---

## Nightcrawler Notes

This plan is structured for Nightcrawler consumption:
- **Tasks are derived from the day-by-day breakdown** → see TASK_QUEUE.md
- **Acceptance criteria** come from the gate pass criteria
- **Dependencies** follow the dependency graph
- **Constraints** come from the simplifications table and invariants
- **"What to cut" decisions** are pre-made in the gate fallbacks — Nightcrawler should escalate via WhatsApp if a gate is at risk, not make cut decisions autonomously

**Carlos's game (demo context — GLOBAL_PLAN OVERRIDES RESEARCH.md §8 for Stage 2 scope):** RESEARCH.md §8 lists Carlos's game integration as Priority 1 for pilot demo. For Stage 2, this is **narrative-only, not a technical integration**. The contract is game-agnostic — `gameId` is just a bytes32 label. No contract, frontend, or API work is needed for game-specific integration in MVP. The demo will use Carlos's game as the narrative context (what match is being wagered on). Nightcrawler must NOT attempt to implement game API integration even though RESEARCH.md lists it as in-scope. If Mateo decides real integration is needed, he will add a task manually.

**Rules for Nightcrawler on this project:**
1. Never modify GLOBAL_PLAN.md or RESEARCH.md
2. Follow Foundry conventions (forge test, forge build, forge script)
3. Use OpenZeppelin imports from `@openzeppelin/contracts/`
4. All Solidity files use `pragma solidity ^0.8.20;`
5. All amounts are in 6-decimal token units (not 18)
6. ReentrancyGuard on every external function that transfers tokens
7. Every state transition emits an event
8. Every timeout uses `block.timestamp` comparison
9. Tests use Foundry's `vm.warp()` for timeout testing, `vm.prank()` for caller spoofing
10. Commit messages: `[nightcrawler] <type>: <description>` format per SPEC.md §7.3

---

_Clout — 9-day MVP plan for internal review. PvP escrow + challenge pools on Base Sepolia._
_Derived from RESEARCH.md + Daebak Markets plan structure._
