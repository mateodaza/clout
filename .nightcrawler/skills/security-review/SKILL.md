---
name: security-review
description: Smart contract security review checklist. Use when reviewing Solidity code for vulnerabilities, before committing, or when auditing contracts.
user-invocable: false
---

# Smart Contract Security Review

## Critical Checks (MUST pass)

### Reentrancy
- All external calls follow CEI (Checks-Effects-Interactions)
- `ReentrancyGuard` on functions with token transfers
- No state reads after external calls that could be manipulated
- Cross-function reentrancy: check if multiple functions share mutable state

### Access Control
- Every state-changing function has access control
- Owner/admin functions use `onlyOwner` or role-based modifiers
- Initialization functions can only be called once
- No unprotected `selfdestruct` or `delegatecall`

### Integer Safety
- Solidity 0.8+ overflow protection is active (no `unchecked` without justification)
- Division before multiplication avoided (precision loss)
- All amounts use consistent decimals (6 for stablecoins)
- `bound()` used in fuzz tests to constrain inputs

### Token Handling
- `SafeERC20` for all transfers
- Return values checked (or use safeTransfer)
- Approve race condition handled (approve 0 first, or use increaseAllowance)
- No assumption about token decimals — read from contract or use constant

### State Machine
- All transitions validated against RESEARCH.md state diagram
- No skippable states
- Expired/timed-out states handled
- Cannot re-enter completed states

## Gas & Efficiency
- Storage reads minimized (cache in memory)
- Mappings preferred over arrays for lookups
- Events indexed on commonly-filtered fields (max 3 indexed per event)
- No unbounded loops over dynamic arrays
