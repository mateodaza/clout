---
name: solidity-foundry
description: Solidity smart contract development with Foundry. Use when writing, modifying, testing, or reviewing Solidity contracts.
user-invocable: false
---

# Solidity/Foundry Development Guide

## Before Writing Any Code

1. Read `RESEARCH.md` — it is the source of truth for struct definitions, state machines, and protocol spec
2. Read `foundry.toml` — match the pragma version exactly
3. Check existing contracts in `src/` — understand what's already built
4. Check existing tests in `test/` — follow established patterns

## Solidity Conventions

### Imports
- Named imports ONLY: `import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";`
- Never use wildcard imports

### Types & Precision
- All monetary amounts use 6 decimals (stablecoin native, NOT 18)
- Use `uint256` for amounts, `uint64` for timestamps
- Define constants for magic numbers: `uint256 constant PRECISION = 1e6;`

### Security Patterns (MANDATORY)
- Checks-Effects-Interactions (CEI) pattern on every external call
- `ReentrancyGuard` on all functions that transfer tokens
- `SafeERC20` for all token transfers (`safeTransfer`, `safeTransferFrom`)
- Never use raw `.call{value:}` for token transfers
- Validate all inputs at function entry (require statements first)
- Access control on all state-changing functions (`onlyOwner`, role-based, or custom)

### Code Style
- Events for every state change (emit before external calls in CEI)
- NatSpec documentation on public/external functions
- Custom errors over require strings: `error Unauthorized();`
- Group functions: external -> public -> internal -> private

## Foundry Testing

### Running Tests
```bash
forge build          # compile
forge test -v        # run all tests (verbose)
forge test -vvvv     # trace-level debugging
forge test --match-test testSpecificFunction  # single test
```

### Test Structure
```solidity
contract MyContractTest is Test {
    MyContract public target;

    function setUp() public {
        // Deploy contracts, set initial state
    }

    function test_normalCase() public {
        // Test happy path
    }

    function test_RevertWhen_InvalidInput() public {
        vm.expectRevert(MyContract.InvalidInput.selector);
        target.doSomething(0);
    }

    function testFuzz_Amount(uint256 amount) public {
        amount = bound(amount, 1, 1e12); // bound to reasonable range
        // Test with fuzzed input
    }
}
```

### Key Forge Cheatcodes
- `vm.prank(address)` — next call from address
- `vm.startPrank(address)` / `vm.stopPrank()` — multiple calls
- `vm.expectRevert(selector)` — expect revert
- `vm.expectEmit(true, true, false, true)` — expect event
- `vm.warp(timestamp)` — set block.timestamp
- `deal(token, address, amount)` — set token balance
- `bound(value, min, max)` — constrain fuzz input

### What to Test
1. Happy path for every function
2. Access control (unauthorized callers revert)
3. Edge cases (zero amounts, max values, empty arrays)
4. State transitions (verify enum state changes)
5. Reentrancy (if applicable)
6. Event emissions

## Common Mistakes to Avoid
- Using 18 decimals instead of 6
- Forgetting reentrancy guard on token transfer functions
- Not reading RESEARCH.md before implementing structs
- Creating contracts not in the plan
- Modifying files outside the plan's scope
- Using `transfer()` instead of `safeTransfer()`
- Missing access control on admin functions
