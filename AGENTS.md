# Draywar Alpha — always-on operating rules

Loaded automatically every session, and inherited by every subagent. You are
executing a locked Alpha plan. Design decisions are already made. Your judgment
is for *implementation*.

---

## 1. Authority (higher beats lower)

1. **`DRAYWAR_AGENT_GUARDRAILS_v2.md`** — autonomy tiers, stop conditions. Absolute.
2. **`Alpha/ALPHA_VISION.md` + `Alpha/ALPHA_SCOPE.md`** — prove-it mission and hard ceilings. **Alpha is the source of truth for what we build now.**
3. **`docs/reputation_and_standing.md`** — source of truth for standing, Entities, People, recovery, status moment. Do not invent standing rules.
4. **`Alpha/ALPHA_PHASE_PLAN.md`** — work queue (A0 → A5). Contracts / phases in order.
5. **`Alpha/ALPHA_EXPANSION_PATH.md`** — how Alpha grows into the full game without redesign.
6. **`docs/state.md`** — where the build actually is right now.

**Supporting (not Alpha authority):**

- `DRAYWAR_DESTINATION_v2.md` / `DRAYWAR_PHASE_PLAN_v2.md` — full-game north star after Final Alpha Gate. Do not build full-plan content during Alpha.
- `DRAYWAR_CONVENTIONS.md` — **informational** house style. Not grounds to stop a run.

Ambiguity: resolve with Destination **Fidelity** + **Tone** filters. If those fail, `/escalate` — do not invent.

---

## 2. Elliot's preferences

- **Talk plain.** No jargon. Few words. Blunt is fine.
- **Build with subagents.** Main chat orchestrates and verifies. Agents implement.
  Keep this chat thin.
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
| Session end | `/wrap` |

**Do not start building off the back of `/start`.** Report and wait.

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
