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
**`standing`** (A2), **`wallet`** (A5), **`cargo`** (B3), **`world`** (B2), and
**`mission`** (B2) maps. Missing `standing` means all-neutral content defaults.
Missing `wallet` means starting credits/fuel/condition. Missing `cargo` means
empty hold. Missing `world` keeps the boot system/spawn. Missing `mission`
means no active job. Tests may still use a hostile probe fixture. New required
career fields later bump the version with a migration step in
`SaveMigrations.gd`.

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

### Optional section: `wallet` (schema v1)

Written by `WalletService.to_section()` / applied by `apply_section()`.
Console save merges this section when a wallet service is present (A5).

| Key | Type | Meaning |
|---|---|---|
| `credits` | `int` | Player credits (>= 0). |
| `fuel` | `float` | Current fuel units. |
| `condition` | `float` | Hull condition. |

Missing section → boot defaults from `BalanceEconomy`.
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

Missing section → no active mission. No envelope version bump.

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
