# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **S10 signed 2026-08-04** — release candidate.
Steam phase queue **S0–S10 complete**. Maturity = **polish / RC** (content
complete was S9). Elliot = playtest + ideas only; LLMs program everything.

| Doc | Role |
|-----|------|
| `docs/STEAM_PHASE_PLAN.md` | Build queue S0–S10 — **complete** for plan bar |
| `docs/PRODUCT_DIRECTION.md` | Steam 1.0 intent locks |
| `docs/reputation_and_standing.md` | Standing law |
| `docs/gates.md` | E6.6 signed; S2–**S10** signed |
| `docs/S10_RC_PLAYTEST.md` | RC playtest (gate **closed**) |
| `docs/S9_CONTENT_PLAYTEST.md` | Content complete (gate closed) |

## Phase progress

| Phase | Status |
|-------|--------|
| E1–E6 | **closed** |
| **S0**–**S9** | **done** |
| **S10** Polish + RC | **done** 2026-08-04 — gate signed (“Pass”) |

## What the game can do now

- Full Steam path: economy, life, enforcement, ship, Ops, campaign, Holding,
  S9 content floor, S10 options/a11y/presentation/audio/packaging floor.
- Product name **Draywar**. Keyboard+mouse only. Ship budget 20.
- SteamService stub (no live SDK). No AAA art/music.

## Next session starts here

1. **Post-plan work** — no S11 in the Steam queue. Next is product/launch ops
   Elliot chooses: external RC players, Steam page, live GodotSteam if approved,
   bug smash from play, optional polish passes.
2. Do not invent new pillars. Standing law unchanged.
3. Cold chat: `/start` reads this file.

### Locked decisions

- All S0–S9 locks stand.
- **S9:** content complete signed 2026-08-04.
- **S10:** RC signed 2026-08-04 (“Pass”). Controller = KBM only. Steam = stub
  until SDK approved. Ship budget 20.

## Standing decisions

- Steam plan v1.2 queue **closed** (S0–S10 signed).
- Next direction is Elliot’s call (launch prep / external play / SDK).

## Session history

- **2026-08-08 (REPAIR-8 — escort/combat lifecycle leaks)** — External audit
  baseline ee17eab5: four lifecycle/timing defects (no save/standing/EventBus
  signal-set change).
  **(1) Stale escort freighter** — `SystemWorld` only spawned on accept/undock/
  system enter and early-returned when `_live_escort_count() > 0`, so a live
  freighter after complete/abandon blocked the next job. Now listens to
  `on_mission_completed` / `failed` / `abandoned` and `_clear_escort_freighters()`.
  **(2) Combat lock leak** — `_release_combat_lock_if_last` treated any valid
  group member as alive; two deaths same frame left lock on forever. Skips
  nodes with `is_alive() != true`.
  **(3) Point-blank bolt** — spawn at `PROJECTILE_LENGTH` could sit inside a
  hostile and auto-hit. `PlayerProjectile` ignores auto contact for the first
  physics tick (`_age_ticks`); explicit `try_hit` still works.
  **(4) Scaled cooldowns** — player `_fire_cooldown` and impact cooldowns now
  tick with real `delta` (motion still scaled). Balance constants unchanged.
  **Tests** (`tests/test_repair8_lifecycle.gd`): escort despawn complete +
  abandon, next spawn fresh; two hostiles same-frame death releases combat
  lock. Red-proved (3/3 fail with fixes stripped), then green. Full suite
  103/103 scripts, 898/898, lint clean.
- **2026-08-08 (REPAIR-19 — captain sheet fits shipping viewport)** — External
  audit PT-9 (baseline ee17eab5): at 1152×648 the Standing header, all six
  faction rows, and Close sat below the window. Accessibility content was
  already correct (every row has color + glyph + tier word); layout only.
  **Fix (same shape as REPAIR-1 tip):** `CaptainSheet` clamps the panel to
  design size and viewport (`_fit_panel_to_viewport`, open + size_changed);
  ship/wallet/job lines live in a `ScrollContainer`; Standing header, the six
  rows, and Close stay outside the scroll so they remain visible. Tier text,
  glyphs, and colours untouched. No StandingService / save / EventBus /
  S10 playtest doc edits.
  **Tests** (`tests/test_repair19_captain_sheet.gd`):
  `test_captain_sheet_fits_shipping_viewport` (red→green — Close + every
  standing row bottom ≤ 648),
  `test_captain_sheet_rows_have_tier_color_glyph_and_word` (green-on-arrival —
  S10 a11y guard on each standing row).
  Full suite 102/102 scripts, 895/895, lint clean.
  **Boundary** `git diff HEAD -- src/systems/standing/StandingService.gd`: empty.
