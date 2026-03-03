---
name: code-quality
description: Code quality and review standards. Use when implementing features, reviewing code, or making architectural decisions.
user-invocable: false
---

# Code Quality Standards

## Implementation Discipline
- Implement EXACTLY what the plan says — no more, no less
- Do not add features, utilities, or abstractions not in the plan
- Do not refactor surrounding code unless the plan calls for it
- Do not create "helper" or "probe" contracts/files outside the plan
- If something seems missing from the plan, implement what's there — the auditor will catch gaps

## Git Hygiene
- Every file you modify must be justified by the plan
- Do not modify config files unless the plan requires it
- Do not add or remove dependencies without plan approval
- Keep changes minimal and focused

## Testing Standards
- Every public function needs at least one test
- Test the happy path AND the revert cases
- Fuzz tests for any function that takes numeric input
- Test names describe what they verify: `test_RevertWhen_CallerNotOwner`
- Tests must be deterministic — no randomness without `bound()`

## Error Handling
- Custom errors over require strings (gas efficient, clearer)
- Error names describe the condition: `error InsufficientBalance(uint256 required, uint256 available);`
- Validate inputs at function boundaries, trust internal calls
- Never silently swallow errors

## Documentation
- NatSpec on all public/external functions
- @param and @return for every parameter
- @notice for user-facing description
- @dev for implementation notes only when non-obvious
