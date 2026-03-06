# Clout — Executive Summary

**One line**: On-chain wagering for gamers, built on Base. Gaming is the wedge — the protocol is a conviction market primitive that works for any creator and any audience.

**Domain**: clout.ac

---

## The Problem

Gamers wager billions through trust-based channels — Discord middlemen, skin gambling sites (~$5B economy), play-money Twitch predictions, off-chain platforms like CheckMate Gaming ($211M+ paid out). None of it settles on-chain. None of it builds verifiable reputation. Almost none of it monetizes creators.

Meanwhile, Base provides native USDC, sub-cent fees, and Coinbase Smart Wallet for seamless onboarding.

## The Insight

Prediction market UX applied to gaming doesn't work (Forkast tried, near-zero traction). But PvP match wager platforms do (CMG: $211M+, 16M+ matches). Gamers want to stake on themselves and their matches, not spectate YES/NO markets.

## What Clout Is

A conviction market — you stake USDC on your match or your call. That stake is public, your track record is permanent, your reputation builds over time.

**Three rails**:
- **Rail A (MVP)**: PvP Escrow — head-to-head match stakes, USDC locked in smart contract, winner claims pot
- **Rail B (fast follow)**: Challenge Pools — streamers create stake pools, audience participates, host takes commission
- **Rail C (v2)**: Open Markets — tournament/event outcomes via Gnosis CTF

## Tech

Single `CloutEscrow.sol` contract (~400-500 lines), Base, USDC (native via Circle CCTP, 6 decimals), Foundry, OpenZeppelin. Sub-second finality. Any wallet can interact — human or AI. Adults only, non-custodial — no house, no odds, no custody.

**Resolution**: Manual settlement v1 → commit-reveal voting v2 → UMA Optimistic Oracle v3.

## Why It's Bigger Than Gaming

The core primitive — "creator stakes a claim, audience stakes conviction, escrow settles on-chain" — is niche-agnostic. Identity-linked stakes + time-weighted scoring + permanent on-chain record = reputation. No existing platform combines all of these. Gaming is the wedge because behavior is proven and outcomes are verifiable, but the protocol generalizes to any creator vertical.

## Competition

Independent project. MVP target: working prototype on Base Sepolia.
