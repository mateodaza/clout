---
name: ponder-indexer
description: Ponder blockchain indexer development. Use when writing or modifying indexer schemas, event handlers, or Ponder configuration.
user-invocable: false
---

# Ponder Indexer Development

## What is Ponder
Ponder is a TypeScript indexer for EVM blockchains. It processes contract events into a queryable GraphQL API. Think of it as "The Graph but local-first and TypeScript-native."

## Project Structure
```
ponder/
├── ponder.config.ts    — networks, contracts, ABIs
├── ponder.schema.ts    — database schema (tables)
├── src/
│   └── index.ts        — event handlers
├── abis/               — contract ABIs (JSON)
└── .env.local          — RPC URLs, API keys
```

## Schema (ponder.schema.ts)
- Use `onchainTable()` for indexed data
- Column types: `text`, `integer`, `bigint`, `boolean`, `hex`
- `bigint` for all token amounts (preserves precision)
- Add indexes on frequently queried fields

## Event Handlers (src/index.ts)
- One handler per contract event
- Use `context.db` for database operations (insert, update, upsert)
- Use `context.client` for RPC calls (read contract state)
- Handlers must be idempotent (re-processing same event = same result)
- Use `event.args` for decoded event parameters
- Use `event.block.timestamp` for time data

## Commands
```bash
ponder dev        # start dev server with hot reload
ponder serve      # production server
ponder codegen    # regenerate types from schema
```

## Common Mistakes
- Using `Number` for token amounts (use `BigInt`)
- Not handling the case where an entity doesn't exist yet (use upsert)
- Forgetting to add ABI to ponder.config.ts when adding new events
- Not matching event signatures exactly to the contract ABI