- **2026-08-08 (REPAIR-9 — station/HUD standing display consistency)** — External
  audit baseline ee17eab5: three display defects only (fourth HUD-stale-on-load
  item lives in Opus Job 3 — do not touch StandingService / load path here).
  **(1) Approach-refused prompt** (`FlightHUD._dock_prompt_text` / `_refresh_prompt`
  ~386–460): showed tier name with no glyph and no color, failing signed S10
  a11y (color + glyph + tier name). Press-F path already correct. Fix prepends
  `tier_glyph` and sets `font_color` to `tier_color` on the refused approach
  branch; non-refused prompts reset to accent.
  **(2) Dock-controller standing while docked** (`StationMenu._on_entity_standing_changed`
  ~627–634): only refreshed recovery buttons, leaving trade banner and service
  markup stale. Now calls `_refresh_all()` when the menu is visible (matches
  person path).
  **(3) Sell cap note** (`StationTradeRow._cap_note` ~175–201): always used
  MARKET sell wording; HOLD strings in BalanceEconomy were dead. Branches on
  `_sell_limit` so hold-limited sell says “you are only carrying N”.
  **Tests** (`tests/test_repair9_standing_display.gd`):
  `test_dock_refused_prompt_has_tier_color_and_glyph` (red→green),
  `test_status_line_has_tier_color_and_glyph` (green-on-arrival — S10 a11y
  guard on both `_refresh_status_line` branches), plus sell HOLD note proof.
  Full suite 101/101 scripts, 893/893, lint clean.
  **Boundary** `git diff HEAD -- src/systems/standing/StandingService.gd`: empty.
- **2026-08-08 (REPAIR-18 — load flight matches hull: PT-8 + IF-22)** — External
  audit **PT-8**: after hull hit zero, pause-menu Load restored a full hull but
  left the ship frozen (`crippled=true`, flight off). Continue worked because it
  rebuilds the ship node. **IF-22** (same line, opposite direction): the free-
  flight placement branch of `Main._apply_world_section` called
  `set_flight_enabled(true)` unconditionally as the last word on flight, after
  undock had already set flight from `HullConditionService.can_fly()` (via
  `DockingService._wallet_can_fly()` — name is a leftover from the S5 split; it
  does **not** read credits). That force-on could hand power to a grounded ship
  when the `_crippled` flag and `can_fly()` disagreed.
  **Fix (one source of truth, both directions):**
  `PlayerShip.apply_load_flight_from_can_fly(can_fly)` sets `_crippled = not
  can_fly` then requests enable; healthy hull flies (PT-8), grounded hull stays
  off (IF-22). Placement at `Main.gd` ~901 now calls that with
  `_hull.can_fly()` instead of forcing true. No save key, no
  `WORLD_KEY_DOCKED_STATION_ID`, no wallet/credits gate on flight, no change to
  what crippling does, no rename of `_wallet_can_fly` (reported only).
  **Tests** (`tests/test_repair18_load_flight.gd`): both failed on the current
  build (PT-8: healthy load left flight off; IF-22: grounded load with flag
  clear forced flight on) and pass after. Full suite 890/890 (100 scripts),
  lint clean.
  **Boundary** `git diff HEAD -- src/Main.gd`: one call swap only — no
  `WORLD_KEY_DOCKED_STATION_ID`, no new save key.
