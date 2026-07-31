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

---

# Catalog

## Time

### `on_time_scale_changed(scale: float)`

The effective game time rate changed (after combat lock is applied).

| Parameter | Type | Meaning |
|---|---|---|
| `scale` | `float` | Rate clocks will get. One of `Balance.TIME_SCALES`, or 1.0 while locked. |

**Emitted by** `src/systems/time/TimeScale.gd`.
**Listened to by** displays (not clocks — clocks ask every tick).

### `on_combat_lock_changed(locked: bool)`

The combat lock that forces time to 1x opened or closed.

| Parameter | Type | Meaning |
|---|---|---|
| `locked` | `bool` | True when combat is holding time at normal speed. |

**Emitted by** `src/systems/time/TimeScale.gd`.

## Save

### `on_save_loaded(path: String)`

A career was loaded successfully from disk.

| Parameter | Type | Meaning |
|---|---|---|
| `path` | `String` | Absolute path that was read. |

**Emitted by** `src/systems/save/SaveService.gd` from `load_from()` only after
success. Failed / refused loads emit nothing.
**Listened to by** `TimeScale` (resets to 1x).

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
**Listened to by** `FlightHUD` (system name).

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
**Listened to by** `FlightHUD`, `StationMenu`.

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
