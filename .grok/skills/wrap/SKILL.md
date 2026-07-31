---
name: wrap
description: Close a Draywar Alpha session. Clean tree, honest state log, handoff a cold chat can resume. Use at end of a long run or before context dies. /wrap
---

# Close out and hand off

The next session is a stranger. Everything it needs must be on disk.

## Step 1 — Land the tree

```
powershell -ExecutionPolicy Bypass -File scripts/lint.ps1
git status --short
```

Fix red or record the exact failure. Commit or explicitly mark half-finished.

## Step 2 — Reconcile claims vs truth

Downgrade anything that did not survive red-green proof. Append journal corrections;
never rewrite history.

## Step 3 — Journal close

```
python scripts/journal.py add NOTE "Session close: <one line>" --detail "..."
```

## Step 4 — Update `docs/state.md`

Keep it short: current position, open decisions, standing decisions, **next
session starts here** (numbered, first item actionable cold).

## Step 5 — Amend Alpha docs if reality moved them

Version-bump. Docs and code must not diverge.

## Step 6 — Commit and push

Remote backup: `https://github.com/elmillgoa/Draywar-Alpha` (`origin/main`).

```
git push
git status -sb
```

A session that ends unpushed leaves everything since the last push on one machine only.

## Report to Elliot

> **Done this session:** …
>
> **Not finished:** …
>
> **Waiting on you:** …
>
> **Next chat:** `/start` picks up at [contract]
