# Build Games — Stage 1 Form Answers

> Submitted February 25, 2026.

---

## Project Overview

**Project name**: Clout

**One sentence (max 280 chars)**:

> Competitive gamers stake USDT via smart contract escrow on Avalanche. Every outcome builds a permanent conviction record, because strong convictions deserve more than words. Gaming is the wedge; anywhere people have skin-in-the-game opinions, Clout gives them a place to prove it.

**Category**: Gaming

**Subcategory**: Gaming Infrastructure / Tooling

**Started before Build Games?**: No — new idea

---

## Problem Identification

**Describe the pain point or need your project aims to solve:**

> Gamers wager billions every year through trust-based channels: Discord middlemen, skin gambling sites (~$5B economy), play-money predictions on streaming platforms, and off-chain skill-based competition platforms that have paid out hundreds of millions. None of it settles on-chain. None of it builds a verifiable, portable reputation. Players trust strangers to hold their money, and if someone doesn't pay out, there's no recourse.
>
> Meanwhile, Avalanche has one of the biggest gaming ecosystems in Web3 but zero infrastructure for staking on outcomes. The games are here. The wagering layer isn't.

**Describe your primary user persona. What needs do they have? Is it B2B or B2C?**

> B2C. Our primary users are competitive gamers who already wager on their own matches, the kind who stake in Discord servers, use third-party match platforms, or bet skins with friends. They're comfortable with risk, motivated by competition, and frustrated by middlemen who can disappear with funds.
>
> Secondary users are streamers and content creators who want to monetize audience engagement beyond tips and subscriptions. They create challenges ("I'll beat this boss on the hardest difficulty"), the audience stakes for or against, and the host takes a commission when they deliver.
>
> Both personas already exhibit the behavior: they just lack trustless infrastructure to do it on-chain.

**Describe existing workarounds or solutions before your project:**

> Today gamers wager through:
>
> - **Discord middlemen**: Trust-based escrow run by server admins. No smart contract, no accountability. If the middleman disappears, the money is gone.
> - **Skin gambling sites**: A ~$5B economy built on trading game skins as proxy currency. Operates in legal grey areas, no permanent record, and regularly shut down by publishers.
> - **Play-money predictions on streaming platforms**: Engagement tools with zero real stakes. Popular but meaningless - wrong calls have no consequence.
> - **Off-chain skill-based competition platforms**: Centralized services that have paid out hundreds of millions in PvP wagers. Proven demand, but custodial, off-chain, and players have no portable reputation across platforms.
>
> All of it is custodial, off-chain, and disposable. Nothing builds a verifiable record that follows you across platforms.

**Explain how your project solves the problem better than current solutions:**

> Clout replaces trust with smart contract escrow. You create a challenge, set the stake in USDT, your opponent accepts and locks matching funds into the contract. Play the match off-chain, submit the result on-chain, and the winner claims the pot. Nobody else touches the money.
>
> What makes it better than existing solutions:
>
> - **Non-custodial**: No middleman holds funds. USDT is locked in the contract until settlement, the protocol never takes custody.
> - **Permanent track record**: Every challenge, outcome, and stake is recorded on-chain. Your reputation is portable and verifiable.
> - **Dispute resolution with designated resolvers**: Optional trusted third parties (tournament organizers, streamers, community figures) can resolve disputes, with admin fallback and player appeal rights.
> - **Bigger than gaming**: The core primitive "stake on your call, settle on-chain, build reputation" works for any creator with conviction and any audience with an opinion. Gaming is the wedge because the behavior is already proven and outcomes are verifiable.
>
> Clout is a conviction market: public stakes, permanent record, compounding reputation.

**Describe the key blockchain interactions in your solution:**

> Every state transition in the challenge lifecycle happens on-chain:
>
> 1. **Challenge creation**: Creator calls `createChallenge()`, specifying opponent, stake amount, stablecoin (USDT/USDC), game type, and optional designated resolver. Creator's USDT is transferred to the escrow contract.
> 2. **Challenge acceptance**: Opponent calls `acceptChallenge()`, locking matching USDT into the contract.
> 3. **Result submission**: After the match (played off-chain), either party calls `submitResult()` with the outcome. This starts a 24-hour confirmation window.
> 4. **Confirmation or dispute**: The counterparty confirms (instant settlement) or disputes (escalates to designated resolver or admin). If neither acts within 24 hours, the submitted result auto-accepts.
> 5. **Settlement**: Winner calls `claimWinnings()` to withdraw the pot minus protocol fee. DRAW splits 50/50. INVALID refunds both players fully.
>
> Additionally, an on-chain `WalletRecord` struct tracks each wallet's challenge history (completions, wins, total staked, timestamps), forming the basis of a portable conviction score computed off-chain.
>
> The contract also supports Challenge Pools: a host creates a YES/NO stake pool, audience members stake into either side, a designated resolver submits the outcome, and winners split the losing pool proportionally. The contract is natively agent-compatible - any wallet, human or AI, can call every function without special integration.

---

## Video & Partnerships

**Video link**: https://www.youtube.com/watch?v=G9Lu2YYWS8w

**Integration partners**: Tether
