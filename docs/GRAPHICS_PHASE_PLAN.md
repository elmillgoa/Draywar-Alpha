# Draywar Graphics Pass — Implementation Plan (roadmap + G0 in full detail)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute the approved graphics pass (`docs/GRAPHICS_PASS_DESIGN.md`) —
this file carries the full-pass roadmap and the complete step-by-step plan for
**Phase G0 (Foundation)**. Later phases get their own detailed plan written at
their phase boundary (see "Planning policy" below).

**Architecture:** G0 changes the display pipeline to a 1920×1080 logical canvas
with `canvas_items` stretch (windowed default stays 1152×648), scales the UI
constants to match, builds the repeatable frame-time instrument the whole pass
measures against, and creates the asset folder + license ledger. No art lands
in G0.

**Tech Stack:** Godot 4.6.1 (`C:\Godot\Godot_v4.6.1-stable_win64_console.exe`),
GUT test framework (committed at `addons/gut/`), gdtoolkit lint/format via
`.venv`, Python gate scripts.

## Global Constraints

Copied from `docs/GRAPHICS_PASS_DESIGN.md` §4 and repo conventions — every task
implicitly includes these:

- Pass starts **only after the fix pass closes** (check `docs/state.md` first).
- All gates green at every commit: `scripts/lint.ps1` (8 gates incl. strict-type
  re-parse, boundaries, magic numbers, globals, groups) and `scripts/run_tests.ps1`
  (import → boot smoke → GUT, `MinTests = 800`).
- Strict typing everywhere: untyped `var` is a parse error; GUT silently drops
  untyped test files — type every declaration.
- Tunables live in `src/data/balance/` files, never inline (magic-number gate).
- `docs/state.md` updated per contract; journal entry per contract via
  `python scripts/journal.py add CONTRACT "..." --detail "..."`.
- Commit messages: `G0: <what the game can now do>` (player-visible statement,
  not file lists).
- **Never commit the godot-mcp autoloads** (`MCPScreenshot`, `MCPInputService`,
  `MCPGameInspector`, `res://addons/godot_mcp/plugin.cfg` lines in
  `project.godot`). CI hard-fails on them. The working tree is currently dirty
  with exactly these — stage `project.godot` hunk-by-hunk or close the editor
  before committing it.
- Accessibility invariant: standing tiers stay color + glyph + word; guarded by
  existing tests — do not touch `BalanceStanding.tier_color()`.
- 20-ship performance budget; measurements use the instrument built in Task 2.
- No paid spend of any kind in G0.
- Feel/style gates are signed by Elliot only.

## Planning policy for G1–G8 (why they are not step-planned here)

G1's tasks depend on which image-to-3D tool wins the bake-off; G2–G8 depend on
G1's proven import pattern and Elliot's style signature. Step-level plans
written today for those phases would be invented detail. **At each phase
boundary, a Claude session writes `docs/GRAPHICS_G<N>_PLAN.md` at the same
detail level as the G0 plan below, from the facts that exist by then.** The
roadmap that binds them is `docs/GRAPHICS_PASS_DESIGN.md` §6 (phase contents
and gates) and §8 (staffing: Claude for judgment and invariant-touching work,
Grok for proven-pattern repetition; sort by risk, not type).

| Phase | Plan written | Built mainly by |
|---|---|---|
| G0 Foundation | **below, in full** | Claude |
| G1 Slice + style gate | at G0 close | Claude (all judgment) |
| G2 Fleet | at G1 signature | Claude leads; Grok repeats proven per-entity pattern |
| G3 World | at G2 close | Claude leads; Grok repeats per-system pattern |
| G4 Effects | at G3 close | Claude (time-scale/pause invariants) |
| G5 Interface | at G4 close | Claude theme work; Grok per-screen sweep |
| G6 Sound | at G5 close | Claude wiring; Grok per-sound data entry |
| G7 Paint shop | at G6 close | Claude (save/economy invariants) |
| G8 Identity + close | at G7 close | Claude + Elliot's tools for 2D art |

---

# Pre-pass job: the bake-off (runs DURING the fix pass — no game code)

Sanctioned by Elliot 2026-08-08 as the one piece of the pass that starts before
the fix pass closes, because it touches no code and retires the pass's biggest
unknown: **can image-to-3D generation reproduce his reference style?**

