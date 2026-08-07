# Event catalog

Every signal on the EventBus, what it carries, who sends it and who listens.

The bus itself is `src/systems/EventBus.gd`, registered as an autoload named
`EventBus`.

**This document is checked against the code.** `scripts/check_boundaries.py`
compares signals in `EventBus.gd` with the entries below and fails the build if
they disagree in either direction.

---

## Adding a signal

1. Declare it in `src/systems/EventBus.gd`, **fully typed**.
2. Add an entry below, in the same commit, copying the signature exactly.
3. Run `python scripts/check_boundaries.py`. Exit 0 means the two agree.

**The entry format is load-bearing.** The checker reads level-3 headings that
contain nothing but the signature in backticks:

```
### `on_signal_name(first: int, second: StringName)`
```

Everything else on this page is for humans and is not parsed.

## Naming

- **`snake_case`, prefixed `on_`**
- **Past tense** for things that happened; **`_requested`** for intent.

## What does not belong on the bus

- Questions that need an answer now (use a method / autoload).
- Per-frame traffic.
- Anything a single system uses internally.

## Every signal names a production listener, or it does not exist

**Verdict of Opus Job 12, decided 2026-08-07.** The 2026-08-06 audit found eight
signals that production code emitted and only tests connected to. That is the
worst of both worlds: the catalog presents the signal as a live contract surface,
so the next system assumes something consumes it — while the only thing keeping
it alive is a test asserting that an emit still emits. The test proves nothing
about the game.

The rule:

1. **Every entry below names at least one non-test consumer** on its
   `**Listened to by**` line. A signal that cannot name one is removed.
2. **There is no "reserved for future use" tier.** A reserved signal and a dead
   signal look identical from the outside, which is exactly how eight of them
   accumulated before anyone noticed. Re-adding a signal later is a declaration,
   a catalog entry and one commit — cheaper than the ambiguity.
3. **A removal is atomic.** The declaration, every emit, every asserting test and
   this catalog entry go in **one** commit. `scripts/check_boundaries.py` fails
   the build on either half alone, so a half-done removal cannot be committed —
   but a removal split across two sessions leaves the tree red in between.
4. **Changing the signal set is an Opus/Elliot decision, never a Grok brief.**
   The standing Grok stop-and-ask line names the EventBus signal set as a halt
   trigger, so a brief that ordered a declaration added or removed would be
   mis-scoped by the project's own rule. A brief may wire a listener to a signal
   that already exists; it may not create or delete one.
5. **The one sanctioned exception is a signal declared ahead of its wiring**, and
   it is time-boxed: the entry must say `**Listened to by** _nobody yet —_` and
   **name the brief that closes the gap**. An entry in that state with no named
   owner is a defect, not a reservation.

