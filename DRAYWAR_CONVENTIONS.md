# DRAYWAR — Engineering Conventions

**Version:** 1.1 — **informational, not an authority.**
**Origin:** Codified from Project Astraeus `_PROJECT_RULES.md`. Where other Draywar docs say "Astraeus conventions," they mean this file.

**Status (Elliot's ruling, session 3):** *"Take that document more as informational than as in a concrete way you need to do things."* This is the house style, not law. It does **not** sit in the authority chain (`CLAUDE.md` §1), it does not outrank the guardrails, the destination doc or the phase plan, and it never reopens a completed contract on its own. Follow it where it fits. Where it fights something already built and proven, **the working code wins** — record the divergence in the journal and move on.

**Nothing in this file is grounds to stop a run.** v1.0 carried two halt-and-ask triggers (§4, §6); both are removed. Questions this file raises are gathered into the phase-opening brief (`CLAUDE.md` §5.1), never raised mid-contract.

---

## 1. Engine & Environment

| Item | Requirement |
|------|-------------|
| Engine | Godot 4.x |
| Language | GDScript 2.0 |
| Typing | Strict typing on every variable, parameter, and return. No exceptions. |
| Paradigm | Composition over inheritance. Prefer adding Node components to building deep class hierarchies. |
| File format | Text-based only (`.gd`, `.tscn`, `.tres`). No binary scene or resource blobs. |

### 1.1 Strict typing — examples

```gdscript
# CORRECT
var current_hull: float = 100.0
func apply_damage(amount: float, source_id: StringName) -> void:
    pass

# FORBIDDEN
var current_hull = 100.0
func apply_damage(amount, source_id):
    pass
```

---

## 2. Communication Architecture (Strict IDD)

| Rule | Detail |
|------|--------|
| **No direct polling** | Nodes may never directly read variables from other sibling nodes. `enemy.hull` accessed from another node is forbidden. |
| **Signal bus pattern** | All cross-domain communication routes through the `EventBus.gd` autoload. |
| **State mutation ownership** | Only the node that *owns* a piece of data may modify it. Other nodes emit a signal requesting the change; the owner decides whether to honor it. |

### 2.1 Pattern — requesting a change

```gdscript
# WRONG — direct mutation from outside
target_ship.current_hull -= 25.0

# CORRECT — emit a signal; the owner mutates its own state
EventBus.on_damage_applied.emit(damage_payload)
```

The owning node listens for `on_damage_applied`, applies the change to its own state, and emits any downstream signals (`on_ship_destroyed`, `on_player_standing_changed`, etc.).

### 2.2 Signal catalog

Every EventBus signal is declared in `EventBus.gd` **and** documented in `/docs/events.md` (name, payload type, emitter, known listeners) in the same commit that adds it. A signal referenced anywhere but absent from the catalog is a bug. Signal names are `snake_case`, prefixed `on_` (e.g. `on_system_entered`, `on_contract_completed`, `on_upkeep_cycle_due`).

---

## 3. Node & Scene Structure

| Rule | Detail |
|------|--------|
| **Encapsulation** | Every discrete mechanical unit is its own `.tscn` scene with an attached `.gd` script. |
| **UI separation (strict MVC)** | UI scripts may only listen to `EventBus` signals to update visuals. They never calculate game logic and never hold authoritative game state. |

### 3.1 MVC boundary — examples

```gdscript
# CORRECT — UI subscribes, displays
func _ready() -> void:
    EventBus.on_player_standing_changed.connect(_on_standing_changed)

func _on_standing_changed(faction_id: StringName, new_state: StringName) -> void:
    label.text = "%s: %s" % [faction_id, new_state]

# FORBIDDEN — UI computing logic
func _on_sell_pressed() -> void:
    var price: float = commodity.base * station.mod   # NO
    player.credits += price                            # NO — emit a request signal instead
```

---

## 4. Data, Schema, and Constants

- **Do not invent data structures quietly.** All Resource shapes, enums, and save fields are defined in `/docs/save_schema.md` and the data definitions under `/src/data`. A shape a phase needs and does not have is raised in the **phase-opening brief** (`CLAUDE.md` §5.1). If one is discovered mid-phase anyway, define it, document it in the same commit, and journal the reasoning — **do not halt.** *(v1.0 said HALT here; removed on Elliot's ruling — it would stall long runs.)*
- **All tunable numbers live in `Balance.gd`**, never hardcoded in logic. If a number could conceivably be tuned, it goes in the balance file. *(v1.0 said "(autoload)". Draywar's `Balance.gd` is a `class_name` script, already globally reachable without consuming a global name slot. Intent satisfied; mechanism differs deliberately — see the globals policy, journal 003#4.)*
- **All content is data-defined** (`.tres`/JSON under `/src/data`), never hardcoded — hulls, weapons, commodities, factions, systems, stations, contracts, character options.

---

## 5. Naming & File Headers

- Classes/nodes/scenes: `PascalCase`. Variables/functions/signals: `snake_case`. Constants: `UPPER_SNAKE_CASE`. Data resource files: `snake_case.tres`.
- Every `.gd` file opens with a header comment tying it to the plan:

```gdscript
# StandingService.gd
# Implements: DRAYWAR_PHASE_PLAN.md P4.1
```

- Commit messages are contract-ID-prefixed: `P4.1: faction standing service + transition tests`.

---

## 6. Documentation Style (for any docs the agent writes)

Matches the established contract style: terse directive language, tables over prose, `gdscript`-fenced code blocks with strict typing.

Anything inferred rather than told is flagged `⚠️ Proposed — Review Required` and **carried to the next phase boundary** for Elliot to batch-answer — never silently treated as decided, and never used to stall the run. *(v1.0 implied a mid-flight halt-and-ask; removed on Elliot's ruling. Flag it, record it in the journal, keep building — `CLAUDE.md` §5.2.)*

Documents Elliot reads are exempt from the terse-and-tabular style: `CLAUDE.md` §2 governs those, and it wins. Plain English, no jargon.

---

## 7. Output Discipline

- When generating a system, produce both the `.gd` script and the plain-text `.tscn` scene structure.
- Every new persistent field is added to the save round-trip test in the same commit.
- Lint and strict-typing checks pass before a contract may be reported complete (see guardrails §3, Definition of Done — that section and this file are one standard).
