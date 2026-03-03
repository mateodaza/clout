---
name: typescript-frontend
description: TypeScript and React frontend development. Use when writing TypeScript, React components, hooks, or frontend application code.
user-invocable: false
---

# TypeScript & Frontend Development

## TypeScript Conventions
- Strict mode always (`"strict": true` in tsconfig)
- Explicit return types on exported functions
- Use `interface` for object shapes, `type` for unions/intersections
- Prefer `readonly` properties where mutation isn't needed
- No `any` — use `unknown` and narrow with type guards
- Null safety: use optional chaining (`?.`) and nullish coalescing (`??`)

## React Patterns
- Functional components only (no class components)
- Custom hooks for shared logic (`use` prefix)
- `useMemo` / `useCallback` only when there's a measured performance need
- Colocate state as close to where it's used as possible
- Extract complex logic into hooks, keep components focused on rendering

## Web3 Frontend (Wagmi/Viem)
- Use `viem` for contract interactions (not ethers.js)
- Use `wagmi` hooks for React integration (`useReadContract`, `useWriteContract`)
- Always handle: loading, error, and success states for transactions
- Show transaction hash and link to explorer after submission
- Handle chain switching and wallet connection errors gracefully
- Parse contract amounts with correct decimals (6 for stablecoins)

## Testing
```bash
npm test              # run test suite
npm run type-check    # TypeScript compilation check
npm run lint          # ESLint
```

## Common Mistakes
- Importing from wrong package (wagmi v2 vs v1 APIs differ significantly)
- Not awaiting transaction confirmation before updating UI
- Using `Number` for big token amounts (use `BigInt` or viem's `parseUnits`)
- Missing error boundaries around Web3 components