**Hard rules:** no file outside `docs/` is created or modified. No spend
without asking Elliot with the price. Sessions never create accounts — if a
tool needs a login, Elliot signs up and the session guides or drives the
browser afterward.

**Inputs:** Elliot's reference images in `docs/art_direction/` (his action
item — the bake-off cannot start without them).

**Procedure:**
1. Take the primary hauler reference image (three-quarter view preferred).
2. Generate a hauler model attempt with each of, in this order:
   - **Hyper3D Rodin** via the installed Blender bridge (free preview mode).
   - **Meshy** free tier (web — Elliot creates the free account when asked).
   - **Tripo** free tier (web — same).
3. Import each result into Blender via the bridge. Render each from the same
   four angles (3/4 front, side, top, rear) on a neutral background.
4. Score each against these criteria, in this priority order:
   a. **Silhouette fidelity** — does it read as the reference ship?
   b. **Surface quality** — panels, rivets, worn paint in the textures?
   c. **Cleanup cost** — topology sanity, watertightness, polygon count after
      decimation vs the spec's ≤15k budget, UV/material state.
   d. **License clarity** of the tool's paid tier (spec §7 table).
5. Deliverables, committed under `docs/art_direction/bakeoff/`:
   side-by-side renders, a plain-language scorecard, a recommendation naming
   the winner and its monthly price (~$20–30), and an honest verdict on the
   fallback question — if ALL three disappoint, say so and recommend the
   hand-model-in-Blender fallback (spec §9 row 1) instead of overselling.
6. Elliot picks the winner. The paid month is NOT bought now — it gets bought
   at G1 start, so the 30 days cover the real generation workload.

**Kickoff prompt (paste into a new Claude Code chat opened in the
`Grok Draywar` folder, model Opus 5 or the top tier offered):**

```
Run the graphics-pass bake-off (pre-pass job — the fix pass is still running, touch no game code).

Read docs/GRAPHICS_PHASE_PLAN.md section "Pre-pass job: the bake-off" and follow it exactly. Also read docs/GRAPHICS_PASS_DESIGN.md sections 2, 5.2 and 7 for the style bar, pipeline and license context.

Confirm docs/art_direction/ contains the reference images first; if not, stop and ask me. Free tiers only; ask me with the price before any spend; ask me before anything needing an account signup. Only files under docs/ may be created or changed.

Close by presenting the side-by-side renders, the scorecard, and your recommendation for my pick.
```

---

# Phase G0 — Foundation (full plan)

**Branch:** `g0-foundation` off `main` (design doc: each phase on its own
branch, merged when its gate passes).

**Phase gate (from spec §6):** all tests green; Elliot confirms the game still
plays right at the new window sizes. Elliot's confirmation closes the phase.

## Preconditions (verify before Task 1 — stop if any fail)

