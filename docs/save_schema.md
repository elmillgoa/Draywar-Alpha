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
**`standing`** (A2), **`world_clock`** (S1), **`market`** (S2), **`wallet`** (A5),
**`cargo`** (B3), **`ship`** (E2.5), **`operation`** (S6), **`campaign`** (S7),
**`world`** (B2), **`mission`** (B2), **`boards`** (S3a), **`incidents`** (S3b),
**`enforcement`** (S4), and **`career`** (E4.6) maps. Missing `standing` means
all-neutral content defaults.
Missing `world_clock` means elapsed game time starts at zero. Missing `market`
means every station market is re-seeded from its station profile. Missing
`boards` means job boards re-derive from the clock with no mid-cycle claims.
Missing `incidents` means security steps re-derive from the clock; offered
prompts are never restored. Missing `enforcement` means no per-Entity heat.
Missing `wallet` means starting credits/fuel/condition. Missing `cargo` means
empty hold. Missing `ship` means Hauler only (starter owned, active Hauler).
Missing `operation` means empty fleet and empty warehouses. Missing `campaign`
means Act I with no spine progress. Missing `world` keeps the boot system/spawn.
Missing `mission` means no active job. Missing `career` means no life-path ids
on the captain sheet (old saves).
Tests may still use a hostile probe fixture. New required career fields later
bump the version with a migration step in `SaveMigrations.gd`.

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
| `recovery_active` | `Dictionary` | Optional (Job 3). The step still running when the save was written: `chain_id`, `step_id` (both `String`). Empty dictionary = nothing running. |

Ids not listed use content `default_player_standing` (else 0).
Missing A4 maps mean no history, nobody closed, no chain progress.
Missing `recovery_active` (a save written before Job 3) means nothing running,
which is what every earlier build did with an in-progress step anyway.
On restore an unknown chain id, or a step the chain no longer has, also means
nothing running — the file is not repaired. A restored step re-emits
`on_recovery_accepted` so the station menu shows the job again.
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

### Optional section: `market` (schema v1)

Written by `MarketService.to_section()` / applied by `apply_section()` via
`CareerSave` (S2). Always gathered when saving a career. No envelope version
bump. Applied **immediately after `world_clock` and before `wallet`/`cargo`** —
the market resolves its own step count against the restored elapsed time, and
trade prices off the restored stocks.

| Key | Type | Meaning |
|---|---|---|
| `steps_done` | `int` | Market simulation steps applied since career start. Couples the market to the world clock so a load resumes mid-timeline instead of restarting it. |
| `stocks` | `Dictionary` | Station id string → { commodity id string → `float` stock }. One entry per (station, commodity) the station keeps a market in. |
| `shocks` | `Array` | Active temporary price modifiers. Each entry: `station`, `commodity`, `kind` (`strip`/`glut`), `magnitude` (`float`, signed), `expiry_seconds` (`float`, world-clock second it decays to nothing). |

Missing section → every market re-seeded from station profiles at their
`stock_targets`, step count zero. On load the section is layered **over** a
fresh content seed, so:

- Unknown station or commodity ids are **dropped**, not repaired.
- Restored stocks clamp to `[0, capacity × SELL_OVERFILL_LIMIT]`.
- `steps_done` clamps to `floor(elapsed_seconds / STEP_SECONDS)` — a restored
  market can never be ahead of its own clock.
- Shocks already past their expiry, or on ids that no longer exist, are dropped.

Byte-determinism holds because stocks are plain finite floats and every code
path that produces them is deterministic (no RNG anywhere in the market sim).

### Optional section: `wallet` (schema v1)

**Single section key** for money + fuel + hull (S5 Session B split). `CareerSave`
**gathers** by merging `to_section()` from three services:

| Service | Group | Keys written |
|---|---|---|
| `WalletService` | `wallet_service` | `credits`, `debt_*` |
| `FuelService` | `fuel_service` | `fuel` |
| `HullConditionService` | `hull_condition_service` | `condition` |

**Apply:** the same dictionary is passed to all three; each applies only its
keys. Missing section → each present service `reset()` to boot defaults.
Old saves written by the pre-split god `WalletService` (all keys in one
`to_section`) still load correctly. No envelope version bump.

