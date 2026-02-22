# Clout

Clout is a conviction market protocol: users make public, stake-backed claims, outcomes settle via on-chain escrow, and track records accumulate over time.

Gaming is the wedge.

## Current Scope

This repo currently contains strategy and pitch documentation for Avalanche Build Games (2026).

- `RESEARCH.md`: full strategic + product spec
- `PITCH_SCRIPT.md`: final 2-minute pitch script

## Product Rails

- **Rail A: PvP Escrow (MVP)**
  - 1v1 match stakes
  - matched collateral
  - manual resolution fallback in v1

- **Rail B: Challenge Pools (MVP-lite)**
  - host-defined YES/NO challenge
  - audience stake pool
  - fixed close time + event window constraints
  - capped participation + manual resolution

- **Rail C: Open Markets (post-MVP)**
  - broader event markets and pricing rails
  - expansion layer only (not core identity)
  - must preserve conviction guardrails (identity visibility, track-record-first UX, time-at-risk signals)

## MVP (Stage 2)

Target: **March 9, 2026**

In scope:

- Rail A end-to-end lifecycle
- Rail B-lite end-to-end lifecycle
- USDC collateral on Avalanche Fuji
- basic web app flow for create/join/resolve/claim

Out of scope:

- full uncapped Challenge Pools
- Rail C open markets
- automated game API resolution
- x402 convenience layer

## Next Step

If you are reviewing this project for demo readiness, start with:

1. `PITCH_SCRIPT.md`
2. `RESEARCH.md`
