# Autoload globals

Must match `[autoload]` in `project.godot` in both directions.
Checked by `scripts/check_globals.py`.

A name may be global only if it is on this list with a one-line justification.

### `EventBus` -> `res://src/systems/EventBus.gd`

Cross-system signal bus. The sanctioned channel for cross-domain communication.
