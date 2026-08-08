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

### 2.0 Sanctioned EventBus exceptions (REPAIR-4)

These are the only UI/world → service call sites allowed to remain after the
EventBus wiring pass. Everything else of this shape is a violation.

| Site | Call | Why it stays |
|------|------|--------------|
| `src/ui/station/StationDockQueries.offered_recovery_person` | `RecoveryService.has_offer_for_person` via group service | **Test helper only**, and `tests/test_e4_recovery_jax.gd::test_station_queries_scope_favor_and_offer_by_controller` is what keeps that true — if it ever stops calling this, the exception has no reason left and the function should go. Production Talk reads the person from the `on_recovery_offered` cache on `StationMenu` (REPAIR-4) and no production path calls this. |
| `src/systems/time/TimeConsoleCommands` | `TimeScale.set_combat_lock` | **Systems-layer debug console**, not UI/world. Combat lock from world code rides `on_combat_lock_requested`. |

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

### 2.3 Group lookups — the second channel, and it is declared

**Verdict on audit finding #79, decided 2026-08-06.**

A signal has no return value. A caller that must *ask* something rather than
announce it needs a handle to the thing it is asking, and this project answers
that in two ways: an autoload reached by bare name, and a **node group lookup** —
`tree.get_first_node_in_group(&"wallet_service")`.

The group lookup is a service locator, and it crosses the same boundaries
`scripts/check_boundaries.py` polices. It carries no `res://` path and no
`class_name`, so that gate could not see the mechanism at all — not a file type
it missed, the entire route. Measured on 2026-08-06: **85 call sites across
`src/`, in 28 files.** Of the **37 under `src/systems/`, 21 reach another
system** — which is what rule 2 of the boundary gate forbids in its static form —
and **15 reach another layer**, which is rule 1. Eight of the group names in play
were raw strings with no constant anywhere. There are **20 groups** in total —
two of them (`impact_body`, `money_log`) are added by a producer and looked up by
nobody, which nothing in the project had noticed until the registry was built.

**This is sanctioned, and it is not a blanket exemption.** Thirty-seven call
sites cannot be waived by naming two of them, and forbidding the mechanism would
mean redesigning the architecture rather than enforcing it. So the pattern stays
legal and becomes **declared**: every group is listed in **`docs/groups.md`**
with the file that adds its members, that file's layer, and the layers permitted
to look it up. **`scripts/check_groups.py`** enforces the list in both
directions and fails the build on a group that is looked up but undeclared, a
lookup from a layer the registry does not permit, or a declared group nobody
produces.

The consequence that matters: **a group lookup added tomorrow is not covered by
this decision.** It fails the gate until somebody adds it to the registry, which
is the point — the old hole was that new ones arrived silently.

A call site that computes its group name at runtime cannot be resolved
statically. Those are listed by name in `docs/groups.md`; an unresolvable site
that is not on that list fails the gate.

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
# Implements: docs/STEAM_PHASE_PLAN.md S4.1
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