| Key | Type | Meaning |
|---|---|---|
| `credits` | `int` | Player credits (>= 0). |
| `fuel` | `float` | Current fuel units. |
| `condition` | `float` | Hull condition. |
| `debt_owed` | `int` | Optional (E3.2). Flat amount still owed on the Free Haulers emergency loan. Missing or ≤0 → no debt. |
| `debt_lender_id` | `String` | Optional (E3.2). Lender Entity id while debt is open (default Free Haulers when owed > 0 and key empty). |
| `debt_grace_docks_left` | `int` | Optional (E3.2). Fee-charging docks left before Free Haulers standing hit while broke with debt. Missing with other debt keys → 0. |
| `upkeep_debt` | `float` | Optional (Job 3). Fractional upkeep run up since the last whole credit was charged, `0.0 <= x < 1.0`. Missing → 0. |

Missing section → boot defaults from `BalanceEconomy` (each service resets).
Missing debt keys (old saves) → no debt.
Missing `upkeep_debt` (a save written before Job 3) → nothing owed, which is the
old forgiving behaviour. Non-finite or negative values are read as 0.
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
| `loadouts` | `Dictionary` (optional) | Per-hull outfitting (S5). Keys are hull content id strings. Each value is `{ "weapons": [id or ""], "equipment": [id or ""] }` sized to that hull's role slots. Empty string = empty slot. Unknown / invalid item ids are dropped on load. |

Missing section → Hauler only (owned `hull_courier`, active Hauler).
Unknown / unowned active id falls back to Hauler. Starter ownership is always
restored if omitted from the array. Missing `loadouts` → empty slots for owned hulls.

### Optional section: `operation` (schema v1)

Written by `OperationService.to_section()` / applied by `apply_section()` when
an ops service is present (S6). Always gathered when the service exists (empty
fleet is valid). Applied **after `cargo`** so warehouse deposit/withdraw stays
coherent with the restored hold. No envelope version bump. Hired ships are
abstract (no world spawn ids).

| Key | Type | Meaning |
|---|---|---|
| `hired` | `Array` of `Dictionary` | Hired abstract ships (max 2). Each entry: `id`, `type` (`ops_hauler` / `ops_fighter`), `order` (`park` / `haul_route` / `escort_player`), `origin_station`, `dest_station`, `commodity_id`, `charter_entity`, `upkeep_misses`, `haul_progress_hours`, `home_station`. |
| `warehouse` | `Dictionary` | station id string → { commodity id string → int qty }. Capacity is per-station volume (`BalanceOps.WAREHOUSE_CAPACITY`). |

Missing section → empty fleet and empty warehouses.

### Optional section: `campaign` (schema v1)

Written by `CampaignService.to_section()` / applied by `apply_section()` when a
campaign service is present (S7–S8). Always gathered when the service exists
(Act I with no progress is valid). Applied **after `operation`** and **before
`mission`**. No envelope version bump.

| Key | Type | Meaning |
|---|---|---|
| `act` | `int` | Current campaign act (`1` Act I, `2` Act II, `3` Act III). |
| `flags` | `Dictionary` | flag name string → `true` for set campaign flags (includes Holding milestones, `flag_holding_claimed`, `flag_campaign_complete`). |
| `completed_spine` | `Array` of `String` | Spine contract template ids completed. |
| `holding` | `Dictionary` | Holding progress (S8). Empty when unclaimed. Keys below. |

#### `campaign.holding` keys (S8)

| Key | Type | Meaning |
|---|---|---|
| `station_id` | `String` / `StringName` | Claimed candidate station id. |
| `claimed` | `bool` | True after purchase. |
| `ignited` | `bool` | True after ignition spine sets `flag_campaign_complete`. |
| `price_paid` | `int` | Credits spent at purchase (effective milestone price). |
| `prior_controller` | `String` / `StringName` | Content `Station.controller_entity_id` at claim time (epitaph). |

On load, if `claimed` is true, `CampaignService` re-applies
`StandingService.set_station_controller_override(station_id, entity_player_holding)`
so status moment and dock use the player Holding entity.

Missing section → Act I, `flag_act1_started` only, no completed spines, empty holding.

