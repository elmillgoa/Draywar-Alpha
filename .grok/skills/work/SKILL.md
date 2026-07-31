---
name: work
description: Execute the current Draywar Alpha contract as orchestrator — plan, implement or delegate, verify, record. Use when starting or continuing work from the Alpha phase plan. /work
---

# Execute a contract (Alpha)

**One contract at a time, in Alpha phase order (A0→A5).** No future-phase work
because you happen to be in the file.

## Step 1 — Restate criteria in one line

If you cannot, re-read. If a criterion is untestable or conflicts with Alpha
scope / reputation law, `/escalate`. Do not reinterpret into something convenient.

## Step 2 — Plan

- Separable pieces; what can parallelize; what must serialize.
- Proof for each criterion (test, scene, console exit code).
- Constraints: EventBus-only, numbers in balance, content as data, full-sized
  data shapes, Alpha ceilings.

## Step 3 — Implement or delegate

Briefs must carry: contract ID + criteria quoted; scope boundary (what is *not*
theirs); stop-and-ask list; evidence to return.

Independent agents may run in parallel. Trivial one-line edits: do yourself.

## Step 4 — Verify in the main chat

Agents report; you verify.

```
powershell -ExecutionPolicy Bypass -File scripts/lint.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
```

**Verify red before trusting green** on new tests.

## Step 5 — Definition of done

Run `/adversary` when there is non-trivial logic, then `/verify`. All points must hold.

## Step 6 — Record and commit

```
python scripts/journal.py add CONTRACT "Ax complete" --detail "criteria + evidence"
```

Update `docs/state.md`. Commit with contract-ID prefix.

## Step 7 — Phase complete → automatic wrap

If this contract **closes the phase** (all phase work done; any plan-marked
human gate signed or not required for this phase):

1. Do **not** wait for Elliot to say wrap or push.
2. Run `/wrap` (commit any handoff docs, push `origin/main`).
3. Final message ends with the wrap report, then **exactly** this last line:

```
Chat ready to close.
```

If a human gate is still open, report and stop — wrap only after the phase is
closed.

## Report to Elliot (mid-phase or pre-gate)

> **Now working:** [what the game can do]
>
> **Proved by:** [plain evidence]
>
> **Notes:** [judgement calls]
>
> **Next:** [next contract]
