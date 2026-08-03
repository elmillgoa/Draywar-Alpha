# Draywar — always-on operating rules

Loaded automatically every session, and inherited by every subagent. You are
executing a locked **Steam 1.0 product plan**. Design decisions are already
made. Your judgment is for *implementation*.

**Maturity:** tech demo → core complete (real Alpha) → content complete (real
Beta) → polish. Do not call the current build industry Alpha/Beta.

---

## 1. Authority (higher beats lower)

1. **`DRAYWAR_AGENT_GUARDRAILS_v2.md`** — autonomy tiers, stop conditions. Absolute.
2. **`docs/STEAM_PHASE_PLAN.md` + `docs/PRODUCT_DIRECTION.md`** — **what we build now** (S0–S10). Campaign through Holding → sandbox; real economy sim; 30h/80h.
3. **`docs/reputation_and_standing.md`** — standing, Entities, People, recovery, status moment. Do not invent standing rules.
4. **`DRAYWAR_DESTINATION_v2.md`** — Fidelity / Tone filters + locked fantasy spine (Ship → Ops → Holding). Story campaign + dynamic economy are **unlocked** for the Steam plan (were deferred).
5. **`docs/state.md`** — where the build actually is right now.

**Historical (do not use as the work queue):**

- `Alpha/*` — prove-it Alpha (done).
- `docs/BETA_*.md` / `docs/BETA_ROADMAP.md` — post-Alpha E-phases (E1–E6 closed).
- `DRAYWAR_PHASE_PLAN_v2.md` — old full-game phase sketch; superseded by Steam phase plan for sequencing.

Ambiguity: resolve with Destination **Fidelity** + **Tone** filters. If those fail, `/escalate` — do not invent.

---

## 2. Elliot's preferences

- **Talk plain.** No jargon. Few words. Blunt is fine.
- **Build with subagents.** Main chat orchestrates and verifies. Agents implement.
  Keep this chat thin.
- **Elliot does not program.** He playtests and decides product ideas. All code is LLM work.
- **Model routing:** `docs/STEAM_PHASE_PLAN.md` §22 — which model tier per phase, when to tell
  him to switch, paste-ready kickoff prompts. Do not freestyle model advice; follow §22.
- **Full phase per go.** When Elliot says go on a phase (e.g. "go on Phase 0" /
  A0), finish **the whole phase** before stopping. Ask every blocking question
  **before** building. Same rule for every phase. Human feel **gates** still
  wait for him when the phase plan marks a gate — that is not a mid-phase stop.
- **Phase end = commit + wrap, automatic.** When a phase is complete (definition
  of done, adversary/verify as required, state updated; any plan-marked human
  gate signed or not required), do **not** wait for him to say wrap. Commit,
  run `/wrap` (includes push), then end. The **last line** of that final
  message must be exactly: `Chat ready to close.`
  If a human gate is still open, stop after the gate report — wrap only once
  the phase is actually closed.
- Fix obvious bugs without asking.
- Gate anything irreversible.
- Never drive design reviews — options and findings; he decides.
- Reports: what the game can *do*, not file lists.

---

## 3. Autonomy (summary)

**Act freely:** implement current phase work, fix bugs, tests, tune balance constants, update `docs/`, placeholder art.

**Act, then report:** new layout beyond docs, new EventBus signals (catalog same commit), technical deviations from a contract note, marking a contract complete.

**STOP and ask:** human gates; save schema after A0 save lands; new dependencies/assets; money/accounts; scope changes / deferred full-game items; standing rules not in the reputation doc; cutting content to pass a criterion.

Full list: `DRAYWAR_AGENT_GUARDRAILS_v2.md`.

---

## 4. Definition of done

A contract is complete only when all hold:

1. Every acceptance criterion demonstrably passes (named evidence).
2. Strict typing and lint pass (`scripts/lint.ps1`).
3. All new tunables live in balance/constants files.
4. Content via the data pipeline.
5. Cross-system communication EventBus-only; `docs/events.md` current.
6. Save/load round-trips new persistent state (once save exists).
7. Tests pass headless.
8. `docs/state.md` updated.

Before calling done: run **adversary** (where applicable) then **verify**.

---

## 5. Memory system (four records + hooks)

**Not Grok “AI memory.”** Disk is truth. Trust files over chat recollection.

| Record | Job |
|--------|-----|
| `docs/state.md` | Where are we **now**? Short. Rewritten. Every session. |
| `docs/journal/` | **Why** is it like this? Append-only. Search, never dump whole. |
| `docs/traps.md` | What lies silently? Permanent. |
| `docs/eras.md` | Which epoch does an old note belong to? |

**Harness hooks** (`scripts/hooks/`, `.grok/hooks/memory-system.json`):

- **Session start** — real position from `state.md`; warn if dirty/unpushed.
- **Before compact** — write status, commit, push; do not start new work.
- **After compact** — memory incomplete and will not feel it; re-read `state.md`.

Hooks are the floor. They do **not** replace `/wrap`.
Between contracts, re-read `docs/state.md`. Never start work you cannot finish and record.

## 6. Session ritual

| When | Skill / action |
|------|----------------|
| Session start | `/start` — orient, toolchain, restate contract, **stop** |
| Build | `/work` — one contract; **subagents build** |
| Before complete | `/adversary` then `/verify` |
| Human feel gates | `/gate` (A1 flight, A4 recovery, Final Alpha) |
| Plan vs reality | `/escalate` — implement nothing while open |
| Phase complete | Commit + `/wrap` + push — **automatic** (do not wait for "wrap") |
| Session end | `/wrap` (also used mid-session if room dies) |

**Do not start building off the back of `/start`.** Report and wait.

**Phase close-out closing line:** after automatic wrap, the final message's last
line is exactly:

```
Chat ready to close.
```

---

## 7. Architecture non-negotiables (even at Alpha scale)

- **No global alignment.** Standing is per-Entity; enforcement only where they have reach.
- **Status moment protected.** System entry and station entry show local controller standing. Never remove, hide by default, or make unreliable.
- **Standing service is the single writer.** Mutations only through that service + EventBus.
- **Data shapes are full-sized.** Tiny content, full fields (see Alpha expansion path).
- **Strict typing.** Godot 4.6.1. Engine path: `C:\Godot\Godot_v4.6.1-stable_win64_console.exe`.
- **Performance budget:** 60 fps with 12 active ships (later phases).

---

## 8. Alpha ceilings (hard)

| Element | Cap |
|---------|-----|
| Systems | 3–4 |
| Entities | 4–6 |
| People | 12–18 |
| Recovery chains | 1 |
| Contract types | 2–3 |

If a task would exceed these, stop and ask. `/alpha-scope` encodes this.

---

## 9. Tooling

- Godot: see `docs/tooling.md`
- Lint: `powershell -ExecutionPolicy Bypass -File scripts/lint.ps1`
- Tests: `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`
- Check-in: `python scripts/checkin.py` / `--deep`
- Journal: `python scripts/journal.py …`
- Godot MCP Pro: editor open + plugin enabled; config in `.mcp.json` and `.grok/config.toml`

---

*The empire fell. The contracts didn't. Neither do these.*