- [ ] `docs/state.md` records the fix pass as closed. If not: **stop, do nothing.**
- [ ] `docs/art_direction/` exists and contains Elliot's 8 reference images
      (hauler multi-angle set, fighter, cockpit mood, hangar mood). This is
      Elliot's own action item from the spec (§10.1). If absent: ask Elliot via
      AskUserQuestion, continue with Tasks 1–2 (they don't need images), but do
      not close the phase without them — G1 cannot start.
- [ ] `git status` on `project.godot`: note the uncommitted MCP autoload lines;
      they must never be staged.
- [ ] Create the branch:

```bash
git checkout -b g0-foundation
```

## File structure (G0 footprint)

| File | Action | Responsibility |
|---|---|---|
| `src/systems/perf/PerfProbe.gd` | Modify | add physics frame-time sampler (instrument) |
| `tests/test_g0_perf_probe.gd` | Create | sanity coverage for the sampler |
| `docs/PERF_BASELINES.md` | Create | baseline numbers + the repeatable procedure |
| `assets/` + 7 subfolders | Create | asset home (empty, `.gitkeep`s) |
| `assets/README.md` | Create | import conventions |
| `docs/ASSET_LICENSES.md` | Create | license ledger (audit trail for Steam) |
| `project.godot` `[display]` | Modify | 1080p canvas, stretch, windowed override |
| `src/data/balance/BalanceUi.gd`, `BalanceSettings.gd`, `BalanceFlight.gd`, `BalanceCombat.gd` | Modify | UI constants scaled to the 1080p canvas |
| `tests/test_g0_viewport_fit.gd` | Create | 1080p fit tests for the 5 unclamped panels |
| 0–5 of `MainMenu.gd`, `PauseMenu.gd`, `OptionsMenu.gd`, `CampaignJournal.gd`, `SectorMapPanel.gd` | Modify only if a fit test fails | `_fit_panel_to_viewport()` hook (REPAIR-19 pattern) |
| `docs/state.md`, `docs/journal/` | Modify/append | per-contract records |

---

### Task 1: Frame-time instrument (PerfProbe sampler)

**Files:**
- Modify: `src/systems/perf/PerfProbe.gd` (currently two FPS statics)
- Test: `tests/test_g0_perf_probe.gd` (new)

**Interfaces:**
- Consumes: `Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)` (Godot
  built-in, seconds per physics step), `SceneTree.process_frame`.
- Produces: `PerfProbe.sample_physics_ms(tree: SceneTree, frame_count: int) -> float`
  (awaitable; average milliseconds per physics step over `frame_count` frames).
  Tasks 6 and every later phase's measurement depend on this exact name and
  signature.

- [ ] **Step 1: Write the failing test**

Create `tests/test_g0_perf_probe.gd` (tabs, strict types — untyped code is
silently dropped by GUT):

```gdscript
extends GutTest
## Implements: docs/GRAPHICS_PHASE_PLAN.md Phase G0 Task 1.
## Sanity only — never asserts absolute performance (machine variance),
## matching tests/test_s5_perf_measure.gd's stance.

const FRAME_SAMPLE: int = 6


func test_sample_physics_ms_is_nonnegative_and_sane() -> void:
	var ms: float = await PerfProbe.sample_physics_ms(get_tree(), FRAME_SAMPLE)
	assert_gte(ms, 0.0, "sampler must return a measurable value")
	assert_lt(ms, 1000.0, "a physics step cannot take a full second")


func test_sample_physics_ms_single_frame() -> void:
	var ms: float = await PerfProbe.sample_physics_ms(get_tree(), 1)
	assert_gte(ms, 0.0, "single-frame sampling must not divide by zero or crash")
```

- [ ] **Step 2: Run it to verify it fails**

```bash
C:\Godot\Godot_v4.6.1-stable_win64_console.exe --path . --headless -s "res://addons/gut/gut_cmdln.gd" -gtest=res://tests/test_g0_perf_probe.gd -gexit
```

Expected: FAIL — `sample_physics_ms` not found on `PerfProbe`.

- [ ] **Step 3: Implement the sampler**

Add to `src/systems/perf/PerfProbe.gd` (below the existing FPS statics, same
house style):

```gdscript
## Average milliseconds per physics step over frame_count idle frames.
## Awaitable. Callers: G0 baseline and every later graphics-phase measurement
## (docs/PERF_BASELINES.md records the numbers).
static func sample_physics_ms(tree: SceneTree, frame_count: int) -> float:
	var frames: int = maxi(frame_count, 1)
	var total_ms: float = 0.0
	for _i: int in frames:
		await tree.process_frame
		total_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	return total_ms / float(frames)
```

- [ ] **Step 4: Run the test to verify it passes**

Same command as Step 2. Expected: PASS (2 tests).

- [ ] **Step 5: Create `docs/PERF_BASELINES.md`** with the procedure and an
      empty baseline table (filled in Task 6):

```markdown
# Performance baselines — graphics pass

Budget: 16.67 ms/frame (60 fps). Ship budget: 20 concurrent (BalanceEconomy.PERF_BUDGET_SHIPS).
Instrument: PerfProbe.sample_physics_ms (physics step) + PerfProbe.sample_average_fps.
Precedent: Job 11 measured TIME_PHYSICS_PROCESS, 12 ships + 24 bolts, 600 frames x 3 runs.

## Procedure (repeat per phase close)

1. Headless physics number: run the reporting test —
   `Godot_v4.6.1 --path . --headless -s "res://addons/gut/gut_cmdln.gd" -gtest=res://tests/test_g0_perf_probe.gd -gexit`
   (sanity only), then the densest-scene measure below.
2. Windowed (real rendering) numbers: open the editor, play the game via
   godot-mcp, reach system_beta (densest per tests/test_s5_perf_measure.gd),
   spawn combat traffic, read `get_performance_monitors` at 1x and at 16x.
3. Record: date, phase, scene, ship/bolt counts, physics ms at 1x and 16x,
   fps windowed at 1x and 16x, machine notes. Compare against this table.

## Baselines

| Date | Phase | Scene | Ships/Bolts | Physics ms 1x | Physics ms 16x | Windowed fps 1x | Windowed fps 16x |
| ---- | ----- | ----- | ----------- | ------------- | -------------- | --------------- | ---------------- |
| (filled by Task 6) | | | | | | | |

Pre-pass reference (Job 11, docs/state.md): 2.66 ms at 1x, 3.17 ms at 16x,
12 ships + 24 bolts, against 16.67 ms budget.
```

- [ ] **Step 6: Full local gates, then commit**

```bash
powershell -ExecutionPolicy Bypass -File scripts/lint.ps1
```

```bash
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
```

Expected: both PASS. Then:

```bash
git add src/systems/perf/PerfProbe.gd tests/test_g0_perf_probe.gd tests/test_g0_perf_probe.gd.uid docs/PERF_BASELINES.md
git commit -m "G0: frame-time is now measurable, not hand-timed"
```

(Godot generates the `.uid` sibling on import — commit it, house rule from
Job 4.)

- [ ] **Step 7: Journal + state**

```bash
python scripts/journal.py add CONTRACT "G0 Task 1: perf instrument" --detail "PerfProbe.sample_physics_ms added with sanity tests; PERF_BASELINES.md procedure written; baseline capture deferred to Task 6"
```

Update `docs/state.md` current-position section (rewrite, short).

---

### Task 2: Asset home + license ledger

**Files:**
- Create: `assets/models/.gitkeep`, `assets/textures/.gitkeep`,
  `assets/liveries/.gitkeep`, `assets/fonts/.gitkeep`, `assets/audio/.gitkeep`,
  `assets/ui/.gitkeep`, `assets/skybox/.gitkeep`
- Create: `assets/README.md`
- Create: `docs/ASSET_LICENSES.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the folder layout every later phase imports into, and the ledger
  every asset entry must update (spec §7: "updated every time an asset enters
  the repo: file, source, license, date").

- [ ] **Step 1: Create the folders + `.gitkeep`s** (PowerShell):

```bash
powershell -Command "'models','textures','liveries','fonts','audio','ui','skybox' | ForEach-Object { New-Item -ItemType Directory -Force \"assets/$_\" | Out-Null; New-Item -ItemType File \"assets/$_/.gitkeep\" | Out-Null }"
```

- [ ] **Step 2: Write `assets/README.md`:**

```markdown
# assets/ — conventions

- models/    GLB only, Y-up, forward = -Z (Godot convention), scaled to match
             the entity's existing collision dimensions before export.
- textures/  PBR sets (albedo/normal/roughness/metallic), source noted in ledger.
- liveries/  Livery .tres resources + mask textures.
- fonts/     TTF/OTF, license file alongside each family.
- audio/     OGG preferred, WAV for short SFX.
- ui/        Icons, hangar backdrops, logo.
- skybox/    Per-system sky resources.

Every file added here gets a row in docs/ASSET_LICENSES.md in the same commit.
No asset without a ledger row; no ledger row without a license verdict.
Ruled-out sources (spec §7): Hunyuan3D, TRELLIS.2, any Freesound file that is
not CC0, any free-tier generation output without explicit commercial rights.
```

- [ ] **Step 3: Write `docs/ASSET_LICENSES.md`:**

```markdown
# Asset license ledger

Audit trail for Steam. One row per asset file (or per pack). Added in the same
commit as the asset itself. "License verdict" is one of: CC0 / public domain,
OFL, paid-owned (invoice date), other-permissive (link the terms).

| File(s) | Source (URL) | License verdict | Date added | Added in commit |
| ------- | ------------ | --------------- | ---------- | --------------- |
| (none yet — G0 ships no assets) | | | | |
```

- [ ] **Step 4: Gates + commit**

Run `scripts/lint.ps1` and `scripts/run_tests.ps1` (both must PASS — this task
adds no code, so this is a regression check only), then:

```bash
git add assets docs/ASSET_LICENSES.md
git commit -m "G0: the game has a home for real assets and a license audit trail"
```

- [ ] **Step 5: Journal + state** (same pattern as Task 1 Step 7, message
      "G0 Task 2: asset home + ledger").

---

### Task 3: 1080p canvas ([display] section)

**Files:**
- Modify: `project.godot` (adds a `[display]` section — none exists today; the
  current 1152×648 is Godot's unwritten default)

**Interfaces:**
- Consumes: nothing.
- Produces: 1920×1080 logical canvas that every later phase's screenshots and
  UI work assume. Windowed default stays 1152×648 physical via override keys.

**Care points:** (a) The working tree's `project.godot` carries uncommitted MCP
autoload lines — stage this file's hunks selectively; never commit the MCP
lines. (b) `docs/tooling.md:43-45`: after any rewrite of `project.godot`,
re-prove warning enforcement.

- [ ] **Step 1: Add the section.** Preferred: with the editor open, use
      godot-mcp `set_project_setting` for each key (the plugin rewrites the
      file safely). Editor closed: edit the file directly — the repo has no
      rule against it. Keys and exact values:

```
display/window/size/viewport_width = 1920
display/window/size/viewport_height = 1080
display/window/size/window_width_override = 1152
display/window/size/window_height_override = 648
display/window/stretch/mode = "canvas_items"
display/window/stretch/aspect = "keep"
```

The resulting `project.godot` block must read:

```
[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/window_width_override=1152
window/size/window_height_override=648
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
```

- [ ] **Step 2: Boot smoke test**

```bash
C:\Godot\Godot_v4.6.1-stable_win64_console.exe --path . --headless --quit-after 2
```

Expected: exit 0, zero error lines.

- [ ] **Step 3: Windowed sanity (editor, human-eyes screenshot).** Run the game
      windowed: window opens at 1152×648; main menu visible; everything renders
      at ~60% of its former physical size (expected — Task 4 fixes scale).
      Toggle the **existing** fullscreen option (Options → Fullscreen) on and
      off: fullscreen fills the display, windowed returns to 1152×648. The
      toggle, persistence, and its tests already exist from S10
      (`SettingsService.set_fullscreen`, `test_s10_settings.gd:67,87`) — G0
      builds nothing here, only verifies.

- [ ] **Step 4: Re-prove warning enforcement** (required after any
      `project.godot` rewrite, `docs/tooling.md`): create a scratch file
      `src/tmp_untyped_probe.gd` containing exactly:

```gdscript
extends Node


func probe():
	var x = 1
	return x
```

Run `scripts/lint.ps1`. Expected: **FAIL** at the strict-type gate. Delete the
scratch file. Run `scripts/lint.ps1` again. Expected: PASS. If the deliberate
failure did not fail, the warning block was damaged by the rewrite — restore
`[debug]` from git before proceeding.

- [ ] **Step 5: Full test suite**

```bash
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
```

Expected: PASS. The REPAIR-1/19 viewport-fit tests set `win.size = 1152×648`
explicitly, so they remain meaningful under the new canvas.

- [ ] **Step 6: Selective stage + commit** — verify the staged diff contains
      ONLY the `[display]` section (no MCP autoloads):

```bash
git add -p project.godot
```

```bash
git diff --cached project.godot
```

Expected staged diff: exactly the `[display]` block. Then:

```bash
git commit -m "G0: 1080p canvas with fullscreen; windowed default unchanged at 1152x648"
```

- [ ] **Step 7: Journal + state** ("G0 Task 3: display section", note the
      enforcement re-proof result).

---

### Task 4: UI constants scaled to the 1080p canvas

**Files:**
- Modify: `src/data/balance/BalanceUi.gd`, `src/data/balance/BalanceSettings.gd`
  (panel/scroll dims incl. the 520×620 options panel), `src/data/balance/BalanceFlight.gd`
  (HUD font sizes), `src/data/balance/BalanceCombat.gd` (reticle/bracket pixel
  sizes) — plus any panel design-size constant found in Step 1 (e.g.
  `NEW_GAME_TIP_HEIGHT`).

**Interfaces:**
- Consumes: the 1920×1080 canvas from Task 3.
- Produces: UI that occupies the same fraction of the screen as before. Later
  phases (G5 theme work) build on these values.

**Why:** the canvas grew 5/3× while every pixel constant was tuned for
1152×648, so all UI renders at 60% physical size after Task 3. The scale
factor is exactly **5/3** (1920/1152 = 1080/648 = 5/3).

- [ ] **Step 1: Enumerate the constants.** Produce the audit table (constant,
      file:line, old value, new value = old × 5/3 rounded to nearest int):

```bash
powershell -Command "Select-String -Path src/data/balance/BalanceUi.gd,src/data/balance/BalanceSettings.gd,src/data/balance/BalanceFlight.gd,src/data/balance/BalanceCombat.gd -Pattern 'SIZE|WIDTH|HEIGHT|FONT|PADDING|MARGIN|RADIUS|BORDER|_PX|OFFSET' | Select-Object Path,LineNumber,Line"
```

Judgment rules while filling the table (this is why Task 4 is Claude-tier):
scale **pixel dimensions and font sizes**; do NOT scale ratios, alphas, counts,
durations, or anything whose name/comment shows it is not a pixel length. When
unsure, read the usage site. Corner radii and border widths scale and round
(2px border → 3px).

- [ ] **Step 2: Apply the table.** Edit each constant in place. No new
      constants, no renames — values only.

- [ ] **Step 3: Existing tests still green**

```bash
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
```

Expected: PASS. If a REPAIR-1/19 fit test fails, a scaled panel no longer fits
the 1152×648 *window* under stretch — re-check that panel's constant against
its clamp logic before touching the test (tests are contracts; fix the value,
not the test).

- [ ] **Step 4: Human-eyes screenshot pass (windowed + fullscreen).** Main
      menu, options, HUD in flight, station menu, sector map, captain sheet.
      Bar: same physical proportions as before Task 3; text crisp in
      fullscreen. Save before/after screenshots for Elliot's phase gate.

- [ ] **Step 5: Lint + commit**

```bash
powershell -ExecutionPolicy Bypass -File scripts/lint.ps1
```

```bash
git add src/data/balance/BalanceUi.gd src/data/balance/BalanceSettings.gd src/data/balance/BalanceFlight.gd src/data/balance/BalanceCombat.gd
git commit -m "G0: UI reads the same size on the 1080p canvas as it did before"
```

(Extend the `git add` list with any additional balance file the Step 1 audit
touched.)

- [ ] **Step 6: Journal + state** ("G0 Task 4: UI scale audit", attach the
      audit table in the detail).

---

### Task 5: 1080p fit tests for the five unclamped panels

**Files:**
- Test: `tests/test_g0_viewport_fit.gd` (new)
- Modify only if a test fails: `src/ui/session/MainMenu.gd`,
  `src/ui/session/PauseMenu.gd`, `src/ui/session/OptionsMenu.gd`,
  `src/ui/session/CampaignJournal.gd`, `src/ui/session/SectorMapPanel.gd`

**Interfaces:**
- Consumes: the panels' existing EventBus open/close request signals and their
  root `PanelContainer`s.
- Produces: regression coverage that every session panel fits the canvas at
  both the windowed override and full 1080p. G5's per-screen work relies on
  these tests as its safety net.

**Background:** REPAIR-1/19 established the method (resize the real `Window`,
assert `get_global_rect()` inside the viewport) and the production fix
(`_fit_panel_to_viewport()` on `viewport.size_changed`). Five of ten session
panels have the hook; `MainMenu`, `PauseMenu`, `OptionsMenu`,
`CampaignJournal`, `SectorMapPanel` do not.

- [ ] **Step 1: Write the tests** — `tests/test_g0_viewport_fit.gd`, following
      `test_repair19_captain_sheet.gd`'s pattern exactly:

```gdscript
extends GutTest
## Implements: docs/GRAPHICS_PHASE_PLAN.md Phase G0 Task 5.
## The five session panels without _fit_panel_to_viewport() must still fit the
## canvas at the windowed override and at full 1080p (REPAIR-1/19 method).

const WINDOWED_W: int = 1152
const WINDOWED_H: int = 648
const CANVAS_W: int = 1920
const CANVAS_H: int = 1080


func _assert_panel_fits(panel: CanvasLayer, win_w: int, win_h: int, label: String) -> void:
	var win: Window = panel.get_window()
	assert_ne(win, null, label + " must live under a Window")
	var prev_size: Vector2i = win.size
	win.size = Vector2i(win_w, win_h)
	await get_tree().process_frame
	await get_tree().process_frame
	var vp_rect: Rect2 = panel.get_viewport().get_visible_rect()
	var root: Control = _first_control_child(panel)
	assert_ne(root, null, label + " must expose a root Control")
	var rect: Rect2 = root.get_global_rect()
	assert_gte(rect.position.x, vp_rect.position.x - 1.0, label + " left edge on-canvas at %dx%d" % [win_w, win_h])
	assert_gte(rect.position.y, vp_rect.position.y - 1.0, label + " top edge on-canvas at %dx%d" % [win_w, win_h])
	assert_lte(rect.end.x, vp_rect.end.x + 1.0, label + " right edge on-canvas at %dx%d" % [win_w, win_h])
	assert_lte(rect.end.y, vp_rect.end.y + 1.0, label + " bottom edge on-canvas at %dx%d" % [win_w, win_h])
	win.size = prev_size


func _first_control_child(layer: CanvasLayer) -> Control:
	for child: Node in layer.get_children():
		var control: Control = child as Control
		if control != null and control.visible:
			return control
	return null


func test_main_menu_fits_both_sizes() -> void:
	var menu: CanvasLayer = MainMenu.new()
	add_child_autofree(menu)
	await get_tree().process_frame
	await _assert_panel_fits(menu, WINDOWED_W, WINDOWED_H, "MainMenu")
	await _assert_panel_fits(menu, CANVAS_W, CANVAS_H, "MainMenu")
```

Then four sibling tests with the same body shape, replacing the constructor and
label: `PauseMenu.new()` / "PauseMenu", `OptionsMenu.new()` / "OptionsMenu",
`CampaignJournal.new()` / "CampaignJournal", `SectorMapPanel.new()` /
"SectorMapPanel". Adjustment allowed during execution: if a panel builds its
Controls lazily on its open-request signal rather than in `_ready()`, emit that
panel's `EventBus` open request (see `OptionsMenu.gd:33-35` for the signal
names) and await one more frame before asserting — mirror how that panel's
existing tests open it if any exist.

- [ ] **Step 2: Run the new tests**

```bash
C:\Godot\Godot_v4.6.1-stable_win64_console.exe --path . --headless -s "res://addons/gut/gut_cmdln.gd" -gtest=res://tests/test_g0_viewport_fit.gd -gexit
```

Two acceptable outcomes: PASS (panels already fit — likely, since 1080p is
*larger*), or FAIL naming specific panels.

- [ ] **Step 3: Fix any failing panel** by adding the established hook — copy
      the REPAIR-19 pattern (`CaptainSheet.gd:33-35` connect +
      `_fit_panel_to_viewport()` capping the panel to its design constant then
      `minf` against the live viewport, centered offsets — full body at
      `NewGameTip.gd:141-159`). One panel per fix, re-run the test between
      fixes. If all five pass in Step 2, skip — do not add hooks nobody needs
      (YAGNI).

- [ ] **Step 4: Full gates**

```bash
powershell -ExecutionPolicy Bypass -File scripts/lint.ps1
```

```bash
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
```

Expected: PASS, test count ≥ previous count + 5.

- [ ] **Step 5: Commit**

```bash
git add tests/test_g0_viewport_fit.gd tests/test_g0_viewport_fit.gd.uid
git commit -m "G0: every session panel provably fits both window sizes"
```

(Add any panel files modified in Step 3 to the `git add` list.)

- [ ] **Step 6: Journal + state** ("G0 Task 5: viewport fit coverage", noting
      which panels needed the hook, if any).

---

### Task 6: Capture the baseline

**Files:**
- Modify: `docs/PERF_BASELINES.md` (fill the table's first row)

**Interfaces:**
- Consumes: `PerfProbe.sample_physics_ms` (Task 1), the procedure section of
  `docs/PERF_BASELINES.md`, godot-mcp runtime tools (editor open).
- Produces: the baseline row every later phase compares against.

- [ ] **Step 1: Follow the procedure** exactly as written in
      `docs/PERF_BASELINES.md` (Task 1 Step 5): densest scene `system_beta`,
      combat traffic up (match Job 11's 12-ships-plus-bolts shape as closely as
      the game's spawning allows), read physics ms and fps at 1× and at 16×,
      windowed.
- [ ] **Step 2: Fill the table row** with real numbers, machine note
      ("home PC"), and date. If any number is wildly off the Job 11 reference
      (e.g. physics ms doubled), **stop and investigate before closing G0** —
      the display change should not move physics cost; a surprise here is a
      real finding, not noise.
- [ ] **Step 3: Commit**

```bash
git add docs/PERF_BASELINES.md
git commit -m "G0: performance baseline recorded for the graphics pass to answer to"
```

- [ ] **Step 4: Journal + state** ("G0 Task 6: baseline captured", numbers in
      the detail).

---

### Task 7: Phase close

**Files:**
- Modify: `docs/state.md` (rewrite current position; name G0 evidence per
  criterion), `docs/GRAPHICS_PHASE_PLAN.md` (tick the checkboxes)

- [ ] **Step 1: Full gates one final time** — `scripts/lint.ps1`,
      `scripts/run_tests.ps1`, and `python scripts/checkin.py --deep` (proves
      the Python gates still bite). All PASS.
- [ ] **Step 2: Definition-of-done sweep** (`AGENTS.md:68-81`): evidence named
      per criterion; state.md updated; journal entries present for Tasks 1–6.
- [ ] **Step 3: Elliot's phase gate.** Present via AskUserQuestion: the
      before/after screenshots from Task 4 Step 4 (windowed + fullscreen), the
      baseline row, and the statement "G0 changes how big things draw, not how
      anything plays." Ask him to run the game and confirm it plays right at
      both sizes. **His confirmation — not this checklist — closes the phase.**
- [ ] **Step 4: Merge on his yes**

```bash
git checkout main
```

```bash
git merge --no-ff g0-foundation -m "G0: foundation - 1080p canvas, asset home, perf instrument"
```

```bash
git push
```

- [ ] **Step 5: Write the G1 plan.** A Claude session (this one or fresh)
      writes `docs/GRAPHICS_G1_PLAN.md` at this plan's detail level: the
      bake-off procedure (hauler reference image through Meshy vs Tripo vs
      Rodin free previews), Blender cleanup + GLB export steps, the
      PlayerShip loader swap, one-system environment, first VFX, font pairing,
      hangar backdrop, and the G1 style-gate packet for Elliot. Inputs it
      needs that exist by then: G0's merged pipeline, the reference images in
      `docs/art_direction/`, and spec §5.2–§5.4.

---

## Kickoff prompt for the G0 session (paste-ready)

Start a **new Claude Code chat opened in `C:\Users\ellio\Desktop\Grok Draywar`**
(the folder matters — project rules and memory only load there), model **Opus
5** (or the top tier your session picker offers). Paste:

```
Execute Phase G0 of the graphics pass.

Read, in order: docs/GRAPHICS_PHASE_PLAN.md (the plan — G0 section), docs/GRAPHICS_PASS_DESIGN.md (the approved spec), AGENTS.md (working rules).

Then: verify the preconditions in the plan (fix pass closed per docs/state.md; docs/art_direction/ images present; note the uncommitted MCP autoload lines in project.godot that must never be staged). Work on branch g0-foundation. Execute Tasks 1-7 in order, test-first, exactly as written; where the plan says "human-eyes" or "Elliot", stop and ask me with AskUserQuestion. Do not spend money. Do not touch fix-pass files. If a plan step contradicts what you find in the repo, stop and tell me instead of improvising.

Close by presenting the Task 7 gate packet for my sign-off.
```

---

## Self-review record (per writing-plans skill)

- Spec coverage (G0 scope from design §6 row 1): window upgrade ✔ (T3–T5),
  screens re-verified ✔ (T4 S4 + T5), assets structure + import conventions ✔
  (T2), fresh perf baseline ✔ (T1+T6), Elliot gate ✔ (T7). Fullscreen toggle:
  already shipped in S10 — G0 verifies rather than builds (T3 S3); spec's
  "fullscreen support" is satisfied by verification, not new code.
- Placeholders: none — every step has real code, commands, or exact values.
  The two runtime-discovery points (lazy-built panels in T5 S1; spawn shape in
  T6 S1) name the discovery method and the pattern to mirror, which is the
  honest maximum for facts that only exist at runtime.
- Type consistency: `sample_physics_ms(tree: SceneTree, frame_count: int) -> float`
  is identical in T1 test, T1 implementation, and T6/PERF_BASELINES references.