- **2026-08-07 (REPAIR-5 attempt 3 — pause freezes the sim, and alt-tab pauses
  without re-opening a docked pause menu)** — Audit findings **#46** (pause does
  not pause), **#47** (no auto-pause on focus loss), **#57** (flight actions fire
  behind Options), **#58** (pause reachable while docked). Pause only flipped a
  UI flag — no `SceneTree.paused` — so hostiles, fuel, hull and upkeep ran on
  behind the menu; nothing handled focus loss; M opened the sector map behind
  Options; Escape opened pause at a berth.
  **Two earlier attempts were rejected, and the second failure is why this entry
  is worth reading.** Attempt 1 resumed on focus-in for *any* pause, so
  Escape → alt-tab → back dropped the player into a live fight under an open
  Options panel; its tests also called the handlers directly, so deleting
  `_mark_sim_pausable` or `_notification` left the suite green. Attempt 2 fixed
  both of those and **re-broke #58**: it rewrote the focus-loss handler and did
  not carry over the docked check, so alt-tabbing at a berth put the pause menu
  — which has Load on it — over the frozen station menu. Both attempts branched
  from the same commit, so attempt 2 never saw attempt 1's code; the requirement
  existed only in prose, and prose is not a test.
  **Root cause, and what changed because of it:** the "no pause while docked"
  rule was written into each *caller* of `_set_pause` rather than into
  `_set_pause` itself. Two callers open a pause; attempt 1 guarded both, attempt
  2 guarded one. The rule now lives in `_set_pause` via `_may_open_pause_menu`
  and nowhere else, so no caller — present or added later — can open a docked
  pause menu. `_set_pause` returns `bool` so a caller can tell a refusal from a
  no-op, and the bus path `_on_pause_changed_bus` asks the same question.
  **Freezing and menu-opening are now two different things**, which is what lets
  #47 and #58 both hold: `_focus_freeze` is set on focus loss and
  `_apply_tree_paused` freezes for `_pause_open or _focus_freeze`. Alt-tab at a
  berth therefore **does** freeze the sim and does **not** show a menu.
  **The rest of the mechanism:** `Main` is `PROCESS_MODE_ALWAYS` so input, focus
  notifications and session menus keep running while the tree is frozen; sim
  nodes are demoted to `PROCESS_MODE_PAUSABLE` by `_mark_sim_pausable` at boot;
  session overlays are `_mark_session_overlay_always`; `WorldClock` went
  ALWAYS→PAUSABLE; `_notification` routes all four focus constants;
  `_pause_from_focus_loss` keeps an intentional pause alive across alt-tab and
  refuses to resume under Options / map / sheet / journal; the sector-map hotkey
  is gated on `_flight_overlay_blocks_actions` (#57).
  **No Job 3 dependency** — this refuses a docked pause and changes no load
  behaviour; `_apply_world_section` untouched.
  **Tests** (`tests/test_repair5_pause_focus.gd`, 16 tests): drive
  `main.notification(...)` rather than calling handlers; assert
  `can_process() == false` on Fuel / Hull / World / Ship / WorldClock **and on a
  hostile spawned for the purpose** — the start system spawns none of its own, so
  the previous version's hostile assertions were wrapped in `if hostile != null`
  and never ran, leaving the headline word of #46 unasserted. #58 is asserted at
  the door (`_set_pause` direct) and on every route to it (Escape, focus loss,
  bus), so a fourth route added later cannot pass by being untested. One test
  walks Main's real child list under a paused tree and fails on any child that
  keeps processing, because `Main` being ALWAYS makes the demotion **opt-out** —
  a node added by a later brief inherits ALWAYS and would simulate behind the
  pause menu with nothing to catch it.
  **Known and not fixed here, filed as a proposed finding:** `PauseMenu` sets its
  own `visible` straight off `on_pause_changed` and connects *after* Main, so an
  outside emitter of `true` would raise the panel while docked even though the
  session stays unpaused. Nothing in the game emits `true` from outside Main
  today, so there is no live path — but the panel's visibility is not covered by
  the guard above, and this entry should not be read as saying it is.
  Full suite 888/888 (99 scripts), import clean, smoke boot clean.
- **2026-08-07 (REPAIR-24 — debug console gated to debug builds)** — Audit
  finding **#44**: `ConsoleService` was created and `start()`ed on every boot,
  and `DebugConsole` registered backtick (`debug_console_toggle` /
  `KEY_QUOTELEFT`) unconditionally, so a release export could set standing,
  kill ships, and change time scale. **Fix:** injectable
  `build_is_debug: bool = OS.is_debug_build()` on `Main` (line 16) and
  `DebugConsole` (line 26). `Main._ready` (line 71) only constructs/starts the
  service when `ConsoleService.is_enabled_for_build(build_is_debug)` is true;
  submit handler null-guards (line 123). `DebugConsole._ready` (line 33) skips
  toggle registration and disables input on release; passes `build_is_debug`
  into `try_register_toggle_action` (line 37) — never a literal `true`.
  No config unlock, no cheat code, console code kept. **Tests hit the real
  `_ready` paths** (`DebugConsole.tscn` / `Main.tscn` with injected false/true)
  — no test-local copy of Main's boot decision. **Proved red then green by
  removing only the production gate lines** (helpers + tests left in place):
  release `_ready` tests failed 2/4 exit 1 (DebugConsole registered toggle;
  Main created ConsoleService); after restore 4/4. Earlier attempt-1 "red"
  was only a parse drop (Scripts-count gate), not this assertion. Editor
  check: open project, backtick still opens console. **Export templates
  absent** — release backtick check not run. Full suite 873/873 (98 scripts);
  lint clean.
- **2026-08-07 (REPAIR-6 — audio buses + rebind integrity)** — External audit
  findings on options: UI/SFX buses never existed so volume sliders did nothing;
  Reset defaults cleared stored binds but left the live InputMap on old keys;
  boot `FlightInput.ensure_actions()` re-stacked default keys over saved rebinds;
  rebind accepted Escape/backtick and other actions' keys with no feedback; and
  **IF-12** — Job 10's twelfth rebind row `call_tow` had no `_default_keycode`
  case so the Options row showed a blank key. **Fix:** `project.godot`
  `audio/buses/default_bus_layout` → `default_bus_layout.tres`, plus
  `_ensure_bus_exists` create-if-missing in `SettingsService` (`_set_bus_linear`
  ~297); `_apply_binds` always writes every REBIND_ROWS action (defaults when
  empty) so reset restores InputMap immediately; `FlightInput._bind` skips
  adding the default when any keyboard event is already present; `set_bind`
  returns a reject string for reserved keys (Escape, backtick) and conflicts,
  surfaced on the Options feedback label; `_default_keycode(&"call_tow")` →
  `KEY_T` matching `FlightInput._bind(ACTION_TOW, KEY_T)` at line 48.
  **Proved red then green on IF-12:** per-row loop over `REBIND_ROWS` failed
  with `Call a tow (call_tow): bind_label empty` before the case; passes after.
  Tests: mute at zero volume, reset restores InputMap, rebind survives
  ensure_actions, reserved/conflict refused, every-row non-empty bind label.
  Full suite 869/869; lint clean. Chose project.godot bus layout key (not
  `AudioServer.load_bus_layout`, which this strict-typing project rejects as a
  static call) + create-if-missing so headless tests still get buses.
- **2026-08-07 (REPAIR-23 — atomic settings save)** — Audit finding **#14**:
  options were written straight over `user://settings.cfg`. A crash mid-write
  left a half file; the next boot treated that as "no settings" and every option
  (FOV, sensitivity, volumes, fullscreen, rebinds) fell back to defaults. Quiet,
  and easy to hit because the options menu saves on every slider drag.
  **`SettingsService.save_to_disk()`** (now ~lines 136–177) writes
  `settings.cfg.tmp` first, aborts without touching the live file if that write
  fails, then renames the previous good file to `settings.cfg.bak` and the temp
  over `settings.cfg`. Format, keys, and defaults unchanged — still not a career
  save. Save-call frequency left alone (debounce is a separate brief). **Proved
  red then green:** `test_failed_save_preserves_existing_settings` (force temp
  path into a missing directory) and `test_atomic_save_round_trips_and_leaves_bak`
  both failed on the in-place write; both pass after the atomic path. Full suite
  864/864; lint clean.
- **2026-08-07 (Job 12 continuation — `on_kill_reported` removed, catalog caught
  up)** — Executed the verdict Opus Job 4 recorded but could not ship, because a
  removal is atomic and one of its four parts is `docs/events.md`, which was Job
  12's file this wave. **`on_kill_reported` is gone** — declaration
  (`EventBus.gd`), emit (the first line of `AttributionService.report_kill()`),
  catalog entry, and the asserting tests, all in one commit. Nothing was pushed
  into a direct call: every one of the six return paths through `report_kill()`
  already announces itself on `on_kill_attributed` or `on_kill_unattributed`,
  which `FlightHUD` listens to. **One assertion was preserved, not deleted** —
  `tests/test_e2_attribution_feedback.gd` now asserts
  `HostileNpc._live_witness_count()` against `NpcTraffic.live_ship_count()`
  directly, keeping the guard that the witness count is live ambient traffic and
  not a hardcoded 1. The three other witness assertions went: the contested
  threshold is 1, so "unattributed with no evidence" already proves the count was
  0, and the remaining live-count check covers the same code path. Bus signal
  count 121 → 120. **The two catalog lines Job 3 handed over are now written** —
  `on_save_loaded` is emitted by `CareerSave.apply_meta_sections()`, not
  `SaveService.load_from()`, and its entry now warns that `world` placement is
  applied by `Main` *after* the emit, so placement listeners must use
  `on_system_entered` / `on_docked` / `on_undocked` (the `#35` trap in its second
  form); `on_status_moment` now records that it is re-fired on career load. No
  brief was written: the verdict was removal and it was executed here, so there
  is nothing left to route.
- **2026-08-07 (Job 10 — losing a fight, autosave, and the fuel-out tow)** —
  Elliot's ruling, memo `DECISION_loss-and-autosave.md`, a **split** answer.
  **Losing a fight = death and respawn:** hull at zero now ends the run and says
  so. A `LossScreen` names what happened and offers **Restart from last save**
  (a full session rebuild from the file — ship, world and services built fresh,
  which is why it works without Grok Brief 18) or **Quit to menu**. Pause and the
  sector map are blocked while it is up. **Autosave = yes, on docking and on
  system entry:** the two origin constants `SaveSchema` has carried since A0 and
  nothing ever called are now wired by a new `AutosaveService`, writing its own
  `autosave` slot so it never eats the player's manual `career` file. It is armed
  by `Main` (boot, load and teardown all disarm it) and the write is deferred one
  message-queue flush, because a jump announces the new system *before* it moves
  the ship. **No schema change, no envelope bump** — the autosave goes through the
  same `gather_sections()` and holds exactly what a manual save holds. **The
  restart point is the last autosave**, and a brand-new career gets one at the
  storyboard dock, before it has ever undocked. **Play-area edge: no boundary** —
  Elliot ruled it out ("it is space"). Running dry is *not* losing a fight and
  does not respawn: a new `RescueService` offers an **emergency tow** (default
  `T`, in the rebind list) whenever the tank is dry away from a berth. It drags
  the ship to the nearest station standing will let it into, for
  `BalanceEconomy.TOW_FEE_CREDITS` — **capped by what the pilot holds**, so the
  measured zero-credit strand is still a tow. No standing moves; the tow spends
  credits only. `HullConditionService.can_fly()` stays the single source of truth
  and is what tells the two failures apart. Closes `PT-7` (the cycle's last open
  Blocker) and `PT-11`. New signals: `on_tow_prompt_changed(available, fee_credits)`
  and `on_run_restart_requested()`.
- **2026-08-07 (Job 3 — save/reload fidelity + where saves live)** — Elliot's
  ruling, memo `DECISION_save-schema-roundtrip.md`: **everything comes back**,
  and **pin the save folder now**. Five things a reload used to take away now
  survive it. **The berth** — a save written at a station comes back at that
  station, restored through the same `begin_session_docked()` a new career uses,
  so no new rule about what a docked player may do was invented (`#9`, ex-Brief
  5). **The recovery job you were on** — new optional `standing.recovery_active`
  key; a restored step re-emits `on_recovery_accepted` so the station menu shows
  it (`#10`). **The hunt cooldown** — new `enforcement.hunt_steps` (`#11`,
  ex-Brief 12). **The incident cooldown** — new `incidents.kind_steps`; offered
  prompts still expire on load, only the cooldown is restored (`#13`). **Partial
  bounty progress** — new `mission.bounty_kills`; `objective_met` still written
  for older readers (`#71`). **The part-credit of upkeep owed** — new
  `wallet.upkeep_debt` (`#27`). No envelope version bump and no migration step:
  every key is optional inside schema v1, and a save written before this loads
  with the old forgiving defaults (tested). **`#35` closed** —
  `SaveService.load_from()` no longer emits `on_save_loaded`; the announcement is
  now the last thing `CareerSave.apply_meta_sections()` does, once the state is
  really there. Residual documented, not hidden: `world` placement is applied by
  `Main` after that, so placement listeners must use `on_system_entered` /
  `on_docked`. **`W13` closed (Major)** — after a load in the system you were
  already in, the HUD showed the pre-load standing tier; `apply_meta_sections`
  now asks `StandingService` to re-fire its own status moment through the
  existing public `emit_status_for_system()` / `emit_status_for_station()`. No
  second standing writer, no new emit inside `apply_section()`, `StandingService.gd`
  untouched. Both failures were reproduced on the pre-fix build before the fix
  (2 failing) and pass after. **`RA-8` closed** — `user://` is pinned via
  `use_custom_user_dir` + `custom_user_dir_name = "Godot/app_userdata/Draywar"`,
  which is byte-for-byte the path Godot already derived, so **nothing moved and
  no save migration was needed**; verified by running Godot headless and printing
  `OS.get_user_data_dir()` before and after. A test proves a product rename can
  no longer move the folder, and that without the pin it still would. New suite
  `tests/test_save_fidelity.gd` (17 tests). **`docs/events.md` needs two lines
  changed** (`on_save_loaded` emitter, `on_status_moment` triggers) — recorded
  for the Job 12 continuation pass; that file was not touched here.
- **2026-08-07 (Job 4 — kill attribution)** — Two standing rules Elliot decided
  and that had never existed anywhere, now written into
  `docs/reputation_and_standing.md` §7 **before** the code. **Sanctioned bounty
  kills:** an Entity does not charge the player for a kill it paid for. While an
  active bounty is held, kills in that bounty's target system are exempt from the
  **offering** Entity's hit — nobody else's, no other system, judged at the moment
  of the kill. The Beta Spit bounty was net −4 (−12 kill against +8 turn-in) and
  is now +8. **Escort deaths:** a destroyed escort freighter is reported as a kill
  like any other, under the same security / witness / evidence rules, at the same
  cost — on top of the mission's own failure penalty. Destroying your own escort
  was previously free. `AttributionService` still writes no standing itself;
  `StandingService` remains the only writer and no new tunable was added. New
  suite `tests/test_kill_attribution_rules.gd` (8 tests). `on_kill_reported`
  verdict recorded for the Job 12 continuation pass — **remove it**; the signal
  is not touched here.
- **2026-08-07 (Job 12 — EventBus contract)** — Ruled on the five signals that
  only tests connected to. `on_incident_offered` **removed** (declaration, emit,
  test, catalog entry — one commit) as a duplicate of `on_incident_prompt`, which
  FlightHUD already listens to. `on_time_scale_changed`, `on_combat_lock_changed`
  and `on_world_time_advanced` **kept**, listeners routed to Grok Briefs 30 and 31
  (FlightHUD time-rate line and transit toast). `on_recovery_offered` **kept**;
  `StationMenu` is its listener via Brief 4. Two request signals **declared** for
  Brief 4 to wire: `on_incident_respond_requested(incident_id, choice)` and
  `on_combat_lock_requested(locked)` — a brief may not change the signal set, so
  Opus declares and the brief wires. General rule written into `docs/events.md`:
  every signal names a production listener or it does not exist; no
  reserved-for-future tier; a listener gate in `check_boundaries.py` is a named,
  unbuilt gap. `on_kill_reported` stays open — Opus Job 4 owns it.
- **2026-08-06 (Job 2 — gates)** — `lint.ps1` green now means the gates ran. The
  strict-typing gate re-parses all 219 scripts (`check_types.gd`, previously dead
  code) instead of booting for two frames; a missing gdlint/gdformat **fails**
  instead of printing SKIP and passing; `run_tests.ps1` gained the import step,
  a zero-error smoke assertion and a `Scripts` count check, and CI got the same
  count check. `checkin.py --deep` now fault-injects all three static gates for
  real. New gate `check_groups.py` + `docs/groups.md` police group lookups (the
  cross-boundary channel `check_boundaries.py` cannot see); `check_globals.py`
  now also polices the 60 `class_name` static namespaces. Verdicts written to
  `DRAYWAR_CONVENTIONS.md` §2.3, `docs/globals.md`, `docs/traps.md` #25-27.
- **2026-08-06 (REPAIR-41)** — Deleted dead Alpha content ceilings
  (`/alpha-scope` skill + AGENTS old §8). Guardrails reading order points at
  Steam plan stack. Live brake remains `Balance.CONTENT_BUDGET` + ContentLibrary.
- **2026-08-06 (REPAIR-2)** — Session boot paths repointed to live Steam
  authorities (start/work/gate skills, checkin.py, README, eras Era 2,
  AGENTS §6 gate row).
- **2026-08-06 (REPAIR-1)** — New-game "How to fly" tip: panel capped to design
  height with scrollable body; Escape dismisses. Got it stays on-screen at
  shipping 1152×648 (was fully below the window).
- **2026-08-06 (REPAIR-10)** — `export_presets.cfg` tracked (was gitignored).
  Fresh clones get Windows Desktop preset; no secrets/absolute paths.
- **2026-08-04 (S10 gate)** — Elliot signed RC (“Pass”). S10 phase closed.
- **2026-08-04 (S10 floor)** — Options/a11y, presentation, audio, packaging.
- **2026-08-04 (S9 gate)** — Content complete signed.
- **2026-08-04 (S8–S6)** — Holding, campaign, Ops.
- **2026-08-03** — S1–S5.
- **2026-08-02** — Plan freeze.
- **2026-07-31–08-02** — E1–E6 closed.
