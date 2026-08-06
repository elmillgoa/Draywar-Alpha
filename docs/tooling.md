# Tooling setup

Everything needed to work on Draywar Alpha. None of this ships.

---

## Godot

**4.6.1-stable, standard build (not .NET).** Installed at `C:\Godot\`.

Use the **console** binary from terminals:

```
C:\Godot\Godot_v4.6.1-stable_win64_console.exe
```

The non-console binary detaches stdout and prints nothing, which reads as a silent success.

**Do not upgrade the engine without asking Elliot.**

### Headless project check

```
C:\Godot\Godot_v4.6.1-stable_win64_console.exe --path . --headless --quit-after 1
```

## Godot MCP Pro

**Installed (local only — not in git):**

- Server: `C:\Godot\godot-mcp-pro\server\build\index.js`
- Project addon: `addons/godot_mcp/` (gitignored)
- Grok / Claude config: `.grok/config.toml` and `.mcp.json`

**To use:** open this project in the Godot editor with the Godot MCP Pro plugin enabled. The MCP server talks to the editor over WebSocket (default port 6505).

**After a fresh clone you must enable the plugin once**, via Project > Project Settings > Plugins > Godot MCP Pro. This is deliberate: `project.godot` no longer commits the plugin entry or its three `MCP*` autoloads, because they point into the gitignored `addons/godot_mcp/` and made every fresh clone fail to boot with nine autoload errors. The plugin injects those autoloads itself when it starts and removes them when it stops, so nothing needs committing — and CI now fails the build if `addons/godot_mcp` reappears in `project.godot`. See `docs/traps.md` #24.

**If the addon is missing:** copy from `C:\Godot\godot-mcp-pro` packaging or from the purchased zip; do not commit it.

## Strict typing

`project.godot` `[debug]` block sets gdscript typing/correctness warnings to **error** (level 2). Godot rewrites `project.godot` and strips comments — document intent here.

After any editor rewrite of `project.godot`, re-prove enforcement: a deliberately untyped script must make lint fail.

## Lint and formatting

gdtoolkit in project `.venv/`:

```
python -m venv .venv
.venv\Scripts\python.exe -m pip install "gdtoolkit==4.*"
```

```
powershell -ExecutionPolicy Bypass -File scripts/lint.ps1
```

Gates: strict typing · gdlint · gdformat --check · architecture · balance · globals (later gates no-op cleanly until their scripts have enough project surface).

## Tests

GUT is committed under `addons/gut/`.

```
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
```

## Journal

```
python scripts/journal.py new-session "topic"
python scripts/journal.py add NOTE "…" --detail "…"
```

## Git remote

```
origin  https://github.com/elmillgoa/Draywar-Alpha.git
branch  main
```

Push at end of session (`/wrap`). Do not force-push `main` without asking Elliot.

---

## Memory system (session safety)

**Problem:** long chats get compressed. The model does not notice. It then writes
a confident, wrong progress log. Prompting "remember to wrap" does not catch that.

**Fix:** four files + three harness hooks (same design as the earlier Draywar project).

### Four records

| File | Question |
|------|----------|
| `docs/state.md` | Where are we now? |
| `docs/journal/` | Why is it like this? |
| `docs/traps.md` | What gives a silent wrong answer? |
| `docs/eras.md` | Which era does an old note belong to? |

### Hooks

Configured in `.grok/hooks/memory-system.json`. Scripts in `scripts/hooks/`.

| Hook | When | Does |
|------|------|------|
| `session_start.py` | New session | Reads position from `state.md`; warns if uncommitted/unpushed |
| `pre_compact.py` | About to compress chat | Warns you; tells agent to write status, commit, push, stop starting new work |
| `post_compact.py` | After compress | Tells agent memory is incomplete; re-read `state.md` |

All three never fail (catch exceptions). A broken hook is worse than no hook.

**Trust the project folder** once so project hooks run (`/hooks-trust` if asked).

**Hooks do not replace `/wrap`.** They are the safety net.

Quick self-test:

```
python scripts/hooks/session_start.py
python scripts/hooks/pre_compact.py
python scripts/hooks/post_compact.py
```

Each should print a JSON blob and exit 0.

## Borrowed from prior Draywar work

GUT, gdtoolkit workflow, boundary/magic-number/globals checkers, journal helper, MCP Pro layout, and session skills were adapted from the earlier Claude-era project. **Code and design authority start over here under Alpha docs.**
