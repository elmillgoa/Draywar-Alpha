# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **S0 complete** (Steam plan frozen). **S1 not started** (Elliot: do not build until outside review lands). Maturity = **tech demo**.

| Doc | Role |
|-----|------|
| `docs/STEAM_PHASE_PLAN.md` | **Build queue S0–S10** — accepted 2026-08-02 |
| `docs/PRODUCT_DIRECTION.md` | Steam 1.0 intent locks |
| `docs/reputation_and_standing.md` | Standing law |
| `docs/gates.md` | E6.6 signed; Steam gates TBD |

## Phase progress

| Phase | Status |
|-------|--------|
| E1–E6 (project labels) | **closed** — tech-demo shell |
| **S0** Plan freeze | **done** 2026-08-02 |
| Outside review (Fable / Claude Code) | **in flight** — read-only; no code from that pass |
| **S1** World clock & sim foundation | **blocked** until review absorbed + plan amended if needed |
| S2–S10 | queued after S1 |

## What the game can do now

- Thin career shell: open, fly, dock, jobs, static trade, standing, combat, multi-system map, lived-in solids/sky/traffic.
- **Not yet:** world clock, economy sim, radiant jobs, Ops, campaign spine, Holding.

## Next session starts here

1. **`/start`** — orient from this file + Steam plan. Confirm no S1 code started.
2. **Ingest Fable findings** Elliot pastes (outside review of product + plan + codebase sample). Read-only review was commissioned; findings live in chat until written to disk.
3. **Amend plan if needed** — update `docs/STEAM_PHASE_PLAN.md` (and PRODUCT_DIRECTION only if product locks change). Journal the review outcome.
4. **Only after Elliot says go:** implement **S1** (world clock & sim foundation). Do **not** freestyle S2+ or Ops/Holding.
5. No invented standing rules.

### Cold-chat checklist for Fable handoff

When Elliot pastes the review, the agent should:
- Summarize Top 5 + blockers in plain English
- Propose concrete plan patches (accept / reject with Elliot)
- Write accepted amendments into `docs/STEAM_PHASE_PLAN.md`
- Update this state file: review absorbed → S1 unblocked or still blocked
- **Not** start S1 unless Elliot explicitly says build/go

## Standing decisions

- Steam plan **accepted** 2026-08-02 (subject to outside-review amendments before S1).
- Campaign through debts + Holding → sandbox; real economy sim; 30h/80h; space Skyrim under Freelancer filters.
- Story + dynamic economy unlocked for Steam plan only.
- E6.6 signed; product still thin.
- **No S1 code until review lands and Elliot green-lights build.**

## Session history

- **2026-08-02 (wrap)** — S0 docs committed; Fable review pending; S1 blocked; handoff for new chat + findings.
- **2026-08-02 (S0)** — Steam product plan accepted; AGENTS authority → Steam queue.
- **2026-08-02 (product bar)** — E6.6 signed; PRODUCT_DIRECTION locked.
- **2026-08-02 (E6)** — Lived-in space closed.
- **2026-07-31–08-02** — E1–E5 closed.
