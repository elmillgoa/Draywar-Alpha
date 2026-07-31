# Draywar Alpha

*The empire fell. The contracts didn't.*

Greenfield **prove-it** slice of Draywar: jurisdictional identity + personal recovery.
Built in Godot 4.6.x. Alpha docs govern; the full game is the destination after the Final Alpha Gate.

---

## Read these first

| Document | Role |
|----------|------|
| `AGENTS.md` | Always-on rules for agents |
| `DRAYWAR_AGENT_GUARDRAILS_v2.md` | Autonomy and stop conditions |
| `Alpha/ALPHA_VISION.md` | Why Alpha exists |
| `Alpha/ALPHA_SCOPE.md` | Hard ceilings |
| `Alpha/ALPHA_PHASE_PLAN.md` | A0 → A5 work queue |
| `docs/reputation_and_standing.md` | Standing system law |
| `docs/state.md` | Where the build is right now |

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
docs/          State, events, tooling, journal
Alpha/         Alpha authority documents
.grok/skills/  Session skills (start, work, verify, …)
```

---

## Grok Build

- Open this folder as the workspace.
- Skills under `.grok/skills/` — use `/start` at the beginning of every session.
- Godot MCP: `.mcp.json` + `.grok/config.toml`; editor must be open with the plugin enabled.
