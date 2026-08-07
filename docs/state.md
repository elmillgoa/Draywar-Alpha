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
