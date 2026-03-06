# Codex Audit Prompt — Clout (GLOBAL_PLAN.md + TASK_QUEUE.md)

You are auditing two documents for an autonomous implementation orchestrator called Nightcrawler. These documents will be consumed directly by AI models (Claude Opus for planning, Claude Sonnet for implementation) operating inside a strict loop with no human in the loop until escalation. Ambiguity, contradiction, or missing information will cause implementation failures, wasted budget, or incorrect code.

## Context

**Project:** Clout — a conviction market protocol for competitive gaming on Base.
**Competition:** Independent project.
**Execution model:** Nightcrawler picks tasks from TASK_QUEUE.md in order, respecting dependencies. For each task, Claude Opus writes a mini-plan, Codex audits the plan, Claude Sonnet implements, Codex reviews the code. If the loop gets stuck (3 iterations or repeated feedback), it escalates to WhatsApp.
**Developer:** Solo (Mateo). Contracts + frontend + deployment.

## What You Are Auditing

1. **GLOBAL_PLAN.md** — The master plan for the 9-day MVP. Nightcrawler reads this as context for every task. It defines what to build, in what order, with what constraints.
2. **TASK_QUEUE.md** — The ordered task list with NC-xxx stable IDs. Nightcrawler consumes tasks sequentially. Each task has: description, acceptance criteria, dependencies, and constraints.

## Orchestrator Constraints (from Nightcrawler SPEC.md and RULES.md)

The auditing model must evaluate the documents against these orchestrator rules:

- **Task selection is dynamic:** After each task completes, the orchestrator re-evaluates the queue and picks the next QUEUED task whose dependencies are ALL in COMPLETED state. Dependencies in terminal failure (BLOCKED, SKIPPED, LOCKED) cause DEP_BLOCKED. Dependencies still QUEUED or IN_PROGRESS are skipped for now, not blocked.
- **No task invention:** Models can only work on tasks from TASK_QUEUE.md. They cannot create new tasks, split tasks, or reorder the queue.
- **No scope creep:** If a task seems to require work not described in its "What" section, the model must log a BLOCKER and skip. It cannot infer scope.
- **Acceptance criteria are the test:** A task is COMPLETED only when all acceptance criteria are met and post-commit tests pass. Vague or untestable criteria cause infinite loops.
- **Dependencies must be exact:** Referencing NC-xxx IDs. If a task depends on code from another task but doesn't list it as a dependency, the orchestrator may schedule it before the dependency completes.
- **Constraints are hard rules:** The "Constraints" field per task is injected into every prompt. Contradictions between constraints and acceptance criteria cause lock loops.
- **Budget is finite:** Each session has a cap ($20 default). Each task consumes budget for planning + audit + implementation + review. Tasks that are too large will exhaust the budget before completing.
- **3-iteration cap:** If Opus and Codex cannot converge on a plan or implementation in 3 iterations, the task is LOCKED and escalated. Tasks with ambiguous specs are likely to lock.
- **GLOBAL_PLAN.md is read-only:** The orchestrator never modifies it. Everything in it is treated as ground truth. Contradictions within the plan propagate silently.
- **RESEARCH.md is the full spec:** GLOBAL_PLAN.md references RESEARCH.md sections. If the plan says something that contradicts RESEARCH.md, the model will be confused about which is authoritative.
- **State machine transitions must be explicit:** The contracts use enum-based state machines. Every valid transition must be described. Missing transitions cause implementation gaps.
- **Every state transition emits an event** (project rule).
- **All amounts use 6 decimals** (stablecoin native, not 18).
- **ReentrancyGuard on every external function that transfers tokens** (project rule).
- **Tests use Foundry vm.warp() for timeouts, vm.prank() for caller spoofing** (project rule).

## Audit Checklist

For each finding, report:
- **Severity:** CRITICAL / HIGH / MEDIUM / LOW
- **File:** GLOBAL_PLAN.md or TASK_QUEUE.md (with line reference or task ID)
- **Section:** Which section or task
- **Issue:** What is wrong, ambiguous, or missing
- **Fix:** Specific remediation

