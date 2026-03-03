# Clout — Turborepo Monorepo

## Structure
- `packages/contracts/` — Solidity/Foundry smart contracts (src/, test/, foundry.toml)
- `packages/types/` — shared TypeScript types (tsup build)
- `apps/web/` — Next.js 16 frontend (React 19, Tailwind 4)

## Key Files
- RESEARCH.md — canonical struct definitions, state machine, and protocol spec
- GLOBAL_PLAN.md — overall architecture and task sequencing
- packages/contracts/foundry.toml — Solidity config (check version here)
- turbo.json — turborepo pipeline config

## Build & Test
- `pnpm turbo build` — build all packages
- `cd packages/contracts && forge test -v` — run contract tests
- `pnpm turbo typecheck` — TypeScript checks across all packages

## Rules
- Match the pragma version in packages/contracts/foundry.toml
- Follow OpenZeppelin patterns (ReentrancyGuard, Ownable, IERC20)
- All amounts use 6 decimals (stablecoin native)
- Read RESEARCH.md before planning any contract — it's the source of truth for structs and state machines
- Named imports only (`import {X} from "..."`)
- Read memory.md if it exists for project patterns