### Optional section: `world` (schema v1)

Written by `CareerSave` when a `system_world` and player ship are present (B2).
Applied by `Main` after boot: system rebuild, then position, then the berth.
**Docked restore is real as of Job 3** — a save written at a station comes back
at that station.

| Key | Type | Meaning |
|---|---|---|
| `system_id` | `String` | Content id of the current star system. |
| `pos_x` | `float` | Ship world X. |
| `pos_y` | `float` | Ship world Y. |
| `pos_z` | `float` | Ship world Z. |
| `docked_station_id` | `String` | Docked station id, or empty when free-flying. |

**Restore order, and it matters.** `Main._apply_world_section()`:

1. Rebuilds the system if the saved one differs from the live one.
2. If the save was written free-flying and the live session is docked, leaves
   the berth first (`on_undock_requested`) — otherwise the undock would fling
   the ship back to the station anchor after it had been placed.
3. Applies `pos_x/y/z`, zeroes velocity, enables flight.
4. If the save names a berth, calls `DockingService.begin_session_docked()` —
   the **same** call a new career uses to wake up docked. That parks the ship
   at the anchor, hides it, cuts flight, and emits `on_docked`, which opens the
   station menu and re-shows the station status moment. No separate rule about
   what a restored docked player may do: it is an ordinary berth.

A berth the rebuilt world does not have, or one standing now refuses, leaves
the free-fly restore from step 3 standing rather than failing the load.

Missing section → boot system and spawn. Missing `docked_station_id`, or an
empty one, reads as free-flying. No envelope version bump.

### Optional section: `boards` (schema v1)

Written by `BoardService.to_section()` / applied by `apply_section()` via
`CareerSave` (S3a). Always gathered when saving a career. No envelope version
bump. Applied **after `market` and before `wallet`/`cargo`** so radiant
shortage reads match restored shelves. Offer rows themselves are **not**
saved — they re-derive from content + market + step.

| Key | Type | Meaning |
|---|---|---|
| `steps_done` | `int` | Board restock steps applied since career start (`floor(elapsed / BOARD_STEP_SECONDS)`). |
| `claimed` | `Dictionary` | Station id string → Array of claimed offer id strings for the current restock cycle. |

Missing section → boards re-derive from the clock; no mid-cycle claims.
`steps_done` clamps to `floor(elapsed_seconds / BOARD_STEP_SECONDS)`.

### Optional section: `incidents` (schema v1)

Written by `IncidentService.to_section()` / applied by `apply_section()` via
`CareerSave` (S3b). Always gathered when saving a career. No envelope version
bump. Applied after `boards`.

| Key | Type | Meaning |
|---|---|---|
| `steps_done` | `int` | Security / incident evaluation steps applied since career start (`floor(elapsed / INCIDENT_STEP_SECONDS)`). |
| `kind_steps` | `Dictionary` | Optional (Job 3). `"system_id\|kind"` string → `int` step the kind last fired at. The same-kind cooldown (`COOLDOWN_STEPS_SAME_KIND`). Missing → no cooldowns. |

**Policy:** offered incidents **expire on load**. Mid-flight prompts depend on
live ships and player location; a reload clears the offered set and only
restores the step counter for news continuity. Do not add offered rows to the
section without a world-prop restore plan. `kind_steps` does **not** change
that policy — it restores the cooldown, never the prompt, so reloading can no
longer make the same incident kind eligible again immediately.

Missing section → security steps re-derive from the clock; no offered prompts.
`steps_done` clamps to `floor(elapsed_seconds / INCIDENT_STEP_SECONDS)`, and
each `kind_steps` value clamps to `[0, steps_done]` — a kind cannot have fired
at a step that has not happened.

### Optional section: `enforcement` (schema v1)

Written by `EnforcementService.to_section()` / applied by `apply_section()` via
`CareerSave` (S4). Always gathered when saving a career. No envelope version
bump. Applied **after `incidents`**. Heat is **not** standing — standing stays
in the `standing` section and only moves through StandingService.

