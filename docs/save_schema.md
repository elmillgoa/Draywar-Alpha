# Save schema

**Version 1.** Alpha A0 foundation. Code: `src/systems/save/`.

Saves may be broken freely until release. Nothing here is future-proofed beyond
the handful of fields whose absence would cost a redesign.

---

## The short version

A save is a **versioned envelope** wrapped around a dictionary of **sections**,
one per game system. The envelope is defined exactly and has no opinion about
what is inside a section.

**Version 1 stores the envelope only.** There is no captain, ship or wallet in
the game yet. Debug `save`/`load` write an empty `sections` (or tests use a
hostile probe fixture). Later contracts add real sections and bump the version
with a migration step in `SaveMigrations.gd`.

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

Files live under `user://saves/*.sav`.
