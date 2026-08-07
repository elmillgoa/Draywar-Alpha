# DRAYWAR — Agent Guardrails

**Version:** 2.0 (updated 2026-07-29)  
**Applies to:** Any agent executing the Draywar phase plan.  
**Reading order on session start:** This file → `DRAYWAR_CONVENTIONS.md` → `docs/STEAM_PHASE_PLAN.md` (the live build queue) → `docs/PRODUCT_DIRECTION.md` → `docs/reputation_and_standing.md` → `DRAYWAR_DESTINATION_v2.md` → `docs/state.md`.

---

## 1. The operating contract

You are executing a locked plan, not designing a game. Elliot has already made the design decisions. The Destination document and the Reputation & Standing design document are the sources of truth. Your judgment is for *implementation*. Where the plan is silent, resolve with the two filters (Fidelity · Tone). Where the filters don't resolve it, stop and ask.

**Elliot's standing preferences:** fix obvious bugs without asking; gate anything irreversible; never drive design reviews — present findings and options, he decides. Direct communication, no hedging, KISS.

---

## 2. Autonomy tiers

**Act freely:**
- Implement contracts in phase order per their specs.
- Fix bugs, refactor within conventions, add tests, improve performance.
- Tune values in the balance/constants files.
- Write and update docs in `/docs`, including the state log.
- Create placeholder/gray-box art and programmer audio stubs.

**Act, then report:**
- New file or scene structure beyond documented layout.
- New EventBus signal (update catalog in same commit).
- Deviating from a contract's notes for a concrete technical reason.
- Marking a contract complete.

**STOP and ask Elliot before acting:**
1. Anything touching a human gate.
2. Save schema changes after P0.4.
3. Adding any dependency or third-party asset.
4. Anything that spends money or creates accounts.
5. Scope changes: adding/removing/reinterpreting contracts, building deferred items, exceeding content budgets, reopening LOCKED decisions.
6. The two filters conflict or fail to resolve an ambiguity with non-trivial consequences.
7. **Phase 4 architecture:** Before implementing P4.1–P4.3, confirm that work matches `docs/reputation_and_standing.md`. If a needed data shape or resolution rule is missing or ambiguous, stop and ask. Do not invent standing rules.
8. Cutting content to make a deadline or criterion pass.

---

## 3. Definition of done

A contract is complete only when all hold:
1. Every acceptance criterion demonstrably passes.
2. Strict typing and lint pass.
3. All new tunables live in balance/constants files.
4. All content added via the data pipeline.
5. Cross-system communication is EventBus-only; catalog current.
6. Save/load round-trips any new persistent state.
7. Tests pass headless.
8. `/docs/state.md` updated.

---

## 4. Session discipline

- Start: read state log, confirm current contract, restate acceptance criteria.
- Work: one contract at a time.
- End: state log updated, tests green, clean commit with contract-ID-prefixed message.
- **Phase complete:** automatically commit, run `/wrap` (push), and end with the
  exact last line `Chat ready to close.` Do not wait for Elliot to ask. Human
  gates still block phase close until signed.
- Honesty rule: report what is actually true.

---

## 5. Quality bars

- Performance budget: 60 fps with 12 active ships on mid-range hardware.
- The interlock law (Hauler cannot beat a fighting Fighter) remains a permanent test.
- **The signature status moment is protected:** the system-entry (and station-entry) standing display may never be removed, hidden by default, or made unreliable.

---

## 6. When the plan and reality disagree

Implement nothing. Write a short note (what the plan says, what reality says, 2–3 options with consequences). Put it in front of Elliot. He decides. Docs are then amended so docs and code never diverge.

---

*The empire fell. The contracts didn't. Neither do these.*
