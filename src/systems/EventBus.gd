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