### 1. Internal Consistency
- Do the 7 simplifications in GLOBAL_PLAN.md align with what the tasks actually build?
- Do the gate pass criteria match the acceptance criteria of the tasks that feed into each gate?
- Do the day-by-day hour estimates match the task complexity?
- Does the dependency graph match the task dependencies in TASK_QUEUE.md?
- Do the invariants (I-1 through I-14) have corresponding acceptance criteria or test coverage in the task queue?
- Does the fee structure table match the acceptance criteria in NC-008?
- Does the state machine diagram match the task descriptions (NC-003 through NC-007)?

### 2. Nightcrawler Executability
- Is every task self-contained enough for a model to implement without asking questions? Or will it lock on iteration 1?
- Are acceptance criteria testable (specific, measurable) or vague ("works correctly", "handles edge cases")?
- Are dependencies complete? Could a task be scheduled before code it needs exists?
- Are constraints consistent with acceptance criteria? Any contradictions that would cause the plan-audit loop to disagree?
- Is any task too large to complete within a ~$3-5 budget (roughly 20 min of Opus+Sonnet+Codex interaction)? Should it be split?
- Are there implicit dependencies not captured in the dependency field (e.g., NC-008 assumes struct fields added in NC-003)?
- Could the dynamic task picker ever strand a task? (e.g., task A depends on B and C, B completes but C is still queued — A stays queued. But if C has no other path to completion in this session, A is effectively dead.)

### 3. Contract Architecture
- Do the state machines in GLOBAL_PLAN.md cover all transitions? Any missing edges?
- Are timeout values consistent (plan says 48h create, 48h accept, 24h confirm, 48h resolver, 24h appeal, 48h admin)?
- Is the payout math unambiguous? Especially DRAW (50/50 minus fee) rounding and proportional pool payouts.
- Are the invariants (I-1 through I-14) enforceable from the task descriptions, or do some require architectural decisions not specified?
- Does CloutPool duplicate code from CloutEscrow (same token whitelist, same fee pattern)? Is shared inheritance specified or left implicit?
- Is the dispute threshold mechanism in CloutPool (>20% of losing stakers) specified enough for implementation?

### 4. Gaps and Missing Specifications
- Are there state transitions in the state machine diagrams that no task implements?
- Are there acceptance criteria that reference functionality not described in the "What" section?
- Are there RESEARCH.md sections referenced in the plan that introduce requirements not covered by any task?
- Is there a task for setting up the test harness, or does NC-010 assume it exists from earlier tasks?
- Is admin role assignment covered? Who is admin on deployment? Is it configurable?
- Is the treasury address deployment configuration specified in any task?

### 5. Risk and Failure Modes
- If Gate 1 is missed, the plan says "cut CloutPool entirely." But NC-011 and NC-012 depend only on NC-001 and NC-002 — the orchestrator would still attempt them. Is there a mechanism to enforce gate failures?
- If a task LOCKs early (e.g., NC-003), the dependency chain blocks NC-004 through NC-010. Is the blast radius acceptable?
- Frontend tasks (NC-014 through NC-016) depend on NC-013 (deployment script). But NC-013 deploys to Base Sepolia, which requires a private key and RPC. Nightcrawler's rules say "NEVER interact with deployed contracts or mainnet/testnet RPCs" at the project code layer. How is deployment handled?
- NC-017 (E2E testing on Base Sepolia) requires interacting with deployed contracts through a browser. This is outside Nightcrawler's capability. Is this task actually for Mateo, not Nightcrawler?

## Output Format

List findings grouped by severity (CRITICAL first, then HIGH, MEDIUM, LOW). For each finding:

```
* Severity: <CRITICAL|HIGH|MEDIUM|LOW>
  File: <filename> (task ID or line reference)
  Section: <section name>
  Issue: <clear description of the problem>
  Fix: <specific, actionable remediation>
```

After all findings, provide a summary count: N CRITICAL, N HIGH, N MEDIUM, N LOW.

If a finding affects both files (e.g., inconsistency between GLOBAL_PLAN.md and TASK_QUEUE.md), list it under the file that should be changed to fix it.

End with a "No Finding" confirmation for any checklist category where you found zero issues — this confirms you actually checked it rather than skipping it.
