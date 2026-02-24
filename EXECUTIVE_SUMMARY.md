# Clout — Executive Summary

**One line**: On-chain wagering for gamers, built on Avalanche. Gaming is the wedge — the protocol is a conviction market primitive that works for any creator and any audience.

**Domain**: clout.ac

---

## The Problem

Gamers wager billions through trust-based channels — Discord middlemen, skin gambling sites (~$5B economy), play-money Twitch predictions, off-chain platforms like CheckMate Gaming ($211M+ paid out). None of it settles on-chain. None of it builds verifiable reputation. Almost none of it monetizes creators.

Meanwhile, Avalanche has one of the biggest Web3 gaming ecosystems (Off The Grid, MapleStory, Shrapnel) but zero wagering infrastructure.

## The Insight

Prediction market UX applied to gaming doesn't work (Forkast tried, near-zero traction). But PvP match wager platforms do (CMG: $211M+, 16M+ matches). Gamers want to stake on themselves and their matches, not spectate YES/NO markets.

## What Clout Is

A conviction market — you stake USDC on your match or your call. That stake is public, your track record is permanent, your reputation builds over time.

**Three rails**:
- **Rail A (MVP)**: PvP Escrow — head-to-head match stakes, USDC locked in smart contract, winner claims pot
- **Rail B (fast follow)**: Challenge Pools — streamers create stake pools, audience participates, host takes commission
- **Rail C (v2)**: Open Markets — tournament/event outcomes via Gnosis CTF

## Tech

Single `CloutEscrow.sol` contract (~400-500 lines), Avalanche C-Chain, USDC (native, 6 decimals, supports permit), Foundry, OpenZeppelin. Sub-2-second finality. Any wallet can interact — human or AI. Adults only, non-custodial — no house, no odds, no custody.

**Resolution**: Manual settlement v1 → commit-reveal voting v2 → UMA Optimistic Oracle v3.

## Why It's Bigger Than Gaming

The core primitive — "creator stakes a claim, audience stakes conviction, escrow settles on-chain" — is niche-agnostic. Identity-linked stakes + time-weighted scoring + permanent on-chain record = reputation. No existing platform combines all of these. Gaming is the wedge because behavior is proven and outcomes are verifiable, but the protocol generalizes to any creator vertical.

## Competition

Avalanche Build Games ($1M prize pool). Stage 1 pitch video due Feb 25. Stage 2 working prototype on Fuji due March 9.
