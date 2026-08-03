# Save schema

**Version 1.** Alpha A0 foundation. Code: `src/systems/save/`.

Saves may be broken freely until release. Nothing here is future-proofed beyond
the handful of fields whose absence would cost a redesign.

---

## The short version

A save is a **versioned envelope** wrapped around a dictionary of **sections**,
one per game system. The envelope is defined exactly and has no opinion about
what is inside a section.

**Version 1 stores the envelope only** (no schema bump for optional sections).
Debug `save`/`load` and menu save write `sections` that may include optional
**`standing`** (A2), **`world_clock`** (S1), **`wallet`** (A5), **`cargo`** (B3),
**`ship`** (E2.5), **`world`** (B2), **`mission`** (B2), and **`career`** (E4.6)
maps. Missing `standing` means all-neutral content defaults. Missing
`world_clock` means elapsed game time starts at zero. Missing `wallet` means
starting credits/fuel/condition. Missing `cargo` means empty hold. Missing
`ship` means Hauler only (starter owned, active Hauler). Missing `world` keeps
the boot system/spawn. Missing `mission` means no active job. Missing `career`
means no life-path ids on the captain sheet (old saves). Tests may still use a
hostile probe fixture. New required career fields later bump the version with a
migration step in `SaveMigrations.gd`.

### Optional section: `standing` (schema v1)

Written by `StandingService.to_section()` / applied by `apply_section()`.
Console save also merges recovery chain progress into this section (A4).

| Key | Type | Meaning |
|---|---|---|
| `entities` | `Dictionary` | Entity id → float standing overrides. |
| `people` | `Dictionary` | Person id → float standing overrides. |
| `person_success` | `Dictionary` | Person id → int successful personal work count (A4). |
| `person_closed` | `Dictionary` | Person id → close reason string (A4; missing = open). |
| `recovery_progress` | `Dictionary` | Chain id → Array of completed step id strings (A4). |

Ids not listed use content `default_player_standing` (else 0).
Missing A4 maps mean no history, nobody closed, no chain progress.
No envelope version bump — these keys are optional inside schema v1.

### Optional section: `world_clock` (schema v1)

Written by `WorldClock.to_section()` / applied by `WorldClock.apply_section()`
via `CareerSave` (S1). Always gathered when saving a career. No envelope
version bump. Later sim sections (`market`, boards, …) will sit beside this;
S1 only persists the clock.

| Key | Type | Meaning |
|---|---|---|
| `elapsed_seconds` | `float` | Accumulated game seconds since career start / last clock reset. |

Missing section → elapsed resets to 0. Negative / non-finite values → 0.
Load does **not** emit bulk away-time bus events; TimeScale still resets to 1x
on `on_save_loaded` independently.

### Optional section: `wallet` (schema v1)

Written by `WalletService.to_section()` / applied by `apply_section()`.
Console save merges this section when a wallet service is present (A5).

| Key | Type | Meaning |
|---|---|---|
| `credits` | `int` | Player credits (>= 0). |
| `fuel` | `float` | Current fuel units. |
| `condition` | `float` | Hull condition. |
| `debt_owed` | `int` | Optional (E3.2). Flat amount still owed on the Free Haulers emergency loan. Missing or ≤0 → no debt. |
| `debt_lender_id` | `String` | Optional (E3.2). Lender Entity id while debt is open (default Free Haulers when owed > 0 and key empty). |
| `debt_grace_docks_left` | `int` | Optional (E3.2). Fee-charging docks left before Free Haulers standing hit while broke with debt. Missing with other debt keys → 0. |

Missing section → boot defaults from `BalanceEconomy`.
Missing debt keys (old saves) → no debt.
No envelope version bump — optional inside schema v1.

### Optional section: `cargo` (schema v1)

Written by `CargoService.to_section()` / applied by `apply_section()` when a
cargo service is present (B3). The section body is the inventory map itself
(not nested under a further key).

| Key | Type | Meaning |
|---|---|---|
| *(commodity id string)* | `int` | Quantity held of that commodity (> 0). |

Missing section → empty hold. Empty dictionary → empty hold.
No envelope version bump — optional inside schema v1.

### Optional section: `ship` (schema v1)

Written by `ShipService.to_section()` / applied by `apply_section()` when a
ship service is present (E2.5). Gathered by `CareerSave` with other meta
sections. No envelope version bump.

