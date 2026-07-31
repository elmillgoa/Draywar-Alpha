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

## Borrowed from prior Draywar work

GUT, gdtoolkit workflow, boundary/magic-number/globals checkers, journal helper, MCP Pro layout, and session skills were adapted from the earlier Claude-era project. **Code and design authority start over here under Alpha docs.**