**This rule is not enforced by a gate yet, and that is a known hole.**
`check_boundaries.py` compares signal *names and signatures* against this file;
it does not read `**Listened to by**` and it does not grep `src/` for `.connect`.
Extending it belongs to whoever owns that script (Opus Job 2's machinery) and was
deliberately not built by Job 12. Until then this is a review rule, which is the
weaker kind.

---

# Catalog

## Time

### `on_time_scale_changed(scale: float)`

The effective game time rate changed (after combat lock is applied).

| Parameter | Type | Meaning |
|---|---|---|
| `scale` | `float` | Rate clocks will get. One of `Balance.TIME_SCALES`, or 1.0 while locked. |

**Emitted by** `src/systems/time/TimeScale.gd`.
**Listened to by** _nobody yet — **Grok Brief 30 (REPAIR-30)** wires the FlightHUD
time-rate line._ Clocks never listen; they ask `effective_scale()` every tick.

### `on_combat_lock_requested(locked: bool)`

Something in the world is asking for the combat lock to open or close. A request,
not a fact: `TimeScale` owns the flag and decides. The "am I the last hostile
alive" rule stays with the requester (`HostileNpc._release_combat_lock_if_last`);
this signal only carries the answer it reached.

| Parameter | Type | Meaning |
|---|---|---|
| `locked` | `bool` | True to hold time at normal speed, false to release. |

**Emitted by** _nobody yet — **Grok Brief 4 (REPAIR-4)** routes
`src/world/HostileNpc.gd:60` and `:496`, which call `TimeScale.set_combat_lock()`
directly today._
**Listened to by** _nobody yet — **Grok Brief 4** has `src/systems/time/TimeScale.gd`
listen._ Declared by Opus Job 12 because changing the signal set is not a brief's
to make; see "Every signal names a production listener" above, point 5.

### `on_combat_lock_changed(locked: bool)`

The combat lock that forces time to 1x opened or closed.

| Parameter | Type | Meaning |
|---|---|---|
| `locked` | `bool` | True when combat is holding time at normal speed. |

**Emitted by** `src/systems/time/TimeScale.gd`.
**Listened to by** _nobody yet — **Grok Brief 30 (REPAIR-30)** wires the FlightHUD
time-rate line, which is where the player is told why time snapped back to 1x._

### `on_world_time_advanced(total_elapsed_seconds: float, delta_seconds: float)`

Bulk away-time finished on the world clock (jump advance, explicit
`advance_hours` / `advance_seconds`). Not emitted per frame — live ticks use
category subscribers only.

| Parameter | Type | Meaning |
|---|---|---|
| `total_elapsed_seconds` | `float` | Elapsed game seconds after this advance. |
| `delta_seconds` | `float` | Game seconds just applied. |

**Emitted by** `src/systems/time/WorldClock.gd` from public bulk advance only.
**Listened to by** _nobody yet — **Grok Brief 31 (REPAIR-31)** wires the FlightHUD
transit toast._ Systems that need the time do **not** listen here: they register a
category subscriber, which also fires on live frames.

## Save

### `on_save_loaded(path: String)`

A career was loaded successfully from disk.

| Parameter | Type | Meaning |
|---|---|---|
| `path` | `String` | Absolute path that was read. |

**Emitted by** `src/systems/save/SaveService.gd` from `load_from()` only after
success. Failed / refused loads emit nothing.
**Listened to by** `TimeScale` (resets rate to 1x). `WorldClock` does **not**
reset elapsed on load — `CareerSave.apply_meta_sections` restores or zeros it.

## Debug console

### `on_console_commands_requested()`

Who is out there? Systems answer with registrations.

No parameters.

**Emitted by** `src/systems/console/ConsoleService.gd` from `start()`.
**Listened to by** every system that offers console commands.

### `on_console_command_registered(name: StringName, usage: String, summary: String)`

A system is offering a command for the console roster.

| Parameter | Type | Meaning |
|---|---|---|
| `name` | `StringName` | Command word. |
| `usage` | `String` | Argument form for help. |
| `summary` | `String` | One-line description. |

**Emitted by** command owners (`TimeConsoleCommands`, `SaveConsoleCommands`, …).
**Listened to by** `ConsoleService`.

### `on_console_command_invoked(name: StringName, args: PackedStringArray)`

A registered name was submitted. Unknown names never reach this signal.

| Parameter | Type | Meaning |
|---|---|---|
| `name` | `StringName` | Registered command. |
| `args` | `PackedStringArray` | Tokens after the command word. |

**Emitted by** `ConsoleService.submit()`.
**Listened to by** command owners.

### `on_console_output(line: String)`

Something to print on the console.

| Parameter | Type | Meaning |
|---|---|---|
| `line` | `String` | One line of output (no trailing newline required). |

**Emitted by** console handlers and `ConsoleService` itself.
**Listened to by** `DebugConsole`.

### `on_console_visibility_changed(open: bool)`

The debug console prompt opened or closed.

| Parameter | Type | Meaning |
|---|---|---|
| `open` | `bool` | True when the prompt is visible and focused. |

**Emitted by** `src/ui/console/DebugConsole.gd`.
**Listened to by** systems that must not treat typed keys as flight input
(`PlayerShip`, `DockingService`).

## Flight / system (A1)

### `on_system_entered(system_id: StringName)`

The player is now in this system. Session-only for A1 (no save section).

| Parameter | Type | Meaning |
|---|---|---|
| `system_id` | `StringName` | Content id of the system that was built. |

**Emitted by** `src/world/SystemWorld.gd` after gray-box build.
**Listened to by** `FlightHUD` (system name), `StandingService` (status moment),
`AutosaveService` (writes the career, origin `autosave_entry`, Job 10).

### `on_dock_requested(station_id: StringName)`

Intent to dock at this station. DockingService decides and may refuse.

| Parameter | Type | Meaning |
|---|---|---|
| `station_id` | `StringName` | Station content id. |

**Emitted by** `src/entities/DockingService.gd` when the dock action fires in range.
**Listened to by** `DockingService` (owner applies the transition).

### `on_docked(station_id: StringName)`

The ship is now docked at this station.

| Parameter | Type | Meaning |
|---|---|---|
| `station_id` | `StringName` | Station content id. |

**Emitted by** `src/entities/DockingService.gd` after a successful dock.
**Listened to by** `FlightHUD`, `StationMenu`,
`AutosaveService` (writes the career, origin `autosave_dock`, Job 10).

### `on_undock_requested(station_id: StringName)`

Intent to leave this station. DockingService decides.

| Parameter | Type | Meaning |
|---|---|---|
| `station_id` | `StringName` | Station content id being left. |

**Emitted by** `src/ui/station/StationMenu.gd` (Undock / Launch).
**Listened to by** `src/entities/DockingService.gd`.

### `on_undocked(station_id: StringName)`

The ship has left this station and is free-flying again.

| Parameter | Type | Meaning |
|---|---|---|
| `station_id` | `StringName` | Station content id that was left. |

**Emitted by** `src/entities/DockingService.gd` after a successful undock.
**Listened to by** `FlightHUD`, `StationMenu`.

### `on_dock_prompt_changed(station_id: StringName, can_dock: bool)`

Dock proximity prompt for the HUD. Empty `station_id` clears the prompt.

| Parameter | Type | Meaning |
|---|---|---|
| `station_id` | `StringName` | Nearest approach/interact station, or empty. |
| `can_dock` | `bool` | True when the dock action will be accepted. |

**Emitted by** `src/entities/DockingService.gd`.
**Listened to by** `FlightHUD`.

### `on_player_speed_changed(speed: float)`

Player ship speed magnitude changed. Session-only HUD traffic.

| Parameter | Type | Meaning |
|---|---|---|
| `speed` | `float` | Speed in metres per second. |

**Emitted by** `src/entities/PlayerShip.gd`.
**Listened to by** `FlightHUD`.

### `on_player_throttle_changed(throttle: float)`

Player throttle setting changed (0..1). Session-only HUD traffic.

| Parameter | Type | Meaning |
|---|---|---|
| `throttle` | `float` | Throttle fraction. |

**Emitted by** `src/entities/PlayerShip.gd`.
**Listened to by** `FlightHUD`.

## Standing (A2)

### `on_entity_standing_changed(entity_id: StringName, old_value: float, new_value: float, tier: StringName)`

Player standing with an Entity changed (after clamp).

| Parameter | Type | Meaning |
|---|---|---|
| `entity_id` | `StringName` | Entity content id. |
| `old_value` | `float` | Standing before the write. |
| `new_value` | `float` | Standing after clamp. |
| `tier` | `StringName` | Display tier for `new_value` (e.g. `&"hostile"`). |

**Emitted by** `src/systems/standing/StandingService.gd` only.
**Listened to by** `FlightHUD` (refresh status line).

### `on_person_standing_changed(person_id: StringName, old_value: float, new_value: float, tier: StringName)`

Player standing with a Person changed (after clamp).

| Parameter | Type | Meaning |
|---|---|---|
| `person_id` | `StringName` | Person content id. |
| `old_value` | `float` | Standing before the write. |
| `new_value` | `float` | Standing after clamp. |
| `tier` | `StringName` | Display tier for `new_value`. |

**Emitted by** `src/systems/standing/StandingService.gd` only.

### `on_status_moment(kind: StringName, place_id: StringName, entity_id: StringName, standing: float, tier: StringName)`

Protected status moment: what the player *is here* with the local controller only.

| Parameter | Type | Meaning |
|---|---|---|
| `kind` | `StringName` | `&"system"` or `&"station"`. |
| `place_id` | `StringName` | System or station content id entered. |
| `entity_id` | `StringName` | Controlling Entity id, or `&"nobody"`. |
| `standing` | `float` | Player standing with that controller. |
| `tier` | `StringName` | Display tier id. |

**Emitted by** `StandingService` on `on_system_entered` and successful `on_docked`.
**Listened to by** `FlightHUD`.

### `on_dock_refused(station_id: StringName, entity_id: StringName, standing: float, tier: StringName)`

Dock blocked because standing is at or below the controller's refusal threshold.

| Parameter | Type | Meaning |
|---|---|---|
| `station_id` | `StringName` | Station that refused the dock. |
| `entity_id` | `StringName` | Controlling Entity (or nobody). |
| `standing` | `float` | Current standing with that Entity. |
| `tier` | `StringName` | Display tier id. |

**Emitted by** `src/entities/DockingService.gd` when a dock request fails standing.
**Listened to by** `FlightHUD` (refusal prompt).

## Attribution & missions (A3)

### `on_kill_reported(system_id: StringName, victim_entity_id: StringName, witness_count: int, evidence: bool)`

A kill was reported for attribution (before the security decision).

| Parameter | Type | Meaning |
|---|---|---|
| `system_id` | `StringName` | System where the kill occurred. |
| `victim_entity_id` | `StringName` | Victim's primary Entity (may be empty). |
| `witness_count` | `int` | Ships that would report the kill. |
| `evidence` | `bool` | Player left an evidence trail. |

**Emitted by** `src/systems/attribution/AttributionService.gd`.
**Listened to by** tests; witness_count is live ambient `NpcTraffic` ship count from HostileNpc.

### `on_kill_attributed(system_id: StringName, entity_id: StringName, delta: float, reason: StringName)`

Kill was attributed; StandingService already applied the delta (and any ripple).

| Parameter | Type | Meaning |
|---|---|---|
| `system_id` | `StringName` | System where the kill occurred. |
| `entity_id` | `StringName` | Entity whose standing moved (local controller). |
| `delta` | `float` | Applied standing change (after stickiness/clamp). |
| `reason` | `StringName` | Mutation tag (e.g. `&"combat_kill"`). |

**Emitted by** `src/systems/attribution/AttributionService.gd`.
**Listened to by** `FlightHUD` (temporary kill toast naming the entity) and tests.

### `on_kill_unattributed(system_id: StringName, victim_entity_id: StringName)`

Kill was not attributed; no standing change from this report.

| Parameter | Type | Meaning |
|---|---|---|
| `system_id` | `StringName` | System where the kill occurred. |
| `victim_entity_id` | `StringName` | Victim's primary Entity (may be empty). |

**Emitted by** `src/systems/attribution/AttributionService.gd`.
**Listened to by** `FlightHUD` (temporary “not recorded” toast) and tests.

### `on_mission_accept_requested(template_id: StringName)`

UI or console asked to accept this contract template.

| Parameter | Type | Meaning |
|---|---|---|
| `template_id` | `StringName` | ContractType content id. |

**Emitted by** `StationMenu` (Accept courier job) and may be used by other UI.
**Listened to by** `MissionService`.

### `on_mission_accepted(template_id: StringName, offering_entity_id: StringName)`

Player accepted a mission (one active max).

| Parameter | Type | Meaning |
|---|---|---|
| `template_id` | `StringName` | ContractType content id. |
| `offering_entity_id` | `StringName` | Entity that offered the job. |

**Emitted by** `src/systems/mission/MissionService.gd`.

### `on_mission_completed(template_id: StringName, entity_id: StringName, delta: float)`

Mission completed; standing delta already applied via StandingService.

| Parameter | Type | Meaning |
|---|---|---|
| `template_id` | `StringName` | ContractType content id. |
| `entity_id` | `StringName` | Offering Entity. |
| `delta` | `float` | Applied standing change. |

**Emitted by** `src/systems/mission/MissionService.gd`.

### `on_mission_failed(template_id: StringName, entity_id: StringName, delta: float)`

Mission failed after an attempt; milder negative standing already applied.

| Parameter | Type | Meaning |
|---|---|---|
| `template_id` | `StringName` | ContractType content id. |
| `entity_id` | `StringName` | Offering Entity. |
| `delta` | `float` | Applied standing change. |

**Emitted by** `src/systems/mission/MissionService.gd`.

### `on_mission_abandoned(template_id: StringName, entity_id: StringName, delta: float)`

Mission abandoned; stronger negative standing already applied.

| Parameter | Type | Meaning |
|---|---|---|
| `template_id` | `StringName` | ContractType content id. |
| `entity_id` | `StringName` | Offering Entity. |
| `delta` | `float` | Applied standing change. |

**Emitted by** `src/systems/mission/MissionService.gd`.

## Personal recovery (A4)

### `on_recovery_accept_requested(person_id: StringName)`

UI or console asked to accept the next recovery step from this Person.

| Parameter | Type | Meaning |
|---|---|---|
| `person_id` | `StringName` | Person content id offering the step. |

**Emitted by** `StationMenu` (Talk to …) and may be used by other UI.
**Listened to by** `RecoveryService`.

### `on_recovery_offered(chain_id: StringName, step_id: StringName, person_id: StringName)`

A recovery step is available (announced on dock when gated conditions pass).

| Parameter | Type | Meaning |
|---|---|---|
| `chain_id` | `StringName` | RecoveryChain content id. |
| `step_id` | `StringName` | RecoveryStep id within the chain. |
| `person_id` | `StringName` | Person offering the step. |

**Emitted by** `src/systems/recovery/RecoveryService.gd` on dock. Not emitted while
a recovery step is already active.
**Listened to by** _nobody yet — **Grok Brief 4 (REPAIR-4)** wires `StationMenu`,
which surfaces the offer by direct query today (`StationDockQueries.gd:110`)._ The
emit runs **before** `StationMenu._on_docked`, because `RecoveryService` is an
earlier child of `Main` than the menu; Brief 4's wiring depends on that order and
must pin it with a test.

### `on_recovery_accepted(chain_id: StringName, step_id: StringName, person_id: StringName)`

Player accepted a recovery step (one active max).

| Parameter | Type | Meaning |
|---|---|---|
| `chain_id` | `StringName` | RecoveryChain content id. |
| `step_id` | `StringName` | RecoveryStep id. |
| `person_id` | `StringName` | Person offering the step. |

**Emitted by** `src/systems/recovery/RecoveryService.gd`.

### `on_recovery_completed(chain_id: StringName, step_id: StringName, person_id: StringName, entity_id: StringName, person_delta: float, entity_delta: float)`

Recovery step completed; personal and Entity standing deltas already applied.

| Parameter | Type | Meaning |
|---|---|---|
| `chain_id` | `StringName` | RecoveryChain content id. |
| `step_id` | `StringName` | RecoveryStep id. |
| `person_id` | `StringName` | Person who offered the step. |
| `entity_id` | `StringName` | Entity whose standing moved. |
| `person_delta` | `float` | Applied personal standing change. |
| `entity_delta` | `float` | Applied Entity standing change (after stickiness). |

**Emitted by** `src/systems/recovery/RecoveryService.gd`.

### `on_recovery_failed(chain_id: StringName, step_id: StringName, person_id: StringName, person_delta: float)`

Recovery step failed; mild personal standing hit already applied.

| Parameter | Type | Meaning |
|---|---|---|
| `chain_id` | `StringName` | RecoveryChain content id. |
| `step_id` | `StringName` | RecoveryStep id. |
| `person_id` | `StringName` | Person who offered the step. |
| `person_delta` | `float` | Applied personal standing change. |

**Emitted by** `src/systems/recovery/RecoveryService.gd`.

### `on_recovery_abandoned(chain_id: StringName, step_id: StringName, person_id: StringName, person_delta: float)`

Recovery step abandoned; stronger personal standing hit already applied.

| Parameter | Type | Meaning |
|---|---|---|
| `chain_id` | `StringName` | RecoveryChain content id. |
| `step_id` | `StringName` | RecoveryStep id. |
| `person_id` | `StringName` | Person who offered the step. |
| `person_delta` | `float` | Applied personal standing change. |

**Emitted by** `src/systems/recovery/RecoveryService.gd`.

### `on_recovery_betrayed(person_id: StringName, person_delta: float, entity_delta: float)`

Player betrayed a recovery contact; personal dump and Entity hit already applied.
Route is closed via `on_person_closed`.

| Parameter | Type | Meaning |
|---|---|---|
| `person_id` | `StringName` | Person who was betrayed. |
| `person_delta` | `float` | Applied personal standing change. |
| `entity_delta` | `float` | Applied Entity standing change. |

**Emitted by** `src/systems/recovery/RecoveryService.gd`.

### `on_person_closed(person_id: StringName, reason: StringName)`

A Person's recovery route is closed (betrayal or other tagged close).

| Parameter | Type | Meaning |
|---|---|---|
| `person_id` | `StringName` | Person content id. |
| `reason` | `StringName` | Close tag (e.g. `&"betrayal"`). |

**Emitted by** `src/systems/standing/StandingService.gd` from `close_person()`.

## Minimal playable slice (A5)

### `on_gate_prompt_changed(destination_system_id: StringName, can_jump: bool)`

Gate proximity prompt for the HUD. Empty destination clears the prompt.

| Parameter | Type | Meaning |
|---|---|---|
| `destination_system_id` | `StringName` | Target system of the nearest gate, or empty. |
| `can_jump` | `bool` | True when fuel is enough and the ship is in interact range. |

**Emitted by** `src/entities/GateTravelService.gd`.
**Listened to by** `FlightHUD`.

### `on_jump_requested(destination_system_id: StringName)`

Intent to jump to this system. Main spends fuel and rebuilds the world.

| Parameter | Type | Meaning |
|---|---|---|
| `destination_system_id` | `StringName` | Star system content id. |

**Emitted by** `src/entities/GateTravelService.gd` when the dock/jump action fires at a gate.
**Listened to by** `src/Main.gd`.

### `on_system_exited(system_id: StringName)`

Player left this system (emitted before the destination is built).

| Parameter | Type | Meaning |
|---|---|---|
| `system_id` | `StringName` | System content id being left. |

**Emitted by** `src/Main.gd` on a successful jump.

### `on_credits_changed(credits: int)`

Player credits changed.

| Parameter | Type | Meaning |
|---|---|---|
| `credits` | `int` | New credit balance (>= 0). |

**Emitted by** `src/systems/wallet/WalletService.gd`.
**Listened to by** `FlightHUD`, `StationMenu`.

### `on_fuel_changed(fuel: float, fuel_max: float)`

Player fuel changed.

| Parameter | Type | Meaning |
|---|---|---|
| `fuel` | `float` | Current fuel units. |
| `fuel_max` | `float` | Tank capacity. |

**Emitted by** `src/systems/wallet/FuelService.gd`.
**Listened to by** `FlightHUD`, `StationMenu`.

### `on_condition_changed(condition: float, condition_max: float)`

Ship hull condition changed.

| Parameter | Type | Meaning |
|---|---|---|
| `condition` | `float` | Current condition. |
| `condition_max` | `float` | Max condition. |

**Emitted by** `src/systems/wallet/HullConditionService.gd`.
**Listened to by** `FlightHUD`, `StationMenu`.

## Thin combat (B4)

### `on_weapon_fired()`

A weapon discharged (player or hostile travel bolt).

No parameters.

**Emitted by** `PlayerShip`, `HostileNpc`.
**Listened to by** (optional VFX / HUD later).

### `on_target_lock_changed(locked: bool, label: String, distance: float)`

Player target lock acquired, cycled, or cleared (Tab).

| Parameter | Type | Meaning |
|---|---|---|
| `locked` | `bool` | True when a live target is locked. |
| `label` | `String` | Display name for the locked target (empty when cleared). |
| `distance` | `float` | Metres to the locked target (0 when cleared). |

**Emitted by** `PlayerShip`.
**Listened to by** `FlightHUD`.

### `on_hostile_damaged(remaining_hp: float)`

A combat hostile took damage.

| Parameter | Type | Meaning |
|---|---|---|
| `remaining_hp` | `float` | Hull remaining after the hit (>= 0). |

**Emitted by** `src/world/HostileNpc.gd`.
**Listened to by** `FlightHUD` (locked target hull %).

### `on_hostile_killed(system_id: StringName, victim_entity_id: StringName)`

A combat hostile died. Attribution is reported separately via kill signals.

| Parameter | Type | Meaning |
|---|---|---|
| `system_id` | `StringName` | System where the kill happened. |
| `victim_entity_id` | `StringName` | Entity tag of the victim (e.g. Free Haulers). |

**Emitted by** `src/world/HostileNpc.gd`.
**Listened to by** `FlightHUD` (combat prompt clear).

### `on_player_damaged(condition: float)`

Player hull took combat damage (condition after the hit).

| Parameter | Type | Meaning |
|---|---|---|
| `condition` | `float` | Hull condition after damage. |

**Emitted by** `src/systems/wallet/HullConditionService.gd` (`apply_damage`).
**Listened to by** `FlightHUD` (brief condition line flash).

### `on_player_crippled()`

Hull condition reached zero. As of Job 10 this ends the run: the loss screen
comes up and the career restarts from the most recent save.

No parameters.

**Emitted by** `src/systems/wallet/HullConditionService.gd`.
**Listened to by** `PlayerShip` (disables flight), `FlightHUD`,
`LossScreen` (shows the end of the run when armed),
`Main` (blocks pause / map and stops autosaving a destroyed ship).

### `on_player_repaired_from_cripple()`

Full repair restored condition after a cripple fail state.

No parameters.

**Emitted by** `src/systems/wallet/HullConditionService.gd` (`repair_full`).
**Listened to by** `PlayerShip` (may re-enable flight if undocked), `FlightHUD`.

### `on_mission_complete_requested()`

UI asked to complete the active mission (destination check in MissionService).

No parameters.

**Emitted by** `StationMenu` (Turn in job).
**Listened to by** `MissionService`.

### `on_mission_abandon_requested()`

UI asked to abandon the active mission.

No parameters.

**Emitted by** `StationMenu` (Abandon job).
**Listened to by** `MissionService`.

### `on_recovery_complete_requested()`

UI asked to complete the active recovery step.

No parameters.

**Emitted by** `StationMenu`.
**Listened to by** `RecoveryService`.

### `on_recovery_abandon_requested()`

UI asked to abandon the active recovery step.

No parameters.

**Emitted by** `StationMenu`.
**Listened to by** `RecoveryService`.

### `on_recovery_favor_requested(person_id: StringName)`

UI asked for a small personal favor (bootstrap trust).

| Parameter | Type | Meaning |
|---|---|---|
| `person_id` | `StringName` | Person content id. |

**Emitted by** `StationMenu` (Ask favor).
**Listened to by** `RecoveryService`.

### `on_recovery_betray_requested(person_id: StringName)`

UI asked to betray this Person (or empty for active contact).

| Parameter | Type | Meaning |
|---|---|---|
| `person_id` | `StringName` | Person content id (may be empty). |

**Emitted by** `StationMenu`.
**Listened to by** `RecoveryService`.

### `on_tow_prompt_changed(available: bool, fee_credits: int)`

An emergency tow is (or is no longer) on offer — the tank is dry, the ship is
free-flying, the hull is still whole, and some station in this system will take
it. Job 10 / PT-11. Only emitted when the answer changes.

| Parameter | Type | Meaning |
|---|---|---|
| `available` | `bool` | True while a tug can be called. |
| `fee_credits` | `int` | What the tug would take right now, already capped by what the pilot holds (so `0` when broke). |

**Emitted by** `src/entities/RescueService.gd`.
**Listened to by** `FlightHUD` (the prompt line that names the key and the fee).

### `on_refuel_requested()`

UI asked to buy a fuel chunk at the docked station.

No parameters.

**Emitted by** `StationMenu`.
**Listened to by** `FuelService`.

### `on_repair_requested()`

UI asked to fully repair the ship at the docked station.

No parameters.

**Emitted by** `StationMenu`.
**Listened to by** `HullConditionService`.

### `on_loan_borrow_requested()`

UI asked to take the Free Haulers emergency loan (E3.2, docked Services).

No parameters.

**Emitted by** `StationMenu`.
**Listened to by** `WalletService`.

### `on_loan_repay_requested()`

UI asked to repay open debt from credits (E3.2, docked Services).

No parameters.

**Emitted by** `StationMenu`.
**Listened to by** `WalletService`.

### `on_debt_changed(debt_owed: int, lender_id: StringName, grace_docks_left: int)`

Emergency loan debt state changed (borrow, garnish, repay, grace burn, load).

| Parameter | Type | Meaning |
|---|---|---|
| `debt_owed` | `int` | Credits still owed (>= 0). |
| `lender_id` | `StringName` | Lender Entity id, or empty when clear. |
| `grace_docks_left` | `int` | Grace dock events remaining before standing hit. |

**Emitted by** `src/systems/wallet/WalletService.gd`.
**Listened to by** `StationMenu`, `CaptainSheet`.

## Session shell (B2)

### `on_new_game_requested()`

Main menu asked to start a new career.

No parameters.

**Emitted by** `MainMenu`.
**Listened to by** `Main`.

### `on_continue_requested()`

Main menu asked to continue the most recent career save.

No parameters.

**Emitted by** `MainMenu`.
**Listened to by** `Main`.

### `on_quit_to_desktop_requested()`

Main menu asked to quit the application.

No parameters.

**Emitted by** `MainMenu`.
**Listened to by** `Main`.

### `on_quit_to_menu_requested()`

Pause menu asked to leave play and return to the main menu.

No parameters.

**Emitted by** `PauseMenu`.
**Listened to by** `Main`.

### `on_life_path_confirmed(origin_id: StringName, trade_id: StringName, mark_id: StringName)`

Life-path create screen confirmed three axis picks. Main applies teeth via
CareerStart then shows annexation.

| Parameter | Type | Meaning |
|---|---|---|
| `origin_id` | `StringName` | Chosen origin option content id. |
| `trade_id` | `StringName` | Chosen former-trade option content id. |
| `mark_id` | `StringName` | Chosen mark option content id. |

**Emitted by** `LifePathCreate`.
**Listened to by** `Main`.

### `on_life_path_cancel_requested()`

Life-path create screen cancelled. Main tears play down and returns to menu.

No parameters.

**Emitted by** `LifePathCreate`.
**Listened to by** `Main`.

### `on_annexation_continue_requested()`

Opening annexation beat dismissed. Main docks at starter and shows fly tip.

No parameters.

**Emitted by** `OpeningAnnexation`.
**Listened to by** `Main`.

### `on_pause_changed(open: bool)`

Pause overlay opened or closed. Flight input freezes while open.

| Parameter | Type | Meaning |
|---|---|---|
| `open` | `bool` | True when the pause menu is shown. |

**Emitted by** `Main` (Escape toggle), `PauseMenu` (Resume).
**Listened to by** `PauseMenu`, `PlayerShip`, `DockingService`, `GateTravelService`, `Main`.

### `on_captain_sheet_open_requested()`

UI asked to open the captain sheet.

No parameters.

**Emitted by** `PauseMenu`.
**Listened to by** `CaptainSheet`.

### `on_captain_sheet_close_requested()`

UI asked to close the captain sheet.

No parameters.

**Emitted by** `CaptainSheet` (Close), `Main` (Escape while sheet open).
**Listened to by** `CaptainSheet`.

### `on_sector_map_open_requested()`

UI asked to open the sector chart (E5.5).

No parameters.

**Emitted by** `PauseMenu`, `Main` (M key in flight).
**Listened to by** `SectorMapPanel`.

### `on_sector_map_close_requested()`

UI asked to close the sector chart.

No parameters.

**Emitted by** `SectorMapPanel` (Close), `Main` (Escape while map open).
**Listened to by** `SectorMapPanel`.

### `on_manual_save_requested()`

Pause menu asked to write the default career save.

No parameters.

**Emitted by** `PauseMenu`.
**Listened to by** `Main`.

### `on_manual_load_requested()`

Pause menu asked to load the most recent career save.

No parameters.

**Emitted by** `PauseMenu`.
**Listened to by** `Main`.

### `on_run_restart_requested()`

The run ended at zero hull and the player chose to start again from the most
recent save. Job 10. `Main` rebuilds the whole session from the file rather than
patching the live one — the run is over, so the ship, the world and every
service are built fresh.

No parameters.

**Emitted by** `LossScreen` (Restart from last save).
**Listened to by** `Main`.

### `on_options_open_requested()`

Main or pause menu asked to open the options panel (S10).

No parameters.

**Emitted by** `MainMenu`, `PauseMenu`.
**Listened to by** `OptionsMenu`.

### `on_options_close_requested()`

Options panel closed (S10).

No parameters.

**Emitted by** `OptionsMenu`.
**Listened to by** `OptionsMenu` (self), optional UI.

### `on_settings_changed()`

SettingsService applied an option or rebind (S10).

No parameters.

**Emitted by** `SettingsService`.
**Listened to by** `ChaseCamera`, `OptionsMenu`, optional HUD.

## Trade / cargo

### `on_trade_buy_requested(commodity_id: StringName, quantity: int)`

UI asked to buy this commodity quantity at the docked station.

| Parameter | Type | Meaning |
|---|---|---|
| `commodity_id` | `StringName` | Commodity content id. |
| `quantity` | `int` | Units to buy. |

**Emitted by** `StationMenu`.
**Listened to by** `CargoService`.

### `on_trade_sell_requested(commodity_id: StringName, quantity: int)`

UI asked to sell this commodity quantity at the docked station.

| Parameter | Type | Meaning |
|---|---|---|
| `commodity_id` | `StringName` | Commodity content id. |
| `quantity` | `int` | Units to sell. |

**Emitted by** `StationMenu`.
**Listened to by** `CargoService`.

### `on_cargo_changed()`

Cargo hold contents or used volume changed.

No parameters.

**Emitted by** `CargoService`.
**Listened to by** `StationMenu`, `CaptainSheet` (when open / refresh).

### `on_trade_completed(side: StringName, commodity_id: StringName, quantity: int, credits_delta: int)`

A legal buy or sell finished; credits and cargo already updated.

| Parameter | Type | Meaning |
|---|---|---|
| `side` | `StringName` | `&"buy"` or `&"sell"`. |
| `commodity_id` | `StringName` | Commodity content id. |
| `quantity` | `int` | Units traded. |
| `credits_delta` | `int` | Credit change (negative for buy, positive for sell). |

**Emitted by** `CargoService`.
**Listened to by** (debug / future sheet money event; optional).

`MarketService` is a new autoload landing in this phase (S2) — it does not yet
exist elsewhere in the tree you can see, but the four signals below are its
contract with the rest of the game.

### `on_market_changed(station_id: StringName, commodity_id: StringName, stock: int, unit_buy_price: int)`

A player trade moved a station's market for this commodity.

| Parameter | Type | Meaning |
|---|---|---|
| `station_id` | `StringName` | Station whose market moved. |
| `commodity_id` | `StringName` | Commodity content id. |
| `stock` | `int` | Station's whole-unit stock after the trade. |
| `unit_buy_price` | `int` | New price for one more unit. |

**Emitted by** `MarketService` only when a player trade commits — never during
simulation ticks.
**Listened to by** the station trade UI.

### `on_market_ticked(steps_applied: int, elapsed_seconds: float)`

A catch-up batch of market sim steps finished bringing the market in line with
`WorldClock`. One emit per batch, not per step.

| Parameter | Type | Meaning |
|---|---|---|
| `steps_applied` | `int` | Sim steps applied in this batch. |
| `elapsed_seconds` | `float` | World clock total elapsed seconds at that moment. |

**Emitted by** `MarketService` after it runs pending sim steps to catch up with
`WorldClock`. One emit per batch whatever the batch size — a 10,000-step
advance still produces a single emission.
**Listened to by** station UI and the news ticker.

### `on_market_news(line: String)`

A new one-line sector headline is available for the ticker.

| Parameter | Type | Meaning |
|---|---|---|
| `line` | `String` | Headline text. |

**Emitted by** `MarketService` when the headline changes; also `IncidentService`
when a real incident echo is pushed (S3b shared feed).
**Listened to by** the station menu news ticker; FlightHUD toast while free-flying (S3b).

### `on_incident_respond_requested(incident_id: StringName, choice: StringName)`

UI or console is asking `IncidentService` to resolve an offered incident with this
choice. A request, not a fact — the service decides whether the choice is legal.

| Parameter | Type | Meaning |
|---|---|---|
| `incident_id` | `StringName` | Instance id from `on_incident_prompt`. |
| `choice` | `StringName` | One of `BalanceIncident`'s `CHOICE_*` values. |

**Emitted by** _nobody yet — **Grok Brief 4 (REPAIR-4)** routes
`src/ui/hud/FlightHUD.gd:794`, which calls `IncidentService.respond()` directly
from a UI script today._
**Listened to by** _nobody yet — **Grok Brief 4** has
`src/systems/incident/IncidentService.gd` listen._ Named `_requested` per the
naming rule above; the audit and Brief 4 called it `on_incident_respond`, which
would have been the only intent signal on the bus without the suffix. Declared by
Opus Job 12 because changing the signal set is not a brief's to make.

**`on_incident_offered` used to sit here and was removed by Opus Job 12 on
2026-08-07.** It was emitted on the line above `on_incident_prompt` with the same
`incident_id`, `kind` and `prompt`, and nothing but a test connected to it. Its
only extra field was `system_id`, and incidents only ever spawn for the player's
current system (`IncidentService._player_system_id`), so it carried nothing
`on_incident_prompt` does not. Removing it pushed nobody into a direct call —
the surviving signal was already the one `FlightHUD.gd:81` listens to.

### `on_incident_prompt(incident_id: StringName, kind: StringName, prompt: String)`

HUD/console prompt for an offered incident (same moment as offered, or refresh).

| Parameter | Type | Meaning |
|---|---|---|
| `incident_id` | `StringName` | Instance id. |
| `kind` | `StringName` | Incident kind. |
| `prompt` | `String` | Prompt text. |

**Emitted by** `IncidentService`.
**Listened to by** FlightHUD toast while free-flying.

### `on_incident_resolved(incident_id: StringName, kind: StringName, system_id: StringName, outcome: StringName, promoted: bool)`

Incident left the offered set (player respond, expire, or promote).

| Parameter | Type | Meaning |
|---|---|---|
| `incident_id` | `StringName` | Instance id. |
| `kind` | `StringName` | Incident kind. |
| `system_id` | `StringName` | System of the incident. |
| `outcome` | `StringName` | `resolved` / `expired` / `promoted`. |
| `promoted` | `bool` | True when distress became a MissionService job. |

**Emitted by** `IncidentService`.
**Listened to by** (optional UI).

### `on_money_event(reason: StringName, credits_delta: int, credits_after: int, detail: Dictionary)`

Any money path: credits moved, tagged by activity for the telemetry log.

| Parameter | Type | Meaning |
|---|---|---|
| `reason` | `StringName` | Activity tag (trade buy/sell, upkeep, dock fee, refuel, repair, loan, fine, job pay). |
| `credits_delta` | `int` | Signed credit change. |
| `credits_after` | `int` | Credit balance after the change. |
| `detail` | `Dictionary` | Optional context (commodity id, units, unit price, station id, system id); may be empty. |

**Emitted by** `WalletService` (money paths), `FuelService` / `HullConditionService`
(refuel/repair spend after wallet `try_spend`), and `CargoService` on credit movements.
**Listened to by** the money telemetry log.

### `on_contraband_seized(station_id: StringName, entity_id: StringName, commodity_ids: PackedStringArray, fine_paid: int, standing_delta: float)`

Fee-charging dock inspection found goods restricted for the station controller.
Fine and standing hit already applied (standing via StandingService only).

| Parameter | Type | Meaning |
|---|---|---|
| `station_id` | `StringName` | Dock where inspection ran. |
| `entity_id` | `StringName` | Controller Entity that enforced (e.g. Reach). |
| `commodity_ids` | `PackedStringArray` | Restricted commodity ids found (string form). |
| `fine_paid` | `int` | Credits actually taken (partial if broke). |
| `standing_delta` | `float` | Applied standing change for that Entity. |

**Emitted by** `CargoService` (`inspect_on_dock`, real docks only).
**Listened to by** `EnforcementService` (S4 heat from contraband in patrolled/contested
space) and optional UI toast; console line also emitted.

### `on_heat_changed(entity_id: StringName, heat: float, reason: StringName)`

Per-Entity enforcement heat changed (S4). **Not** a standing mutation — heat is
patrol pressure only. Standing still moves only through StandingService.

| Parameter | Type | Meaning |
|---|---|---|
| `entity_id` | `StringName` | Entity that would enforce (e.g. Reach). |
| `heat` | `float` | New heat after the change (0..HEAT_MAX). |
| `reason` | `StringName` | `heat_kill` / `heat_customs_flee` / `heat_contraband` / `heat_decay` / `heat_set`. |

**Emitted by** `EnforcementService` only.
**Listened to by** (optional UI / telemetry).

## Hull ownership / switch (E2.5)

### `on_buy_fighter_requested()`

UI asked to buy the Fighter hull once at the docked station Services desk.

No parameters.

**Emitted by** `StationMenu`.
**Listened to by** `ShipService`.

### `on_switch_hull_requested(hull_id: StringName)`

UI asked to switch the active player hull while docked.

| Parameter | Type | Meaning |
|---|---|---|
| `hull_id` | `StringName` | Target owned hull content id. |

**Emitted by** `StationMenu`.
**Listened to by** `ShipService`.

### `on_hull_purchased(hull_id: StringName)`

A hull was purchased once; ownership updated (active hull unchanged).

| Parameter | Type | Meaning |
|---|---|---|
| `hull_id` | `StringName` | Hull content id now owned (e.g. `&"hull_fighter"`). |

**Emitted by** `ShipService`.
**Listened to by** `StationMenu`, `CaptainSheet` (refresh when open).

### `on_hull_changed(old_hull_id: StringName, new_hull_id: StringName)`

Active flyable hull changed (station switch, load, or direct set).

| Parameter | Type | Meaning |
|---|---|---|
| `old_hull_id` | `StringName` | Previous active hull content id. |
| `new_hull_id` | `StringName` | New active hull content id. |

**Emitted by** `ShipService`.
**Listened to by** `PlayerShip` (flight/weapon/silhouette), `StationMenu`, `CaptainSheet`.

## Outfitting / loadout (S5)

### `on_outfit_install_requested(item_id: StringName)`

UI asked to buy and install a weapon or equipment item on the active hull while
docked.

| Parameter | Type | Meaning |
|---|---|---|
| `item_id` | `StringName` | Weapon or equipment content id. |

**Emitted by** `StationOutfitUi` (via station menu buttons).
**Listened to by** `ShipService`.

### `on_outfit_uninstall_requested(item_id: StringName, slot_index: int)`

UI asked to remove an installed weapon or equipment module and refund sell-back.

| Parameter | Type | Meaning |
|---|---|---|
| `item_id` | `StringName` | Content id in that slot (used to pick weapon vs equipment path). |
| `slot_index` | `int` | Slot index within weapons or equipment array. |

**Emitted by** `StationOutfitUi`.
**Listened to by** `ShipService`.

### `on_loadout_changed(hull_id: StringName)`

Weapons or equipment on a hull changed (install, remove, or load apply).

| Parameter | Type | Meaning |
|---|---|---|
| `hull_id` | `StringName` | Hull content id whose loadout changed. |

**Emitted by** `ShipService`.
**Listened to by** `PlayerShip` (reapply weapon/turn/afterburner), `StationMenu`.

## Operations / warehouse (S6)

### `on_ops_hire_requested(ship_type: StringName)`

UI asked to hire an abstract ops ship type while docked.

| Parameter | Type | Meaning |
|---|---|---|
| `ship_type` | `StringName` | Hireable type (`ops_hauler` / `ops_fighter`). |

**Emitted by** `StationOpsUi` (via station menu buttons).
**Listened to by** `OperationService`.

### `on_ops_fire_requested(ops_ship_id: StringName)`

UI asked to fire a hired abstract ops ship.

| Parameter | Type | Meaning |
|---|---|---|
| `ops_ship_id` | `StringName` | Hired ship id (e.g. `ops_ship_1`). |

**Emitted by** `StationOpsUi`.
**Listened to by** `OperationService`.

### `on_ops_order_requested(ops_ship_id: StringName, order: StringName, origin_station: StringName, dest_station: StringName, commodity_id: StringName)`

UI asked to set an order on a hired ops ship.

| Parameter | Type | Meaning |
|---|---|---|
| `ops_ship_id` | `StringName` | Hired ship id. |
| `order` | `StringName` | `park` / `haul_route` / `escort_player`. |
| `origin_station` | `StringName` | Haul origin (empty for park/escort). |
| `dest_station` | `StringName` | Haul destination (empty for park/escort). |
| `commodity_id` | `StringName` | Haul commodity (empty for park/escort). |

**Emitted by** `StationOpsUi`.
**Listened to by** `OperationService`.

### `on_ops_warehouse_deposit_requested(commodity_id: StringName, quantity: int)`

UI asked to move cargo from the player hold into the dock station warehouse.

| Parameter | Type | Meaning |
|---|---|---|
| `commodity_id` | `StringName` | Commodity content id. |
| `quantity` | `int` | Units to deposit. |

**Emitted by** `StationOpsUi`.
**Listened to by** `OperationService`.

### `on_ops_warehouse_withdraw_requested(commodity_id: StringName, quantity: int)`

UI asked to move cargo from the dock station warehouse into the player hold.

| Parameter | Type | Meaning |
|---|---|---|
| `commodity_id` | `StringName` | Commodity content id. |
| `quantity` | `int` | Units to withdraw. |

**Emitted by** `StationOpsUi`.
**Listened to by** `OperationService`.

### `on_ops_ship_hired(ops_ship_id: StringName, ship_type: StringName, charter_entity: StringName)`

An abstract ops ship was hired; credits already spent.

| Parameter | Type | Meaning |
|---|---|---|
| `ops_ship_id` | `StringName` | New hired ship id. |
| `ship_type` | `StringName` | Hireable type. |
| `charter_entity` | `StringName` | Dock controller Entity id at hire. |

**Emitted by** `OperationService`.
**Listened to by** `StationMenu`.

### `on_ops_ship_fired(ops_ship_id: StringName)`

An abstract ops ship was fired or released after charter breach.

| Parameter | Type | Meaning |
|---|---|---|
| `ops_ship_id` | `StringName` | Fired ship id. |

**Emitted by** `OperationService`.
**Listened to by** `StationMenu`.

### `on_ops_order_changed(ops_ship_id: StringName, order: StringName)`

Order field on a hired ship changed.

| Parameter | Type | Meaning |
|---|---|---|
| `ops_ship_id` | `StringName` | Hired ship id. |
| `order` | `StringName` | New order. |

**Emitted by** `OperationService`.
**Listened to by** `StationMenu`.

### `on_ops_upkeep_paid(credits: int)`

Fleet retainer upkeep credits paid this world-clock tick (may be partial).

| Parameter | Type | Meaning |
|---|---|---|
| `credits` | `int` | Whole credits spent this tick. |

**Emitted by** `OperationService`.
**Listened to by** `StationMenu` (refresh).

### `on_ops_charter_breached(ops_ship_id: StringName, entity_id: StringName)`

Charter breached after missed upkeep threshold; standing already written via
StandingService; ship is fired after this signal.

| Parameter | Type | Meaning |
|---|---|---|
| `ops_ship_id` | `StringName` | Ship that breached. |
| `entity_id` | `StringName` | Charter Entity that took the standing hit. |

**Emitted by** `OperationService`.

### `on_warehouse_changed(station_id: StringName)`

Warehouse contents at a station changed (deposit / withdraw / load).

| Parameter | Type | Meaning |
|---|---|---|
| `station_id` | `StringName` | Station whose warehouse changed. |

**Emitted by** `OperationService`.
**Listened to by** `StationMenu`.

### `on_campaign_flag_set(flag_name: StringName)`

A campaign flag became true (spine progress / act start).

| Parameter | Type | Meaning |
|---|---|---|
| `flag_name` | `StringName` | Flag constant (e.g. `flag_wake_done`). |

**Emitted by** `CampaignService`.
**Listened to by** `CampaignJournal`, `StationCampaignUi` (via StationMenu refresh).

### `on_spine_completed(template_id: StringName)`

A campaign spine beat completed successfully (after mission complete + flags).

| Parameter | Type | Meaning |
|---|---|---|
| `template_id` | `StringName` | Spine `ContractType` content id. |

**Emitted by** `CampaignService`.
**Listened to by** `CampaignJournal`, `StationCampaignUi`.

### `on_campaign_act_changed(act: int)`

Career campaign act advanced (1 = Act I, 2 = Act II, 3 = reserved Act III).

| Parameter | Type | Meaning |
|---|---|---|
| `act` | `int` | New act number. |

**Emitted by** `CampaignService`.
**Listened to by** `CampaignJournal`, `StationCampaignUi`.

### `on_spine_accept_requested(template_id: StringName)`

UI asked to accept a campaign spine template (Story section).

| Parameter | Type | Meaning |
|---|---|---|
| `template_id` | `StringName` | Spine content id. |

**Emitted by** `StationCampaignUi` (Story accept buttons).
**Listened to by** `CampaignService` → `MissionService.accept` (library path).

### `on_campaign_journal_open_requested()`

UI asked to open the campaign journal panel.

No parameters.

**Emitted by** `PauseMenu` (Journal button).
**Listened to by** `CampaignJournal`.

### `on_campaign_journal_close_requested()`

UI asked to close the campaign journal panel.

No parameters.

**Emitted by** `CampaignJournal` close button / Esc path via Main.
**Listened to by** `CampaignJournal`.

### `on_holding_purchase_requested(station_id: StringName)`

UI asked to purchase a Holding at this candidate station (S8).

| Parameter | Type | Meaning |
|---|---|---|
| `station_id` | `StringName` | Candidate station to claim. |

**Emitted by** `StationHoldingUi` (Purchase button).
**Listened to by** `CampaignService` → `try_purchase_holding`.

### `on_holding_claimed(station_id: StringName, price_paid: int)`

Player purchased a Holding (debt clear, milestones, credits spent).

| Parameter | Type | Meaning |
|---|---|---|
| `station_id` | `StringName` | Station claimed as Holding. |
| `price_paid` | `int` | Credits spent (effective price after milestones). |

**Emitted by** `CampaignService`.
**Listened to by** `StationHoldingUi` (via StationMenu refresh).

### `on_holding_ignited(station_id: StringName)`

Ignition crisis spine complete; campaign complete; sandbox continues.

| Parameter | Type | Meaning |
|---|---|---|
| `station_id` | `StringName` | Claimed Holding station. |

**Emitted by** `CampaignService` after `flag_campaign_complete`.
**Listened to by** `StationHoldingUi` (via StationMenu refresh).
