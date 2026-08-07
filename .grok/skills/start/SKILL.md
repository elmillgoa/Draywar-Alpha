---
name: start
description: Get up to speed at the beginning of a Draywar session. Loads live Steam authority docs and the state log, verifies the toolchain, restates the current contract, and reports in plain English. Use at the start of every new chat, or when resuming after a long gap. /start
---

# Get up to speed (Steam plan)

A fresh chat knows nothing. Orient in one pass without dragging forty files into
the main conversation.

**Cost control:** delegate heavy reading to a subagent. The main chat should end
holding a short briefing.

---

## Step 1 — Read the state log yourself

Read `docs/state.md` directly. It drives everything below.

If it does not exist, this is session one: say so, create it, and follow
`docs/STEAM_PHASE_PLAN.md` from current position (do not invent a phase).

**Do not read `docs/journal/` wholesale.** Search only for a specific question
(especially *"has Elliot already decided this?"*).

Open this session's journal:

```
python scripts/journal.py new-session "<what this session is about>"
```

## Step 2 — Send one agent to load the plan

Spawn a read-only or general-purpose agent:

> Read in order: `AGENTS.md`, `DRAYWAR_AGENT_GUARDRAILS_v2.md`,
> `docs/STEAM_PHASE_PLAN.md`, `docs/PRODUCT_DIRECTION.md`,
> `docs/reputation_and_standing.md` (standing sections only if current work is
> standing). Return a compact briefing:
>
> 1. Current contract from `docs/state.md`: ID/name, scope, acceptance criteria
>    **quoted verbatim**.
> 2. Dependencies and whether state says they are complete.
> 3. Any human gate between last complete work and this contract.
> 4. Likely stop conditions (scope ceiling, standing ambiguity, new dependency).
> 5. Which Steam plan / reputation sections govern.
>
> Quote acceptance criteria exactly. Do not implement anything.
>
> Historical only (not the work queue): `Alpha/*`, closed E-phases, old phase
> sketches. Do not treat them as current authority.

## Step 3 — Verify the toolchain

```
python scripts/checkin.py --deep
```

If tools are missing, restore from `docs/tooling.md` / `README.md`.

Confirm `git status --short` (if repo exists). Dirty tree: understand before adding.

## Step 4 — Sanity-check ground truth

- Does state match git / the tree?
- Does anything state claims passes still pass?

---

## Report to Elliot

Plain English, short:

> **Where we are:** [what the game can do]
>
> **Everything still works:** [checks pass / exactly what's broken]
>
> **Next up:** [contract] — [one sentence]
>
> **What it needs to satisfy:** [criteria in plain English, not softened]
>
> **Anything in the way:** [gates, stops, or "nothing"]

**Boot ends at the report.** Findings are not permission to start. Stop and wait.

**One-line rule before writing code later:** restate current acceptance criteria
in a single line. If you cannot, you are not ready.
