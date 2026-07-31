extends Node
## Cross-system signal bus. All cross-domain communication goes through here.
## Catalog: docs/events.md — keep that file in the same commit as any new signal.

## TimeScale: the effective rate clocks will get after a change.
signal on_time_scale_changed(scale: float)

## TimeScale: combat lock opened or closed.
signal on_combat_lock_changed(locked: bool)

## SaveService: a career was loaded successfully from this path.
signal on_save_loaded(path: String)

## ConsoleService: who is out there? Systems answer with registrations.
signal on_console_commands_requested

## A system is offering a command for the console roster.
signal on_console_command_registered(name: StringName, usage: String, summary: String)

## ConsoleService: a registered name was submitted with these args.
signal on_console_command_invoked(name: StringName, args: PackedStringArray)

## Anything with something to say to the console view.
signal on_console_output(line: String)

## DebugConsole: the prompt opened or closed.
signal on_console_visibility_changed(open: bool)

## SystemWorld: the player is now in this system (session-only for A1).
signal on_system_entered(system_id: StringName)

## Player / DockingService: request to dock at this station.
signal on_dock_requested(station_id: StringName)

## DockingService: ship is now docked at this station.
signal on_docked(station_id: StringName)

## UI: request to leave this station.
signal on_undock_requested(station_id: StringName)

## DockingService: ship has left this station and is free-flying again.
signal on_undocked(station_id: StringName)

## DockingService: dock prompt state for the HUD (empty id clears).
signal on_dock_prompt_changed(station_id: StringName, can_dock: bool)

## PlayerShip: speed magnitude changed (session HUD).
signal on_player_speed_changed(speed: float)

## PlayerShip: throttle 0..1 changed (session HUD).
signal on_player_throttle_changed(throttle: float)

## StandingService: player standing with an Entity changed.
signal on_entity_standing_changed(
	entity_id: StringName, old_value: float, new_value: float, tier: StringName
)

## StandingService: player standing with a Person changed.
signal on_person_standing_changed(
	person_id: StringName, old_value: float, new_value: float, tier: StringName
)

## StandingService: protected status moment (system or station entry).
signal on_status_moment(
	kind: StringName, place_id: StringName, entity_id: StringName, standing: float, tier: StringName
)

## DockingService: dock blocked by standing with the station controller.
signal on_dock_refused(
	station_id: StringName, entity_id: StringName, standing: float, tier: StringName
)