| Key | Type | Meaning |
|---|---|---|
| `active_hull_id` | `String` | Content id of the hull currently flown. |
| `owned_hull_ids` | `Array` of `String` | Hull content ids the career owns. Always includes starter `hull_courier`. |

Missing section → Hauler only (owned `hull_courier`, active Hauler).
Unknown / unowned active id falls back to Hauler. Starter ownership is always
restored if omitted from the array.

### Optional section: `world` (schema v1)

Written by `CareerSave` when a `system_world` and player ship are present (B2).
Applied by `Main` after boot (system rebuild + free-fly position). Docked
restore is not required (free-fly at saved position is OK).

| Key | Type | Meaning |
|---|---|---|
| `system_id` | `String` | Content id of the current star system. |
| `pos_x` | `float` | Ship world X. |
| `pos_y` | `float` | Ship world Y. |
| `pos_z` | `float` | Ship world Z. |
| `docked_station_id` | `String` | Docked station id, or empty when free-flying. |

Missing section → boot system and spawn. No envelope version bump.

### Optional section: `mission` (schema v1)

Written by `MissionService.to_section()` when a mission is active (B2).
Applied by `MissionService.apply_section()` (restores active template; emits
`on_mission_accepted` so HUD refreshes).

| Key | Type | Meaning |
|---|---|---|
| `template_id` | `String` | Active contract template content id. |
| `objective_met` | `bool` | Optional (E1.3). True when a bounty kill gate is done. Missing = false. |

Smuggle (E3.4) does **not** add mission keys. Cargo for the job lives in the
`cargo` section. Restore applies cargo first, then mission without re-loading
crates (so save/load does not double the hold).

Missing section → no active mission. No envelope version bump.

### Optional section: `career` (schema v1)

Written by `CareerPathState.to_section()` / applied by `apply_section()` when
gathered through `CareerSave` (E4.6). Holds the three life-path option ids and
whether the opening beat finished. No envelope version bump.

| Key | Type | Meaning |
|---|---|---|
| `origin_id` | `String` | Life-path origin option content id. |
| `trade_id` | `String` | Life-path former-trade option content id. |
| `mark_id` | `String` | Life-path mark option content id. |
| `opening_complete` | `bool` | True after annexation continue (or restored past opening). |

Missing section → old save; captain sheet hides Origin/Trade/Mark. Empty path
ids with no flag → clear path memory.

Saving is deterministic to the byte: the same state always produces the same
file, and loading a file and saving it again reproduces it exactly.

---

## The envelope

Six fields. All six are required; an envelope with a missing one, or with a
seventh nobody recognises, is refused rather than repaired.

| Field | Type | Version 1 |
|---|---|---|
| `format` | `StringName` | Always `&"draywar_save"`. |
| `schema_version` | `int` | `1`. Read before anything else is trusted. |
| `profile_name` | `String` | Player name for this career. Free text; may be empty. |
| `origin` | `StringName` | `&"manual"`, `&"autosave_entry"`, or `&"autosave_dock"`. |
| `career_mode` | `StringName` | `&"standard"` only (ironman reserved later). |
| `sections` | `Dictionary` | Per-system state, keyed by name. May be empty. |

A save file is exactly `var_to_bytes()` of that dictionary in **canonical form**
(keys sorted at every depth, string keys normalised to StringName, containers
plain). There is no separate header, checksum or padding.

---

## What a save may contain

Only:

- null, bool, int, float, String, StringName, Array, Dictionary

Refused (with a sentence):

- NaN / infinity floats
- Vector2 / Vector3 / Vector4 (store components as separate floats — vectors are
  32-bit and already lose precision)
- Objects, callables, other engine types
- Non-name dictionary keys

---

## Migrations

`SaveMigrations.registered_steps()` is empty at schema v1. The walk and refusal
paths are real; tests inject fake steps to prove the seam.

When schema N+1 lands: add one step keyed by N that returns an envelope stating
N+1, and bump `SaveSchema.CURRENT_VERSION`.

---

## Public face

`SaveService` (not an autoload):

- `envelope(sections, profile_name, origin, career_mode)`
- `save_to(path, envelope)` / `load_from(path)` — load emits
  `EventBus.on_save_loaded(path)` only on success
- `encode_bytes` / `decode_bytes` for in-memory work

Console: `save <name>` / `load <name>` via `SaveConsoleCommands` (child of Main).
Menu/pause: same gather/apply path through `CareerSave` (default name `career`).

Files live under `user://saves/*.sav`.
