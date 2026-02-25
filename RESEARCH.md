# Clout — Research & Strategic Specification

> The conviction market for the creator economy. Gaming is the wedge.

**Last updated**: February 22, 2026 (fact-checked, audited, philosophically stress-tested)
**Competition**: Avalanche Build Games ($1M prize pool)
**Domain**: clout.ac
**Chain**: Avalanche C-Chain

---

## Table of Contents

1. [What Is Clout](#1-what-is-clout)
2. [The Thesis](#2-the-thesis)
3. [Market Research](#3-market-research)
4. [Competitive Landscape](#4-competitive-landscape)
5. [Target User](#5-target-user)
6. [Product Architecture](#6-product-architecture)
7. [Smart Contract Architecture](#7-smart-contract-architecture)
8. [Game API Integration](#8-game-api-integration)
9. [Agent Compatibility](#9-agent-compatibility)
10. [Resolution Strategy](#10-resolution-strategy)
11. [Risk Register](#11-risk-register)
12. [Build Games Timeline](#12-build-games-timeline)
13. [Pitch Strategy](#13-pitch-strategy)
14. [Intellectual Lineage](#14-intellectual-lineage)
15. [Key Data Points](#15-key-data-points)
16. [Sources](#16-sources)

---

## 1. What Is Clout

**One sentence**: Clout is the first conviction market — a protocol where creators stake claims, audiences stake conviction, and outcomes settle via on-chain escrow.

**What it's NOT**:
- Not a prediction market with a gaming skin
- Not Polymarket for esports
- Not a sportsbook
- Not a casino
- Not an "AI agent" project

**What it IS**:
- On-chain wagering for competitive gamers (PvP match stakes)
- A challenge pool platform (streamers create USDC stake pools for audiences)
- A conviction market primitive (your stakes are public, your track record is permanent, your reputation is earned)
- Agent-compatible infrastructure (any wallet — human or AI — can interact with the contract natively; x402 is an optional convenience layer)

**The trojan horse**: Gaming-focused wagering on the surface. The first conviction market underneath.

---

## 2. The Thesis

### The Gap
Gamers wager billions through trust-based channels: Discord middlemen, skin gambling sites, play-money Twitch predictions, and off-chain platforms like CheckMate Gaming ($211M+ paid out). None of this settles on-chain. None of it builds verifiable reputation. Almost none of it monetizes creators — Duelmasters.io is the closest (7.5% streamer commission), but it's early-stage and lacks robust settlement.

Meanwhile, Avalanche has one of the largest Web3 gaming ecosystems but zero prediction/wagering infrastructure.

### The Insight
Prediction market UX applied to gaming topics doesn't work (Forkast: near-zero traction, token failed). But PvP wager match platforms DO work (CheckMate Gaming: $211M+, 16M+ matches). The difference: gamers want to stake on themselves and their matches, not spectate binary YES/NO markets.

### The Bigger Picture
The core primitive — "creator asserts a claim, audience stakes on the outcome, escrow settles on-chain" — is niche-agnostic. Gaming is the wedge because behavior is proven and verification is solvable. But the protocol works for any creator with conviction and any audience with an opinion.

### Conviction Markets
The term "conviction market" exists in crypto — XO Market (Celestia, $500K pre-seed from Delphi/Cyber Fund, ~$101M alpha volume) and any.bid (B2B infrastructure) both use it. But both define it as a flavor of prediction market: permissionless market creation (XO) or no-exit engagement retention (any.bid). Neither includes identity, reputation, track records, or time-weighted commitment.

Clout's definition is structurally different:
- **Prediction market**: anonymous probability signal ("62% chance X happens")
- **XO/any.bid "conviction market"**: permissionless prediction market with engagement mechanics
- **Clout conviction market**: public, identity-linked, time-committed stake ("I believe X so strongly I'm locking $100 with my name on it — and that record is permanent")

The signal isn't just probability or even willingness to bet. It's strength + duration + identity + public nature of commitment. Your track record becomes your reputation. No existing platform combines all of: identity-linked stakes, time-weighted scoring, permanent on-chain record, and permissionless participation.

---

## 3. Market Research

### Demand Signals

| Signal | Data | Source |
|--------|------|--------|
| Esports betting market | $2.8B (2025), projected $14B+ by 2030 | TheXboxHub, GlobalNewsWire |
| CheckMate Gaming PvP payouts | $211M+, 16M+ matches played | CMG homepage |
| CS2 skin gambling economy | ~$5B (hit $6B+ Oct 2025, crashed, recovered to ~$5.5B Nov 2025) | Skin.Club, TalkEsport |
| Stake.com monthly deposits | $1.1B (centralized) | BlockchainMagazine |
| Polymarket esports volume | ~$9M out of ~$13B (2025) = ~0.07% | Polymarket, Paradigm (notes double-counting in raw data) |
| On-chain esports wagering (all platforms) | <$50M total | Estimate based on SX Bet, Azuro, WINR esports segments |
| Prediction markets on Avalanche | Zero | DappRadar |
| USDC on Avalanche | ~$604M native (was $784M Q3 2025) | usdc.cool (live, Feb 22 2026) |

### Streaming/Creator Economy

| Signal | Data | Source |
|--------|------|--------|
| Twitch MAU | 240M | DemandSage |
| Twitch DAU | 35M | DemandSage |
| Kick registered users | 57M (+131% YoY) | StreamsCharts |
| YouTube Gaming hours watched | 8.8B (2025, best year) | StreamsCharts |
| Twitch streamers making $0 | 72.6% | PlayerCounter |
| Channel Points predictions | Native on Twitch/Kick, play money only | Twitch |
| Gen-Z who see gaming as main social space | 58% | SQ Magazine |
| Gen-Z who view betting as social activity | 67% | TransUnion |
| Gen-Z crypto ownership | 51% | Gemini |

### Key Behavioral Insight
Twitch Channel Points Predictions prove the behavior: viewers love wagering on stream outcomes ("Will the streamer beat this boss?"). Engagement spikes 30-45% during prediction windows. But it's play money. The monetization is missing.

### Duelmasters.io Validation
Already live. Real-money crypto predictions on streamer outcomes. Streamers earn 7.5% commission. Integrated with Twitch/Kick. Validates the exact concept. But early stage, small, no robust dispute mechanism.

---

## 4. Competitive Landscape

### Direct Competitors

| Competitor | What they do | Volume | Why they're not us |
|------------|-------------|--------|-------------------|
| **Stake.com** | Dominant crypto sportsbook | $1.1B/month deposits | Centralized, custodial, no PvP stakes, no creator tools |
| **SX Bet** | Largest on-chain sports exchange | $780M+ all-time | Trader UX, esports is afterthought, Arbitrum/Bera |
| **Azuro** | Infra/liquidity layer for betting | $370M+ volume | Sports-focused, blocks esports parlays, no PvP |
| **WINR** | Casino bankroll-as-a-service | $250M+ | Casino games, not competitive esports |
| **Polymarket** | Dominant prediction market | ~$13B (2025, adjusted for double-counting) | Esports ~0.07%, binary YES/NO doesn't fit gaming |
| **Forkast** | Gaming prediction market | Near zero | Token collapsed, chain-hopped Ronin→Arbitrum, no traction |
| **Duelmasters.io** | Streamer real-money predictions | Early stage | No robust dispute mechanism, small, validates concept |
| **CheckMate Gaming** | PvP cash matches | $211M+ paid out | Centralized, off-chain, trust-based middlemen |
| **XO Market** | "Conviction markets" (permissionless prediction) | ~$101M alpha volume | No identity/reputation. "Conviction" = open market creation, not track records. Celestia rollup. |
| **any.bid** | White-label conviction market infra | Pre-revenue B2B | No identity features. "Conviction" = no exit button (retention play). Not user-facing. |

### Positioning
Forkast proves "prediction market UX on gaming topics" doesn't work. CheckMate Gaming proves "PvP match stakes" does. Duelmasters proves "challenge pools for audiences" have demand. Nobody combines all three with on-chain settlement, verifiable reputation, and agent compatibility.

### Whitespace
No competitor offers more than 2 of these 5 elements together:
1. Deep gaming-native market types (PvP + challenge pools)
2. Gamer-native UX (not finance/trading UX)
3. Decentralized self-custody
4. Social/competitive features (leaderboards, reputation, squads)
5. Agent compatibility (x402, Coinbase Agentic Wallets)

---

## 5. Target User

### Primary: Competitive Gamers Who Already Wager
- Play CS2, Valorant, LoL, Fortnite, fighting games
- Already wager through Discord, CMG, or informally
- Pain: friends don't pay, disputed outcomes, no accountability
- Crypto-comfortable (51% of Gen-Z own crypto)
- 18-25 years old

### Secondary: Gaming Streamers/Creators
- Twitch/Kick/YouTube streamers with engaged audiences
- Pain: 72.6% make $0, need new monetization tools
- Channel Points prove audience engagement with wagering mechanics
- Creator challenge = new revenue stream (commission on pools)

### Tertiary: AI Agents
- Agents with Coinbase Agentic Wallets
- Can create challenges, stake, submit evidence, resolve
- Agent-vs-human and agent-vs-agent wagering
- x402 payment protocol for frictionless interaction

### User Acquisition Strategy
1. Start with existing wager communities (Discord servers, CMG users)
2. Challenge link sharing = zero-friction viral loop
3. Creator adoption = built-in distribution (each streamer brings their audience)
4. Agent compatibility = automated volume and liquidity

---

## 6. Product Architecture

### Three Rails

| Rail | What | Users | When |
|------|------|-------|------|
| **Rail A: PvP Escrow** | Head-to-head match stakes | Player vs player (or player vs agent) | MVP (Build Games) |
| **Rail B: Challenge Pools** | 1-to-many stake pools | Host + audience | MVP-lite (Build Games) |
| **Rail C: Open Markets** | CTF-based tournament/event markets | Spectators | v2 |

### Rail A: PvP Escrow (MVP)

**Flow**:
1. Player A creates challenge (game, match type, stake amount in USDC, optional designated resolver)
2. Player B accepts challenge (locks matching USDC)
3. Both play the match off-chain
4. Either party submits result on-chain (CREATOR_WIN, OPPONENT_WIN, DRAW)
5. Counterparty confirms (instant settlement), disputes (goes to resolver/admin), or does nothing for 24h (submitted result auto-accepts)
6. Winner claims pot (minus protocol fee). DRAW splits 50/50 minus fee. INVALID/VOIDED refunds both.

**State Machine**:
```
CREATED ──→ ACCEPTED ──→ SUBMITTED ──→ FINALIZED (mutual agreement)
  ↓ 48h       ↓ 48h         ↓ dispute
VOIDED      VOIDED      DISPUTED ──→ RESOLVED (resolver/admin decides)
                           ↓ 24h no action    ↓ 24h appeal window
                     FINALIZED (auto-accept)  FINALIZED (no appeal)
                                               ↓ appeal filed
                                             admin reviews → FINALIZED
                                               ↓ admin timeout (48h)
                                             VOIDED
```

**Submit/confirm flow**: One party submits an outcome. The other has 24h to confirm (same outcome = instant settlement) or dispute. Only the non-submitting party can dispute — prevents contradictory submissions. **If the counterparty does nothing for 24h, the submitted result auto-accepts.** This prevents grief-to-refund attacks where a losing player refuses to confirm/dispute to force a void.

**Appeal flow**: After a resolver decision (DISPUTED → RESOLVED), either player has 24h to appeal to admin. If no appeal within 24h, the resolver's decision auto-finalizes. If appealed, admin has 48h to review and decide — their decision is final. This prevents resolver collusion from being uncontestable.

### Rail B: Challenge Pools (MVP-Lite)

**Flow (MVP-lite constraints)**:
1. Host creates YES/NO challenge pool with fixed close time, event window (`eventStart`, `eventEnd`, `resolveBy`), and designated resolver
2. Audience stakes YES or NO into the pool (per-wallet cap, total pool cap)
3. Staking closes at `eventStart`
4. Host attempts challenge (on stream, in game, etc.)
5. Designated resolver submits result (YES or NO) — **host cannot be their own resolver** (conflict of interest, enforced on-chain)
6. 24h dispute window: if >20% of losing-side stakers flag dispute → admin review
7. Winners split losing pool. Host takes commission from winning pool. Protocol takes fee.

**State Machine**:
```
OPEN ──(eventStart)──→ CLOSED ──(resolver submits)──→ SUBMITTED
  ↓ (no stakers by eventStart)      ↓ (resolveBy timeout)       ↓ confirm (24h no dispute)
VOIDED                              VOIDED                    FINALIZED
                                                               ↓ dispute threshold met
                                                             DISPUTED → admin resolves → FINALIZED
                                                               ↓ timeout
                                                             VOIDED
```

**Who can dispute in Rail B?** Any staker on the losing side can flag a dispute. To prevent frivolous disputes from freezing the pool, a **threshold** is required: >20% of losing-side stakers (by count, not by stake) must flag within 24h. Below threshold → result stands.

**Host conflict of interest**: The host creates the challenge AND participates in the outcome. To prevent self-dealing:
- Host **cannot** be the designated resolver for their own pool
- Host **must** stake on the YES side (skin in the game — they're betting they can do it)
- A separate trusted resolver (co-host, moderator, community figure) submits the result

**Payout logic (Rail B)**:

| Outcome | YES Stakers | NO Stakers | Host Commission | Protocol Fee |
|---------|-------------|-----------|----------------|-------------|
| YES wins | Split NO pool proportionally | 0 | % of winning pool | % of total pool |
| NO wins | 0 | Split YES pool proportionally | 0 (host lost) | % of total pool |
| INVALID | Full refund | Full refund | No commission | No fee |
| VOIDED | Full refund | Full refund | No commission | No fee |

**Host commission**: Only paid when the challenge succeeds (YES wins). This aligns incentives — the host earns commission by actually completing the challenge, not by manipulating the result.

**Scope guard for March 9**:
- No AMM/odds engine — payout is proportional split of losing pool
- No open market discovery — pools are shared via link
- No algorithmic resolution — designated resolver + admin fallback
- One pool type (YES/NO), one clear payout rule
- Per-wallet cap and total pool cap prevent whale manipulation
- Event constraints are validation-only (manual evidence + manual settlement), not oracle automation

### Rail C: Open Markets (v2)
- Gnosis CTF (needs deployment on Avalanche)
- Tournament brackets, esports event outcomes
- LMSR or simple AMM for pricing
- Deferred to post-Build Games

**Rail C philosophy alignment (non-negotiable)**:
- Identity-linked participation stays visible (wallet continuity, public history)
- UI prioritizes calibration and track record, not just price/odds
- Time-at-risk is explicit (holding duration/commitment shown, not just entry price)
- Avoid pure anonymous trading UX; Rail C is an extension layer, not the product identity

### Wedge Expansion
Each vertical is a wedge using the same protocol:
- Gaming (Build Games MVP)
- Finance/Crypto (CT predictions, Chainlink-resolvable)
- Creator milestones ("This video hits 1M views")
- Future verticals as verification matures

---

## 7. Smart Contract Architecture

### Reusable Patterns (From Previous Work)

The team has prior experience building prediction market protocols on EVM. Key battle-tested patterns that carry over to Clout:

- **Lifecycle state machine**: Multi-state challenge lifecycle with timeout/void safety paths
- **Commit-reveal voting**: Two-phase dispute resolution (commit hash → reveal vote). Alternative to UMA for v2.
- **Central storage pattern**: Well-typed structs for challenges, stakes, users, fees
- **Role-based access control**: Lightweight RBAC without heavy OpenZeppelin AccessControl
- **Fee distribution**: Protocol fee routing on settlement
- **Oracle adapter pattern**: Pluggable resolution adapters per data source
- **Formal invariants**: Protocol correctness properties (solvency, state consistency)
- **Pre-deploy checklist**: 40+ items before mainnet deployment

### Contract Architecture (Clout v1 MVP)

MVP uses minimal, purpose-built contracts — no proxy, no facets, no upgradeability complexity:
- **`CloutEscrow.sol`** (~500-600 lines): Rail A PvP escrow — challenges, stakes, resolution, payouts
- **`CloutPool.sol`** (~300-400 lines): Rail B challenge pools — pooled stakes, host commission, resolver flow

Two contracts because the mechanics differ: escrow is 1v1 symmetric, pools are 1-to-many asymmetric. Both share the same stablecoin integration, admin roles, and fee routing.

**Dependencies**: OpenZeppelin `IERC20`, `ReentrancyGuard`, `Ownable`.
**Supported stablecoins** (both natively issued on Avalanche, both 6 decimals):
- **USDT**: `0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7` (native, 6 decimals). No EIP-2612 permit() on legacy contract. Tether is a Build Games partner (mentor: Raquel Raigal). Tether WDK provides wallet infrastructure.
- **USDC**: `0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E` (native, 6 decimals). Supports EIP-2612 `permit()`. Higher DeFi liquidity on Avalanche (~$572M).
- Fuji testnet: Deploy mock ERC-20 with 6 decimals (`MockStablecoin.sol`). MVP develops against Fuji.
- Contract accepts any `IERC20` address — stablecoin is a parameter, not hardcoded.

**Core functions**:

| Function | Purpose |
|----------|---------|
| `createChallenge(opponent, stakeAmount, token, gameId, designatedResolver)` | Creator sets game, stake, stablecoin, optional resolver, locks funds |
| `acceptChallenge(challengeId)` | Opponent locks matching USDC. State → ACCEPTED |
| `submitResult(challengeId, outcome)` | Either party submits outcome. State → SUBMITTED. Starts 24h confirmation window |
| `confirmResult(challengeId)` | Counterparty confirms same outcome → State → FINALIZED (mutual agreement) |
| `disputeResult(challengeId)` | Counterparty disagrees → State → DISPUTED. Only callable by party who did NOT submit |
| `resolveDispute(challengeId, outcome)` | Designated resolver or admin submits decision. State → RESOLVED. Starts 24h appeal window |
| `appealResolution(challengeId)` | Either player appeals resolver decision within 24h. Escalates to admin |
| `finalizeResolution(challengeId)` | Admin finalizes after appeal, or anyone calls after 24h appeal window expires with no appeal |
| `claimWinnings(challengeId)` | Winner withdraws pot minus protocol fee |
| `voidChallenge(challengeId)` | Refund both sides (timeout, cancellation). Callable after relevant timeout expires |

**State machine**:
```
CREATED ──(acceptChallenge)──→ ACCEPTED ──(submitResult)──→ SUBMITTED
   ↓ (48h timeout)                ↓ (48h timeout)              ↓
  VOIDED                        VOIDED                    confirmResult() → FINALIZED
                                                          disputeResult() → DISPUTED
                                                          24h timeout     → FINALIZED (auto-accept)
                                                               ↓
                                                          resolveDispute() → RESOLVED
                                                          48h resolver timeout → admin fallback → RESOLVED
                                                               ↓
                                                          24h no appeal → FINALIZED
                                                          appealResolution() → admin reviews → FINALIZED
                                                          48h admin timeout → VOIDED
```

**Note**: No explicit PLAYING state in the contract. The match happens off-chain between ACCEPTED and SUBMITTED. The contract only tracks escrow state — it doesn't know when the game starts or ends. Either party calls `submitResult()` when the match is done.

**Storage structs**:
```solidity
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

enum ChallengeState { CREATED, ACCEPTED, SUBMITTED, DISPUTED, RESOLVED, FINALIZED, VOIDED }
enum Outcome { NONE, CREATOR_WIN, OPPONENT_WIN, DRAW, INVALID }
```

### Key Design Decisions
- **Minimal contracts, not Diamond proxy**: Two purpose-built contracts (CloutEscrow ~500-600 lines, CloutPool ~300-400 lines). No proxy complexity. Ship fast.
- **Stablecoins only (USDT + USDC)**: No governance token, no volatile collateral. Token address is a parameter per challenge — contract accepts any whitelisted IERC20. Tether WDK integration for wallet layer.
- **Submit → confirm/dispute flow**: One party submits the outcome, the other confirms or disputes. Only the non-submitting party can dispute. This prevents both parties submitting contradictory results.
- **Manual settlement + designated resolver v1**: Mutual agreement primary, optional third-party resolver, admin fallback (fast to ship, flexible)
- **Commit-reveal v2**: Community voting for decentralized dispute resolution
- **UMA OOv3 v3**: Optional integration when Avalanche support matures
- **No governance token**: No DAO, no voting token, no DeFi complexity
- **No PLAYING state in contract**: Match happens off-chain. Contract tracks escrow state only (ACCEPTED → SUBMITTED).

### Conviction Score v1 (On-Chain Reputation Primitive)

The philosophical claims in Section 14 (track record > stake size, time as Sybil-resistant resource) require a protocol-level mechanism. This is the minimal falsifiable spec.

**What the contract stores per wallet** (added to `CloutEscrow.sol`):

```solidity
struct WalletRecord {
    uint256 challengesEntered;     // incremented on both create and accept
    uint256 challengesCompleted;   // finalized (win or loss)
    uint256 challengesWon;
    uint256 challengesDisputed;
    uint256 totalStaked;           // cumulative USDC staked (6 decimals)
    uint256 firstChallengeAt;      // timestamp of first completed challenge
    uint256 lastChallengeAt;       // timestamp of most recent challenge
}

mapping(address => WalletRecord) public walletRecords;
```

**How it works in v1** (read-only, no gating):
- Every `claimWinnings()` and `voidChallenge()` call updates the wallet's record
- The data is public and queryable — any frontend or agent can compute scores
- v1 does NOT gate access based on score (permissionless entry)
- v1 DOES expose the data for frontends to display trust signals

**Conviction Score formula (off-chain, displayed by frontend)**:
```
score = (challengesCompleted / max(1, challengesEntered))
      × log2(1 + daysSinceFirstChallenge)
      × (challengesWon / max(1, challengesCompleted))
      × log10(1 + totalStaked / 1e6)
```

Four components:
1. **Completion rate**: `completed / entered` — bounded [0, 1]. Penalizes wallets that enter but don't finish (spam/testing/abandonment)
2. **Time depth**: `log2(days)` — you can't fake 6 months of history. This is the core Sybil defense.
3. **Win rate**: Track record calibration signal
4. **Stake volume (log-scaled)**: `log10(1 + totalStaked / 1e6)` — normalized to USDC units (6 decimals), prevents grind-farming via cheap micro-stakes. Log compression means 10x more volume adds ~1 unit to this component, preventing wealth from dominating the score.

**Known grind-gaming vector**: Two colluding wallets can alternate wins on low stakes to farm completion/win-rate. The stake volume component raises the floor cost of this attack, but doesn't eliminate it. v2 adds opponent quality weighting (your score improves more by beating high-score opponents) and anomaly detection (flagging wallet pairs with abnormal mutual-challenge frequency).

**What this closes**:
- The Section 14 claim "500 accurate $20 stakes carry more conviction weight than one $1B stake" is now computable, not just narrative
- The claim about identity cost is grounded in `firstChallengeAt` — a fresh wallet has zero time depth, making rotation transparent (though not prevented; see Sybil Resistance section below)
- Track record weighting and time-based Sybil resistance are now on-chain primitives, not just philosophical positions

**v2 expansion** (post-MVP):
- Gated features: minimum score to create high-stake challenges
- Social graph: optional linked Discord/game IDs stored off-chain, verified via signed message
- Conviction Score as ERC-721 soulbound token (portable reputation)

**Kill criterion for Conviction Score**: See Kill Criteria section (Gini coefficient < 0.3 after 500 resolved challenges).

### Sybil Resistance in v1

**Honest assessment**: MVP has limited Sybil resistance. What exists:

| Defense | Mechanism | Strength |
|---------|-----------|----------|
| **Time depth** | `firstChallengeAt` in WalletRecord — fresh wallets have zero history | Strong (time is unfakeable) |
| **Completion rate** | Incomplete challenges count against you | Medium (friction to farm) |
| **Stake-to-create** | Creating a challenge requires locking USDC | Medium (costs real money) |
| **Public history** | All challenges are on-chain and queryable | Medium (manipulation is visible) |
| **Admin review** | Disputed challenges go through human review in v1 | Weak but functional |

**What v1 does NOT have** (explicitly scoped out):
- No linked identity proofs (Discord/game accounts) — deferred to v2
- No social graph analysis — deferred to v2
- No score-based access gating — v1 is permissionless
- No on-chain cluster detection — deferred to v2

**The honest framing**: In v1, a determined attacker CAN create fresh wallets to escape reputation. The defense is that fresh wallets have zero conviction score (time depth = 0), and the frontend surfaces this. It's transparent, not prevented. Prevention requires the v2 identity layer.

---

## 8. Game Integration & Publisher ToS Compliance

### Publisher ToS Reality

Game publisher Terms of Service constrain which games can be supported and how. This is a structural constraint, not a blocker — CMG has processed $211M+ by operating within these boundaries.

**Key findings (Feb 2026):**

| Game | Wagering in ToS | Blockchain Ban | API for Wagering | Enforcement | Risk |
|------|----------------|---------------|-----------------|-------------|------|
| **Off The Grid** | Game IS blockchain. Cash tournaments (paused). | NO — Avalanche subnet | No public API. No match data on-chain. | None | **LOW** (ToS) / **HIGH** (integration — battle royale, not 1v1) |
| **CS2** | Steam ToS prohibits gambling | Not explicit | Limited API | 40+ C&D letters (skin gambling, not cash) | MODERATE |
| **League of Legends** | Not explicit in player ToS | **YES — absolute** ("no crypto/blockchain/NFTs whatsoever") | **Prohibited** for gambling | No action on external platforms yet | HIGH |
| **Valorant** | Same as LoL | **YES — same policy** | **Prohibited** | Same as LoL | HIGH |
| **Fortnite** | **Explicit ban** (Community Rules + Dev Rules 1.11) | Not explicit | No public API | **Player bans + platform shutdowns** | VERY HIGH |

### Critical Riot Developer API Policy (Affects LoL + Valorant)

Riot's developer portal contains two independent blockers:
1. *"Your product cannot feature betting or gambling functionality."*
2. *"No cryptocurrencies, blockchain, or NFTs whatsoever. Even if these elements only apply to non-Riot games on a third party platform, we still don't allow our IP or data to be associated with this space."*

**Implication**: Clout cannot use the Riot API for match verification. Period. Both the gambling prohibition and the blockchain prohibition independently block it.

### How CMG Operates Without Publisher Licenses

CMG has no disclosed publisher partnerships. They operate by:
1. Framing as "skill-based competition with entry fees" (not "wagering")
2. Using manual screenshot dispute resolution — **never touching publisher APIs**
3. Operating entirely outside the game ecosystem
4. Excluding 7 US states: Arizona, Hawaii, Iowa, Mississippi, Montana, Nevada, South Dakota
5. 18+ hard gate

This is the proven model for non-blockchain-native games.

### Off The Grid: Why It's Not a Launch Title

Off The Grid is the most prominent Avalanche-native game, but it's **incompatible with Clout's PvP escrow design**:
- **Battle royale** (150 players, 3-player squads) — not head-to-head 1v1
- **No public API** for match data or results. GUNZ blockchain tracks NFT/asset extraction, not match outcomes.
- **"Clash for Cash" paused** since April 10, 2025 — leaderboard tournament, not PvP escrow
- **Player count declining**: ~7,300 concurrent Steam (52% drop from Dec 2025 peak)

OTG remains valid **ecosystem evidence** (proves Avalanche has gaming) but is not a game Clout can launch on. Would require a custom matching layer for squad-based challenges — months of work, not weeks.

### Game Priority (Updated)

The protocol is **game-agnostic** — the smart contract is just escrow. It doesn't know or care what game is being played. Any 1v1 competitive game works with manual resolution.

| Priority | Game | Why | Resolution Model |
|----------|------|-----|-----------------|
| 1 | **Carlos's game** | Custom game for same hackathon, can provide direct API. Ideal for demo. | Custom API integration |
| 2 | **Any 1v1 PvP game** | Protocol is game-agnostic. Manual resolution works for any game. | Manual (CMG model) |
| 3 | **Dota 2** | OpenDota API (community-run), Valve doesn't restrict 3P wagering | Manual v1, API v2 (lower ToS risk) |
| 4 | **CS2 (via FACEIT)** | FACEIT Data API, moderate ToS risk for cash-based | Manual v1, FACEIT API v2 (moderate risk) |
| 5 | **League of Legends** | Largest esports audience, proven demand (CMG model) | Manual only. **Riot API permanently blocked.** |

### Verification Flow (v1 MVP)
```
Players complete match → Both submit result manually →
Mutual agreement = instant settlement → Disputed = admin review
```

For v1 MVP: **Manual submission + mutual agreement** is the primary path. This is both the fastest to ship AND the legally safest approach — it avoids publisher API policies entirely.

### Game API Auto-Resolution (v2+, Per-Game)

API-based auto-resolution is a v2 enhancement that works **only for games where the publisher permits it**:
- **Custom/partner games** (Carlos's game, future blockchain-native titles): Direct API integration
- **Open API games** (Dota 2 via OpenDota): Lower risk, community-run API
- **Riot/Epic games**: **Blocked by developer policy.** Manual resolution only, indefinitely.

```
Match completes → Game API returns result → Keeper submits on-chain →
Challenge window (if disputed) → Settlement
```

### Multi-Game Aggregation APIs
- **GRID Esports**: Best for betting use cases, official publisher partnerships
- **PandaScore**: 13+ titles but explicitly prohibits betting on standard plans
- **Abios**: 60K+ matches/year, REST + Push APIs

### Legal Framework: "Skill-Based Competition" vs "Gambling"

Gambling requires three elements: (1) prize, (2) consideration (paid entry), (3) chance. Removing element (3) — because competitive gaming outcomes are determined by skill — exempts the activity under most state laws.

States use different tests:
- **Predominance Test** (majority of states): Is skill the dominant factor?
- **Material Element Test** (~8 states): Does chance play a material role?
- **Any Chance Test** (strictest): Does chance play ANY role?

Clout's PvP escrow is pure skill-based competition. Challenge Pools with audience predictions are closer to the edge and require legal counsel before mainnet.

---

## 9. Agent Compatibility

### Why: Be the arena, not the player
Don't build AI agents. Be the platform agents consume. 76% of AI agent deployments fail. The AI agent token meta peaked at $20B market cap and has been volatile since (ranging $4-12B through early 2026). But the infrastructure is real.

### What Happened (February 11, 2026)
Coinbase launched **Agentic Wallets** — first wallet infrastructure built for AI agents. Agents can hold funds, send payments, trade tokens, transact on-chain. Spin up in 2 minutes via CLI. Built-in spending limits, session caps, key isolation.

### x402 Protocol
HTTP payment protocol by Coinbase. Activates the dormant HTTP 402 "Payment Required" status code. 75M transactions, $24M processed. Co-founded x402 Foundation with Cloudflare.

**How it works**: Agent sends HTTP request → Server returns 402 + payment terms → Agent sends signed USDC payment in header → Server verifies → Returns resource.

### Clout + Agents

| What we build | Cost | What agents can do |
|---------------|------|-------------------|
| REST API for challenges | Needed anyway | Discover, create, accept challenges |
| x402 payment header support | ~1-3 days (depends on Avalanche facilitator support) | Pay to stake autonomously |
| Public resolution endpoint | Minimal | Submit resolution evidence |

### Three-Way Arena
```
Human vs Human    → PvP Escrow (standard)
Human vs Agent    → Same escrow, agent has Coinbase wallet
Agent vs Agent    → Same escrow, both sides are agents
```

The protocol doesn't care who's on either side. A wallet is a wallet. A stake is a stake.

**Important distinction**: The smart contract is inherently agent-compatible from day one — any wallet (human or AI) can call `createChallenge()`, `acceptChallenge()`, etc. No special integration is needed. x402 is a *convenience layer* that lets agents interact via HTTP headers instead of direct contract calls. It's deferred to post-MVP (see Section 12), but its absence doesn't block agent participation.

### Cultural Moment
Grok 5 vs T1 (League of Legends) is the most anticipated human-vs-AI gaming event of 2026. Elon challenged T1, Riot co-founder responded "Let's discuss." Agent-vs-human gaming wagering has zero existing platforms. Clear whitespace.

---

## 10. Resolution Strategy

### V1: Manual Settlement + Designated Resolver (Build Games MVP)

**Three resolution paths** (in order of priority):

| Path | When | Who Decides | Deadline |
|------|------|-------------|----------|
| **Path 1: Mutual agreement** | Both players confirm same result | Players themselves | Instant |
| **Path 2: Designated resolver** | Dispute triggered, resolver specified at challenge creation | Trusted third party (tournament organizer, streamer, community figure) | 48h to decide → 24h appeal window → FINALIZED |
| **Path 3: Admin fallback** | No resolver specified, resolver times out, or appeal filed | Clout team | 48h after dispute/appeal (decision is final, no further appeal) |

**Designated Resolver** (optional, ~80 lines of Solidity):
- Challenge creator specifies `address designatedResolver` when creating challenge (or leaves as zero = admin-only)
- Both players implicitly accept the resolver by accepting the challenge
- Resolver can submit `CREATOR_WIN`, `OPPONENT_WIN`, `DRAW`, or `INVALID`
- If resolver doesn't act within 48h → auto-fallback to Clout admin
- Unlocks tournament organizer and streamer use cases without decentralized governance

**Timeout Specifications**:

| State Transition | Timeout | What Happens |
|-----------------|---------|-------------|
| CREATED → not accepted | 48h | Creator can void, gets refund |
| ACCEPTED → no result submitted | 48h | Either party can void, both refunded |
| SUBMITTED → not confirmed or disputed | 24h | Submitted result auto-accepted (submitter wins by default) |
| DISPUTED → resolver doesn't act | 48h | Fallback to admin |
| DISPUTED → admin doesn't act (as fallback) | 48h after fallback | Auto-void, both refunded |
| RESOLVED → no appeal filed | 24h | Resolver decision auto-finalizes |
| RESOLVED → appeal filed, admin doesn't act | 48h after appeal | Auto-void, both refunded |

**Payout Logic**:

| Outcome | Winner Payout | Loser Payout | Protocol Fee |
|---------|--------------|-------------|-------------|
| CREATOR_WIN or OPPONENT_WIN | Full pot minus fee | 0 | Yes (from pot) |
| DRAW | 50% of pot minus fee | 50% of pot minus fee | Yes (players chose to play) |
| INVALID | Full refund | Full refund | No (not players' fault) |
| VOIDED (timeout) | Full refund | Full refund | No |

**Why this model**: Mutual agreement resolves 85%+ of PvP wagers (CMG data). Designated resolver adds flexibility for organized play. Admin fallback is the safety net. CMG has processed $211M+ with a simpler version of this. UMA OOv3 on Avalanche is "unmonitored" (multi-sig relay, not full DVM). This is honest and functional for testnet.

### Common Dispute Scenarios

| Scenario | Frequency | Resolution |
|----------|-----------|-----------|
| Both agree on outcome | 85%+ | Instant settlement (Path 1) |
| One claims win, other disagrees | ~10% | Resolver/admin reviews evidence (screenshots, match logs) |
| Player disconnects mid-match | 3-5% | Resolver/admin decides forfeit rules |
| One player never submits result | ~2% | Timeout → auto-void, both refunded |
| Server crash / match invalid | <1% | Resolver/admin marks INVALID, both refunded |
| Resolver colludes with one player | Rare | Public history shows pattern, admin appeal available |

### Collusion Mitigations

- **Resolver bias tracking**: On-chain `resolvedChallenges` mapping — anyone can query resolver history and detect anomalous win rates
- **Zero-sum defense**: Both players colluding is impossible (one wins, one loses). Collusion risk is resolver + one player vs. the other
- **Admin appeal**: After resolver decision (RESOLVED state), either player can call `appealResolution()` within 24h to escalate to admin. If no appeal, resolver decision auto-finalizes
- **Reputation cost**: Resolvers with high dispute rates or one-sided patterns get flagged in the frontend

### V2: Commit-Reveal Voting (Post-Build Games)
- Commit-reveal voting pattern
- Community of stakers vote on disputed outcomes
- Two-phase: commit hashed vote → reveal vote
- Winner determined by majority
- Bond/slashing for incorrect voters

### V3: UMA OOv3 Integration (If/When Avalanche Support Matures)
- UMA OOv3 deployed at `0xa4199d73ae206d49c966cF16c58436851f87d47F`
- Currently "unmonitored" on Avalanche
- Optimistic assertion → challenge window → DVM fallback
- Better for open markets (Rail C) than PvP escrow

### V4: Game API Auto-Resolution (Enhancement — Per-Game, ToS-Dependent)
- Keeper watches game API → submits result on-chain
- Challenge window for disputes
- Auto-finalize if no dispute within window
- Per-game adapter (ResolutionAdapter pattern)
- **Only available for games whose publisher ToS permits API use for wagering/competition platforms** — custom/partner games (Carlos's game) and open APIs (OpenDota) are viable. Riot/Epic APIs are blocked. See Section 8.

### Resolution Adapter Interface
```solidity
interface IResolutionAdapter {
    function source() external view returns (string memory);      // "otg-api"
    function fallbackSource() external view returns (string memory); // "manual"
    function canAutoResolve(bytes32 challengeId) external view returns (bool);
    function fetchResult(bytes32 challengeId) external returns (Outcome);
    function disputeWindow() external view returns (uint256);     // seconds
    function invalidPolicy() external view returns (string memory); // when to mark INVALID
}
```

---

## 11. Risk Register

### Kill Points

| # | Risk | Severity | Mitigation |
|---|------|----------|-----------|
| 1 | **Regulatory** — gaming + wagering + Gen-Z = legal magnet | Critical | 18+ hard gate with real verification. USDC-only (reduces but does not eliminate regulatory exposure — legal counsel required). "Skill-based wagering" framing. Geo-restrictions. Legal review before mainnet. |
| 2 | **Game publisher hostility** — C&Ds from Valve/Riot/Epic | High | **Riot/Epic**: API integration blocked by policy (gambling + blockchain bans). CMG-model only (manual resolution, no API, no game IP). **Valve**: Skin gambling enforced, cash-based less targeted. **Mitigation**: Protocol is game-agnostic — launch with Carlos's game (custom API) and manual resolution for any other game. Frame as "skill-based competition." See Section 8. |
| 3 | **Dispute volume overwhelms system** — UMA bonds exceed wager amounts for small stakes | High | Mutual agreement is primary path (no oracle needed). Manual fallback. Minimum wager threshold. Reputation system for repeat disputers. |
| 4 | **Abuse/collusion** — smurf accounts, match throwing, creator self-dealing | High | No volume-based rewards. Stake-to-create. Per-wallet caps. Public match history. Skill-based matchmaking. Identity signals (Discord/game ID). |
| 5 | **Nobody comes** — Forkast built gaming prediction market, got zero users | High | Ship INTO existing communities (Discord wager servers). Challenge link sharing = viral loop. Kill metric: 50 active wagers in week 1 or pivot. |
| 6 | **Build Games timeline** — 6 weeks, video due Feb 25 | High | PvP escrow is simple contract. Reuse proven patterns. ONE game, ONE contract, ONE flow for demo. |
| 7 | **Twitch/Kick TOS** — real-money wagering on stream violates TOS | Medium | Clout exists as independent app. Streamers link to it, viewers stake off-platform. Stream = viewing layer, not transaction layer. |
| 8 | **Streamer match-fixing** — intentional failure for friends on NO side | Medium | Public challenge history. Stake limits. Anomaly detection. Creator must lock own USDC too. UMA dispute path. |
| 9 | **Addiction backlash** — real money in entertainment = controversy | Medium | Loss limits. Cool-down periods. Transparent odds. Responsible gambling disclosures. Don't market to minor audiences. |
| 10 | **UMA unmonitored on Avalanche** — multi-sig relay, not full DVM | Medium | Use manual settlement for v1. Commit-reveal voting for v2. UMA integration when support matures. |
| 11 | **Designated resolver collusion** — resolver + one player steal from the other | Medium | Public on-chain resolver history (anyone can audit win rates). Admin appeal within 24h. Anomaly detection flags resolvers with >70% one-sided outcomes. Reputation cost. See Section 10. |

---

## 12. Build Games Timeline

| Stage | Date | Deliverable | What We Ship |
|-------|------|-------------|-------------|
| **Stage 1: Idea** | Feb 25 | 2-min video | Problem, solution, value prop, demo concept |
| **Stage 2: MVP** | Mar 9 | Working prototype + demo + code | PvP escrow + challenge pool (MVP-lite) on Avalanche Fuji, basic web app, one complete wager lifecycle per rail |
| **Stage 3: GTM & Vision** | Mar 19 | Go-to-market plan | Creator economy expansion, agent compatibility, wedge strategy |
| **Stage 4: Finals** | Mar 27 | Live showcase | End-to-end demo, community traction evidence |

### Judging Criteria
- **Builder Drive**: Energy, follow-through, ship in 6 weeks
- **Execution**: Actually delivering working product
- **Crypto Culture**: Authentically crypto-native
- **Long-Term Intent**: Genuine commitment to Avalanche

### MVP Scope (For Stage 2: March 9)
**In scope**:
- PvP Escrow contract (`CloutEscrow.sol`: create, accept, submit, confirm, dispute, resolve, appeal, claim)
- Designated resolver option (optional third-party resolver per challenge, ~80 lines)
- Timeout specifications (acceptance 48h, submission 48h, confirmation 24h, resolver 48h, admin 48h)
- Payout logic: DRAW (split minus fee), INVALID (full refund, no fee), VOIDED (full refund)
- Challenge Pools MVP-lite (YES/NO stake pool with fixed close time, event window constraints, capped participation, manual resolution)
- USDT + USDC collateral on Avalanche Fuji testnet (whitelisted stablecoins, token as parameter)
- Basic web app (duels + challenge pools: create, join, submit result, claim winnings)
- Manual dispute resolution + designated resolver fallback
- One complete lifecycle demo for each in-scope rail
- Carlos's game integration for pilot demo

**Out of scope** (defer to Stage 3+):
- Full Challenge Pools (uncapped pools, advanced discovery, automated resolution)
- CTF/Open Markets (Rail C)
- Game API auto-resolution
- x402 convenience layer (note: the contract itself is agent-compatible — any wallet can call it. x402 adds HTTP-native payment flow for agents that interact via REST, not a requirement for agent participation.)
- UMA OOv3 integration
- Mobile optimization

---

## 13. Pitch Strategy

### Evaluation Criteria (From Build Games)
- Clarity of idea
- Problem-solution fit
- Innovation
- Presentation quality
- Potential market impact

### 2-Minute Video Structure

One continuous story — not 5 slides. Causal transitions throughout. Face to camera + text overlays + one flow animation.

| Time | Beat | Content |
|------|------|---------|
| 0:00-0:15 | **Thesis (broad)** | "Every opinion online is free. You can call any outcome, predict any result, and if you're wrong — nothing happens." |
| 0:15-0:40 | **Narrow to gaming** | Discord trash talk, calls on stream, none on the record. $5B skin gambling economy, hundreds of millions in PvP wagers on Discord middlemen. No escrow, no accountability, no record. |
| 0:40-0:55 | **Product intro** | "So we built Clout — a conviction market." Stake USDC, public stakes, permanent track record, reputation over time. Match stakes, challenge pools, audience predictions — all on Avalanche. |
| 0:55-1:15 | **How it works** | *(Flow animation/mockup)* Create challenge → opponent accepts → lock USDC → play → submit result → winner claims pot. One contract, on-chain escrow. |
| 1:15-1:35 | **Why Avalanche** | One of the biggest gaming ecosystems in Web3 (OTG, MapleStory, Shrapnel) but no way to stake on outcomes. Sub-two-second finality, native USDC, any wallet (human or AI). "The infrastructure is ready. Nobody's built this layer." |
| 1:35-1:50 | **Expand back out** | "Gaming is where we start — because gamers already back their calls and outcomes are verifiable. But this works for any creator, any audience, any outcome worth staking on." |
| 1:50-2:00 | **Close (echoes opener)** | "Right now opinions are free and conviction is cheap. We're building the place where that changes." Logo + clout.ac. |

### Key Phrases to Plant
- "Conviction market" — introduced naturally as what we built, not a definition lecture
- "Every opinion online is free" — the thesis, stated as the open and echoed in the close
- "Gaming is where we start" — signals bigger thinking without scope creep
- "Any wallet, human or AI" — innovation signal, not a buzzword
- $5B skin economy — market-level data, no company names
- "Nobody's built this layer" — Avalanche whitespace

### What NOT to Do
- Don't say "prediction market" — judges lump you with Polymarket clones
- Don't stack TAM numbers — honest data only
- Don't lead with tech stack — lead with the insight
- Don't show five features — show one complete flow, polished
- Don't name specific companies — talk about the market
- No "That's [Product]" formula
- No "it's not X, it's Y" contrasts
- No bullet-point lists spoken aloud — everything connects causally

---

## 14. Intellectual Lineage

### The Evolution

```
Prediction Markets (Iowa, 1988)
  "What will happen?"
  → Financial incentives aggregate information
      ↓
Futarchy (Robin Hanson, 2000)
  "Vote on values, bet on beliefs"
  → Use markets to make governance decisions
  → MetaDAO on Solana (Paradigm-backed, used by Drift/Jito/Sanctum)
      ↓
Conviction Voting (Commons Stack, 2018)
  "Time-weighted commitment"
  → Stake + time = conviction signal
  → 1Hive Gardens, Giveth
      ↓
Information Finance (Vitalik Buterin, 2024)
  "Markets that produce information as primary output"
  → Subsumes prediction markets, futarchy under one umbrella
      ↓
Conviction Markets (XO Market 2024, any.bid 2025)
  "Permissionless prediction markets with engagement"
  → Open market creation, no exit button
  → No identity, no reputation, no track records
      ↓
Conviction Markets Redefined (Clout, 2026)
  "Financialized conviction as social signal"
  → Public stakes + track record + time commitment = reputation
  → Identity-linked, not anonymous
  → Creator-driven, not market-maker-driven
  → Agent-compatible, not human-only
```

### Key Distinction
- **Prediction markets** measure what the crowd thinks will happen
- **Conviction markets** measure how strongly individuals believe, for how long, and publicly

The difference is identity, time, and social context. A conviction market is a reputation system disguised as a wagering platform.

### Philosophical Foundations

Conviction markets rest on established ideas from philosophy, economics, and social theory — then extend them.

| Thinker | Concept | How Clout Uses It |
|---------|---------|-------------------|
| **Nassim Taleb** (2018) | Skin in the Game | Information from people with exposure to consequences is more trustworthy. Conviction stakes = formalized skin in the game. |
| **Michael Spence** (Nobel 2001) | Signaling Theory | Costly signals are credible signals. Staking money + public reputation is costlier than cheap talk, therefore more credible — proportional to the cost borne. |
| **J.L. Austin** (1962) | Performative Utterances | Prediction = constative ("X will happen"). Conviction stake = performative ("I commit to X with my identity"). The act creates social reality. |
| **Robert Aumann** (Nobel 2005) | Common Knowledge | Public stakes create common knowledge (I know that you know that I know). This enables coordination effects that anonymous markets can't. |
| **Foucault / Bentham** | Panopticon | Voluntary visibility forces calibration. Knowing your record is public changes how you stake — toward honesty. |
| **Pierre Bourdieu** (1979) | Capital Convertibility | Economic → social → symbolic capital. Conviction markets must resist letting money = credibility. Calibration > capital. |
| **Jean Baudrillard** (1981) | Simulacra | Manufactured conviction (wealth-as-credibility) is a simulacrum of belief. Protocol must distinguish real conviction from simulated conviction. |
| **Kahneman** (Nobel 2002) | Anchoring | Large stake sizes anchor perception. Protocol must surface relative conviction (% of wallet), not just absolute amounts. |
| **Keynes** (1936) | Beauty Contest | People stake based on what they think others believe. Public conviction creates cascades — powerful for coordination, dangerous for manipulation. |

### The Anti-Slop Thesis

In a world of infinite AI-generated content, takes, and predictions, **genuine human commitment is the scarcest resource**. An LLM can produce a thousand opinions per second. Nobody — human or AI — can stake without accepting consequences.

Conviction markets are a slop filter: they separate "I generated this opinion" from "I believe this enough to put my name and money on it."

This applies to agents too: when an AI stakes on Clout, it commits real USDC with a traceable wallet. The protocol forces every participant — human or AI — to have skin in the game.

### Conviction Market Strength Spectrum

Conviction markets produce their most distinctive signal (vs. prediction markets) under specific conditions:

| Condition | Conviction Signal Strength | Why |
|-----------|---------------------------|-----|
| **Self-referential stakes** ("I will beat you") | Strongest | You're committing to your own performance — not predicting a third party. Uniquely conviction-native. |
| **Small, high-context groups** (streamer + 200 viewers) | Strong | Identity graph is tight, social context is rich, repeated games build compound reputation. |
| **Subjective or ambiguous outcomes** | Strong (for reputation signal) | Resolution depends on judgment, not fact. Staker track record matters more than probability. Note: verification is harder — this is where conviction signal is most distinct from prediction markets, but also where manipulation risk is highest. |
| **Repeated games over time** | Strong | Compound reputation accrues. Calibration record becomes the primary signal. |
| **Large anonymous pools on objective events** | Weak — collapses toward prediction market | Individual identity diluted, social context lost. Rail C (open markets) is weakest zone. |

**Design implication**: Clout's core use cases (PvP, challenge pools) are in the strong zone. Open markets (Rail C) should be positioned differently when they launch and must follow Rail C philosophy alignment rules (identity visibility, track-record-first UX, time-at-risk signals) to avoid collapsing into a generic prediction market.

**Resolving the tension**: Gaming is the wedge because it combines two different strengths: self-referential stakes (conviction-native) AND verifiable outcomes (reduces dispute friction). Subjective outcomes produce stronger *reputation signals* (track record matters most when resolution is judgment-based), but they're harder to build infrastructure for. Gaming gives us the conviction signal with the verification substrate. Subjective markets (creator claims, debate) are the expansion path once the reputation layer is mature enough to support them.

### Philosophical Q&A — Strongest Challenges

**Q: If I hold strong conviction and the market resolves against me, does that destroy my reputation?**

No — it builds a calibration record. Taleb: loss from genuine belief with skin in the game is informative, not shameful. What matters is your distribution over time. 7/10 on high-conviction bets = elite calibration. 3/10 = reckless. Both are useful signals. The visibility of loss (Foucault) pushes future calibration toward honesty.

**Q: Isn't collective conviction just a prediction market with profiles?**

At scale on objective events, yes — it converges. That's fine. Prediction markets are a subset of conviction markets. The distinction is sharpest when stakes are self-referential, communities are small, outcomes are subjective, and games are repeated. Austin: prediction is constative ("X will happen"), conviction is performative ("I commit to X with my identity"). The performative dimension disappears when identity doesn't matter.

**Q: Can a billionaire stake $1B on a fake video and manipulate perception?**

This is the strongest attack — the plutocratic manipulation problem. A $1B stake from one wallet creates Kahneman anchoring (the number shifts baseline perception), Keynesian cascade (others follow the signal), and Bourdieu capital conversion (money → credibility).

**Why the protocol survives this:**

1. **Track record > stake size**: 500 accurate $20 stakes carry more conviction weight than one $1B stake with no history. Calibration over capital. You can create 10,000 wallets, but you can't give each one a 6-month track record. Time is the Sybil-resistant resource. (In v1: this is computed off-chain from on-chain `WalletRecord` data. See Section 7 Conviction Score v1 spec.)
2. **Progressive identity raises Sybil cost**: Creating 10,000 wallets is cheap. Creating 10,000 wallets each with verified Discord, game accounts, and social graphs is prohibitively expensive. Identity density is the defense, not on-chain wealth estimation (which is trivially gamed with hot wallets).
3. **Social graph analysis**: Real communities have interconnected wallets (shared Discord servers, game histories, mutual stakes). 10,000 puppet wallets with zero social connections look structurally different from 10,000 real users. On-chain cluster detection raises the cost of convincing manipulation.
4. **Counter-conviction incentive**: A $1B wrong-side stake (however distributed) is the most profitable counter-trade possible. Truth-tellers are maximally incentivized.
5. **Transparency is the antibody**: Unlike media manipulation (hidden funding), every stake is public and traceable. On-chain analysis can identify wallet clusters (shared funding source, correlated timing). The manipulation is harder to hide than in any traditional system.
6. **Time decay**: If stakes are time-locked and counter-evidence emerges, holding becomes reputationally expensive every day.

**Where it still fails**: When the chilling effect prevents counter-staking (social pressure, not just capital), or when the billionaire's off-chain influence affects the resolution itself. This is a protocol limitation, not a concept failure — and traditional media has the same vulnerability with zero transparency. Clout makes the manipulation legible; it doesn't prevent it.

**Q: Why gaming? Isn't this bigger than gaming?**

Yes — and that's the point. Gaming is the wedge because it sits in the strongest zone of the conviction signal spectrum: self-referential stakes ("I will beat you"), verifiable outcomes (game APIs), natural communities (Discord, Twitch), and daily repeat play (fast reputation compounding). Alternative wedges were evaluated:

- *Finance/CT*: Massive audience but crowded (Polymarket), and predicting third-party events is weaker conviction signal.
- *Fitness/Health*: Self-referential but hard to verify (wearable data is fakeable), small crypto overlap.
- *Creator milestones*: Easy verification but slow resolution (days/weeks vs. minutes).
- *Debate/Takes*: Pure conviction but subjective resolution — the collapse zone.

Gaming is where the conviction signal is strongest, verification is most solvable, community distribution is built-in, and behavior is already proven ($211M on CMG alone). The protocol generalizes; the wedge is chosen for signal strength, not market size.

**Q: Are you just building a sportsbook and calling it philosophy?**

Gaming PvP escrow is the surface product. The underlying primitive — "identity-linked public commitment with financial exposure and permanent track record" — is something new. No existing system combines all of: public identity, financial stake, time commitment, permanent record, and permissionless participation. The closest analogs are credit scores (private, centralized) and social media clout (free, no cost to be wrong). Clout makes conviction costly, public, and verifiable.

**Q: Doesn't requiring identity kill crypto-native adoption?**

Pseudonymous is enough. A wallet with 500 resolved challenges IS an identity — you don't need a passport. The key requirement is reputational continuity (same wallet across challenges), not legal identity. Progressive doxxing (Discord, game ID, ENS) strengthens the signal but isn't required. The minimum bar is: creating a new wallet is free, but a fresh wallet carries zero conviction score (time depth = 0, no track record). The protocol doesn't prevent identity rotation — it makes it transparent. In v1, the defense is legibility (everyone can see you have no history); in v2, linked identity proofs raise the cost of rotation.

**Q: How is this different from reputation systems that already exist (eBay ratings, Uber scores)?**

Three ways: (1) Financial exposure — eBay ratings are free to give, conviction stakes cost money. (2) Permissionless — no platform gatekeeper decides who participates. (3) Portable — your on-chain record follows you across any app that reads the contract, not locked inside one platform.

### Where Conviction Markets Fail

Conviction markets are not universal. These are the conditions under which the primitive breaks down or collapses into something less useful:

| Failure Mode | What Happens | Why It Fails |
|-------------|-------------|--------------|
| **Large anonymous pools** | Identity signal dissolves. Individual conviction is noise in aggregate volume. | Collapses into a prediction market. Rail C (open markets) is in this zone by design — position it accordingly. |
| **Plutocratic manipulation** | Wealthy actor stakes large to anchor perception (Kahneman) and trigger cascades (Keynes). | Conviction Score mitigates but doesn't prevent. Off-chain influence (media, social) can amplify. See billionaire attack analysis above. |
| **Resolution capture** | The resolution mechanism (admin in v1, voters in v2) is compromised or colluded against. | In v1, admin is a single point of trust. In v2, commit-reveal voting is exploitable if voter pool is small. UMA OOv3 is strongest but unmonitored on Avalanche. |
| **Chilling effect** | Social pressure prevents counter-staking even when evidence exists. | Financial incentive to counter-stake exists but social cost may outweigh it. Protocol can't fix off-chain power dynamics. |
| **Low liquidity / thin markets** | Too few participants → reputation signal is noisy, score distributions are meaningless. | Below ~500 resolved challenges system-wide, conviction scores don't differentiate. Need critical mass. |
| **Outcome ambiguity** | Outcome is genuinely subjective (not just hard to verify — actually contested). | Neither side is "wrong." Resolution becomes political. Works in PvP gaming (clear winner). Fails in debate/opinion markets without robust jury design. |
| **Identity farming** | Actors slowly build legitimate track records specifically to exploit a future high-stakes event. | Time-depth defense works against impulse Sybil but not against patient adversaries. Requires anomaly detection (sudden stake size increase) in v2+. |

**The honest position**: Conviction markets are strongest in the zones where prediction markets are weakest (small groups, self-referential stakes, repeated games, identity-rich context). They are weakest in the zones where prediction markets are strongest (large anonymous pools, objective binary events). The protocol should NOT expand into weak zones prematurely — and should clearly label market types by conviction signal strength when it does.

### Kill Criteria

**Gaming wedge kill criteria** (evaluate after Stage 2 MVP):
- If <50 unique wallets complete challenges in first 2 weeks → the distribution channel failed, not necessarily the concept. Pivot to different community (e.g., specific Discord servers).
- If >50% of challenges are disputed → mutual agreement path is broken. Manual resolution doesn't scale. Reassess v1 architecture.
- If conviction score distribution has Gini coefficient <0.3 after 500 resolved challenges (i.e., scores are nearly uniform — no meaningful differentiation) → the scoring model is wrong or users don't develop distinguishable records. Revise formula or acknowledge prediction market convergence.
- If users overwhelmingly prefer anonymous/fresh wallets over building track records → the reputation thesis doesn't match real user behavior. This is a concept-level failure.

**Concept kill criteria** (evaluate after 6 months):
- If conviction scores don't predict future accuracy (AUROC <0.55 when using score to predict next-challenge win rate) → the "conviction as information" thesis fails. It's just betting with profiles.
- If a model using only stake size predicts outcomes as well as the full conviction score (delta AUROC <0.02) → the identity/time/track record dimensions are decorative, not functional.

---

## 15. Key Data Points

### Market Size

| Metric | Value | Source |
|--------|-------|--------|
| Esports betting market (2025) | $2.8B | TheXboxHub |
| Esports betting projected (2030) | $14B+ | GlobalNewsWire |
| On-chain esports total (all platforms) | <$50M | Estimate based on SX Bet, Azuro, WINR esports segments |
| CMG PvP payouts | $211M+ | CheckMate Gaming homepage (Feb 2026) |
| CS2 skin gambling | ~$5B (hit $6B+ Oct 2025, crashed, recovered to ~$5.5B Nov 2025) | Skin.Club |
| Stake.com deposits | $1.1B/month | BlockchainMagazine |
| Polymarket esports | ~$9M (~0.07% of adjusted total) | Polymarket |
| Polymarket 2025 volume | ~$13B (adjusted; raw data double-counted per Paradigm) | Paradigm, Token Terminal |
| Creator economy (2025) | $250B | Goldman Sachs Research |

### Avalanche

| Metric | Value | Source |
|--------|-------|--------|
| USDC on Avalanche | ~$604M native (was $784M Q3 2025) | usdc.cool (live, Feb 22 2026) |
| TVL | ~$2.1B | DeFiLlama |
| C-Chain cumulative transactions | 1B+ | Team1 Blog |
| Prediction markets on Avalanche | Zero | DappRadar |
| UMA OOv3 address | 0xa4199d73ae206d49c966cF16c58436851f87d47F | UMA docs |
| Gnosis CTF on Avalanche | Not deployed (needs fresh deploy) | GitHub |
| Off The Grid wallets | 17.3M (7-13K Steam concurrent) | ActivePlayer.io |
| MapleStory accounts | 1.75M (70K daily wallets) | BlockchainGamerBiz |

### Gen-Z / Users

| Metric | Value | Source |
|--------|-------|--------|
| Gen-Z crypto ownership | 51% | Gemini |
| Gaming = primary social space | 58% | SQ Magazine |
| Betting = social activity | 67% | TransUnion |
| Twitch MAU | 240M | DemandSage |
| Twitch DAU | 35M | DemandSage |
| Kick users | 57M (+131% YoY) | StreamsCharts |
| Twitch streamers making $0 | 72.6% | PlayerCounter |
| Boys 11-17 who gambled | 36% | Common Sense Media |
| Gen-Z self-reported betting addiction | 37% | CNN |

### Agents / AI

| Metric | Value | Source |
|--------|-------|--------|
| AI agent token meta peak | $20B market cap | Blockworks |
| AI agent token meta (volatile) | $4-12B range through early 2026 | CoinMarketCap (fluctuates significantly) |
| Olas Predict accuracy | 79% | Olas |
| AI sports resolution accuracy | 99.7% | Gnosis AI agent studies |
| Coinbase Agentic Wallets | Launched Feb 11, 2026 | Coinbase |
| x402 transactions | 75M, $24M processed | CoinGecko |
| AI agent deployment failure rate | 76% | Medium analysis |

---

## 16. Sources

### Market & Competition
- [TheXboxHub - Esports Betting $2.8B](https://www.thexboxhub.com/esports-betting-evolution-how-competitive-gaming-wagering-reached-2-8b/)
- [GlobalNewsWire - Esports Betting Projections](https://www.globenewswire.com/news-release/2026/02/13/3237947/28124/en/E-Sports-Betting-Analysis-Report-2026.html)
- [CheckMate Gaming](https://www.checkmategaming.com/)
- [Skin.Club - CS2 Market Cap](https://community.skin.club/en/news/cs2-skins-market-cap-a-new-historical-record)
- [SX Bet](https://sx.bet/)
- [Azuro](https://azuro.org/)
- [WINR Docs](https://docs.winr.games/)
- [Polymarket Esports](https://polymarket.com/predictions/esports)
- [Forkast on Arbitrum](https://www.businesswire.com/news/home/20251106162098/en/Forkast-Joins-Arbitrum)
- [Duelmasters.io](https://www.duelmasters.io/)
- [DappRadar - Avalanche Gambling](https://dappradar.com/rankings/protocol/avalanche/category/gambling)

### Streaming & Creator Economy
- [DemandSage - Twitch Statistics 2026](https://www.demandsage.com/twitch-users/)
- [StreamsCharts - Q4 2025](https://streamscharts.com/news/q4-2025-global-livestreaming-landscape)
- [PlayerCounter - Creator Earnings](https://playercounter.com/gaming-content-creator-earnings-breakdown)
- [Twitch Channel Points](https://help.twitch.tv/s/article/channel-points-guide)
- [Kick Predictions](https://help.kick.com/en/articles/11182854-guide-to-predictions-for-streamers)

### Avalanche
- [Build Games](https://build.avax.network/build-games)
- [usdc.cool/avalanche](https://usdc.cool/avalanche)
- [UMA Network Addresses](https://docs.uma.xyz/resources/network-addresses)
- [DeFiLlama - Avalanche](https://defillama.com/chain/avalanche)
- [Avalanche Year in Review](https://www.team1.blog/p/avalanche-2025-year-in-review)

### Gen-Z & Behavior
- [Gemini - Gen Z Crypto](https://www.gemini.com/blog/gemini-survey-finds-more-than-half-of-gen-z-owns-crypto)
- [SQ Magazine - Gen Z Gaming](https://sqmagazine.co.uk/gen-z-gaming-platform-preferences-statistics/)
- [TransUnion - Q2 2025](https://newsroom.transunion.com/gen-z-millennial-speculators-drove-year-over-year-gambling-growth-in-q2-2025/)
- [Common Sense Media - Betting on Boys](https://www.commonsensemedia.org/research/betting-on-boys)

### Agents & AI
- [Coinbase Agentic Wallets](https://www.coinbase.com/developer-platform/discover/launches/agentic-wallets)
- [x402 Docs](https://docs.cdp.coinbase.com/x402/welcome)
- [Olas Predict](https://olas.network/agent-economies/predict)
- [Gnosis - AI Agents in Prediction Markets](https://www.gnosis.io/blog/the-rise-of-ai-agents-in-prediction-markets)

### Intellectual Lineage
- [Robin Hanson - Futarchy](https://mason.gmu.edu/~rhanson/futarchy.html)
- [MetaDAO - Futarchy on Solana](https://www.helius.dev/blog/futarchy-and-governance-prediction-markets-meet-daos-on-solana)
- [Vitalik - From Prediction Markets to Info Finance](https://vitalik.eth.limo/general/2024/11/09/infofinance.html)
- [Commons Stack - Conviction Voting](https://medium.com/giveth/conviction-voting-a-novel-continuous-decision-making-alternative-to-governance-aa746cfb9475)
- [Scott Alexander - Play Money and Reputation](https://www.astralcodexten.com/p/play-money-and-reputation-systems)

### Game APIs
- [Riot Developer Portal](https://developer.riotgames.com/apis)
- [OpenDota API](https://docs.opendota.com/)
- [FACEIT Developer Docs](https://docs.faceit.com/)
- [GRID Esports](https://grid.gg/)
- [PandaScore](https://www.pandascore.co/)

### Previous Work (Internal — not for external use)
- Team has prior experience building EVM prediction market protocols (Diamond proxy, Foundry, Solidity 0.8.x)
- Patterns reused: lifecycle state machines, commit-reveal voting, oracle adapters, formal invariants
