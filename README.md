# Draywar

*The empire fell. The contracts didn't.*

Steam 1.0 product path for Draywar: jurisdictional identity, recovery, economy,
Ops, campaign, Holding. Built in Godot 4.6.x. The **Steam phase plan** (S0–S10)
is the live work queue; prove-it Alpha docs under `Alpha/` are historical only.

---

## Read these first

| Document | Role |
|----------|------|
| `AGENTS.md` | Always-on rules for agents |
| `DRAYWAR_AGENT_GUARDRAILS_v2.md` | Autonomy and stop conditions |
| `docs/STEAM_PHASE_PLAN.md` | S0 → S10 work queue (what we build now) |
| `docs/PRODUCT_DIRECTION.md` | Steam 1.0 intent locks |
| `docs/reputation_and_standing.md` | Standing system law |
| `docs/state.md` | Where the build is right now |

Historical (not the work queue): `Alpha/*`, closed E-phases, old phase sketches.

---

## Quick commands

```powershell
# Static gates
powershell -ExecutionPolicy Bypass -File scripts/lint.ps1

# Tests
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1

# Session facts
python scripts/checkin.py
python scripts/checkin.py --deep
```

Godot (console): `C:\Godot\Godot_v4.6.1-stable_win64_console.exe`

---

## Layout

```
src/           Game code (systems, entities, ui, data, world)
addons/gut/    Test framework (committed)
addons/godot_mcp/  MCP Pro plugin (local only, gitignored)
scripts/       Lint, tests, journal, checkin
docs/          State, Steam plan, events, tooling, journal
Alpha/         Historical prove-it Alpha docs (closed)
.grok/skills/  Session skills (start, work, verify, …)
```

---

## Grok Build

- Open this folder as the workspace.
- Skills under `.grok/skills/` — use `/start` at the beginning of every session.
- Godot MCP: `.mcp.json` + `.grok/config.toml`; editor must be open with the plugin enabled.