| Key | Type | Meaning |
|---|---|---|
| `heat` | `Dictionary` | Entity id string → float heat (0..HEAT_MAX). Missing id = 0. |
| `steps_done` | `int` | Security steps applied for heat decay (same cadence as incidents: `floor(elapsed / INCIDENT_STEP_SECONDS)`). |
| `hunt_steps` | `Dictionary` | Optional (Job 3). System id string → `int` step a forced hunt patrol last fired at (`HUNT_COOLDOWN_STEPS`). Missing → no cooldowns. |

Missing section → no heat; decay steps re-derive from the clock on next catch-up.
`steps_done` clamps to `floor(elapsed_seconds / INCIDENT_STEP_SECONDS)`, and
each `hunt_steps` value clamps to `[0, steps_done]` — a hunt cannot have fired
at a step that has not happened. Missing `hunt_steps` (a save written before
Job 3) means no cooldown carried across the load, which is the old behaviour
that let a forced hunt re-fire straight after loading.
Unknown entity ids in `heat` are kept as raw floats (dropped only if non-finite
or ≤ 0 after clamp).

### Optional section: `mission` (schema v1)

Written by `MissionService.to_section()` when a mission is active (B2 / S3a).
Applied by `MissionService.apply_section()` (restores active template or
runtime snapshot; emits `on_mission_accepted` so HUD refreshes).

| Key | Type | Meaning |
|---|---|---|
| `template_id` | `String` | Active contract template content id, **or** board offer instance id for radiant/hand board rows. |
| `objective_met` | `bool` | Optional (E1.3). True when a bounty kill gate is done. Missing = false. |
| `bounty_kills` | `int` | Optional (Job 3). Kills banked so far on a bounty job, `0..BOUNTY_KILLS_REQUIRED`. Written for every active bounty, including zero. |
| `runtime` | `bool` | Optional (S3a). True when the job is a board snapshot (not ContentLibrary). Missing = false. |
| `kind` | `String` | Runtime only. Mission kind (`delivery` / `bounty` / `smuggle` / `escort`). |
| `offering_entity_id` | `String` | Runtime only. Offering Entity id. |
| `pay_credits` | `int` | Runtime only. Credits on complete. |
| `standing_complete` | `float` | Runtime only. Standing delta on complete. |
| `standing_fail` | `float` | Runtime only. Standing delta on fail. |
| `standing_abandon` | `float` | Runtime only. Standing delta on abandon. |
| `destination_station_id` | `String` | Runtime only. Turn-in station. |
| `target_system_id` | `String` | Runtime only. Bounty kill system / escort dest system. |
| `cargo_commodity_id` | `String` | Runtime only. Smuggle commodity. |
| `cargo_quantity` | `int` | Runtime only. Smuggle units. |
| `label` | `String` | Runtime only. Plain-English board label. |
| `escort_alive` | `bool` | Optional (S3a). Escort freighter still alive. Missing on non-escort ignored; missing on escort = true. |

Smuggle (E3.4) cargo still lives in the `cargo` section. Restore applies cargo
first, then mission without re-loading crates (so save/load does not double the
hold). Runtime radiant missions restore from the snapshot keys above — they do
**not** require the offer to still be on the board.

On restore `bounty_kills` wins when present and clamps to
`[0, BOUNTY_KILLS_REQUIRED]`. A save written before Job 3 has no such key, so
it still restores from `objective_met` alone — all-or-nothing, which is what it
recorded. `objective_met` is still written for a finished bounty so an older
build reading a newer file is not confused about a job the player completed.

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
| `origin` | `StringName` | `&"manual"`, `&"autosave_entry"`, or `&"autosave_dock"`. All three are written by real code as of Job 10 — see *When a save is written*. |
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
- `save_to(path, envelope)` / `load_from(path)` — files only. **`load_from` emits
  nothing.**
- `encode_bytes` / `decode_bytes` for in-memory work

`CareerSave`:

- `gather_sections(tree)` / `apply_meta_sections(tree, sections, path = "")`
- `apply_meta_sections` is where a load actually happens, and it ends by
  re-showing the status moment and emitting `EventBus.on_save_loaded(path)`.

Console: `save <name>` / `load <name>` via `SaveConsoleCommands` (child of Main).
Menu/pause: same gather/apply path through `CareerSave` (default name `career`).

### When the load is announced (Job 3, `#35`)

`SaveService.load_from()` used to emit `on_save_loaded` the moment the file was
decoded — before a single section had been applied — so every listener read the
state the load was about to replace. It now emits nothing. The announcement is
the **last** thing `CareerSave.apply_meta_sections()` does, after every section
above is in place, and it carries the path the caller read.

One residual, deliberate and documented rather than hidden: `world` (system,
ship position, berth) is applied by `Main` immediately **after**
`apply_meta_sections` returns, so the ship's placement is not settled at
`on_save_loaded`. Placement announces itself — `on_system_entered`, `on_docked`,
`on_undocked` — and that is what a listener that cares where the player is must
use. Nothing currently listening to `on_save_loaded` reads placement.

### When a save is written (Job 10)

Until Job 10 the answer was "only when the player presses Save". `SaveSchema`
had declared `ORIGIN_AUTOSAVE_DOCK` and `ORIGIN_AUTOSAVE_ENTRY` since A0 and
nothing called either, so a new career that lost a fight had nothing to reload
at all. There are now four writers:

| Writer | Slot | `origin` |
|---|---|---|
| Pause menu **Save** (`Main._on_manual_save_requested`) | `career` | `manual` |
| Debug console `save <name>` (`SaveConsoleCommands`) | as typed | `manual` |
| `AutosaveService` on `on_docked` | `autosave` | `autosave_dock` |
| `AutosaveService` on `on_system_entered` | `autosave` | `autosave_entry` |

**The autosave has its own slot** (`user://saves/autosave.sav`,
`BalanceSession.AUTOSAVE_SAVE_NAME`). It never overwrites the manual `career`
file — a save the player chose to write is theirs. `SaveService.most_recent_path()`
already picks the newest file by modification time, so **Continue** and the
pause menu's **Load** both mean "carry on from wherever I actually was".

**No schema change.** The autosave goes through `CareerSave.gather_sections()`
unchanged, so it holds exactly what a manual save holds — no new key, no
required field, no envelope version bump. The only code change on the write
side is an `origin` parameter on `CareerSave.save_to_name()`, defaulting to
`manual`, so every existing caller behaves as before.

**`AutosaveService` is armed and disarmed by `Main`, and that is load-bearing.**
`on_system_entered` fires part-way through `_boot_play_session()` — before the
player ship exists, so `_world_section()` would return empty and the save would
have no `world` section — and again while `_apply_world_section()` rebuilds a
system during a load, where re-saving would overwrite the file being read. A new
`AutosaveService` starts disarmed. `Main` arms it at exactly three points: just
before the storyboard dock of a new career (which is what gives a captain who
has never touched Save something to come back to), and at the end of the
Continue and Load paths. It is disarmed again the moment the hull reaches zero,
so no autosave ever captures a destroyed ship.

**The write is deferred by one message-queue flush**, not run inside the signal
handler. A gate jump builds the destination system — which emits
`on_system_entered` — and only then moves the ship to the arrival point; saving
inline would file the new system with the old coordinates.

### Where the files live

`user://saves/*.sav`.

`user://` is **pinned** (Job 3), not derived from the product name:

```
application/config/use_custom_user_dir = true
application/config/custom_user_dir_name = "Godot/app_userdata/Draywar"
```

The pinned name is deliberately the exact relative path Godot already derived
from `config/name`, so turning the pin on **moved nothing**. Measured on
Windows with Godot 4.6.1: `%APPDATA%/Godot/app_userdata/Draywar` before the pin
and the same path after it. No save migration was needed and none exists.

This closes `RA-8`. Commit `4a9eb9b` renamed `config/name` from "Draywar Alpha"
to "Draywar" and every existing save became invisible, because `user://` was
derived from that name. It cannot happen again: with the pin, changing
`config/name` no longer changes the save folder — `tests/test_save_fidelity.gd`
asserts exactly that, and asserts that without the pin the rename still would
move it.

Note for a future non-Windows export (there is only a Windows preset today):
Godot's *derived* path uses a lower-case `godot` directory on Linux, so on a
first Linux build the pinned capital-`G` folder is a fresh, empty directory.
That is harmless — there are no pre-existing Linux saves to strand — but do not
"fix" the case on Windows, where it would orphan every real save.
