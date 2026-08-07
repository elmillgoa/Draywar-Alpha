# Group lookups

Every Godot group used as a service locator under `src/`: who produces it,
what layer that producer lives in, and which layers are allowed to look it
up.

**This document is checked against the code.** `scripts/check_groups.py`
scans every `add_to_group`, `get_first_node_in_group` and `get_nodes_in_group`
call under `src/` (plus any scene `groups=` assignment) and fails the build
if what it finds disagrees with the catalog below, in any direction.

---

## What a group lookup is, and why it is allowed at all

`scripts/check_boundaries.py` forbids a file in one of the four deciding
layers (`systems`, `entities`, `ui`, `world`) from statically referencing a
file in a different one, and forbids one system referencing another, with
`EventBus` as the one sanctioned channel across both boundaries.

A group lookup is a second channel that gate cannot see, because it carries
neither a `res://` path nor a `class_name`:

```gdscript
var wallet: Node = tree.get_first_node_in_group(&"wallet_service")
```

It exists for the same reason an autoload does (see `docs/events.md`'s own
reasoning for why `EventBus` and `ContentLibrary` are reached by bare name
rather than by reference): **a signal has no return value.** `EventBus` is
fire-and-forget - it can announce that fuel changed, but it cannot answer
"how much fuel do I have right now." A caller that must *ask* something -
`FuelService`, docked at a station, whether the player can afford a top-up -
needs a handle to call a method on, and a Godot group is how a node gets a
handle to another node it was never handed a reference to and does not sit
in the same branch of the tree as.

37 of the project's 85 lookup call sites live in `src/systems`, and 21 of
those reach a *different* system - the exact crossing `check_boundaries.py`'s
rule 2 forbids when it happens by path or `class_name`. Forbidding the
mechanism would break 37 working call sites and amount to redesigning how
this project locates its own services. Sanctioning it by name, silently,
is the blanket exemption an architecture gate cannot survive either. So the
group lookup **stays a sanctioned pattern - but a declared, inventoried
one**, policed the same way `docs/globals.md` polices autoloads: a thing may
occupy this channel only if it is entered here, and a check fails the build
when the real set and this list disagree.

## What the registry means

Each catalog entry below answers three questions a text scan cannot:

1. **Who adds this group?** The file (or files) that call `add_to_group`
   for it, and the layer that file lives in.
2. **Who is allowed to look it up?** The layers that reach it *today*, by
   the checker's own count. This is a recorded fact, not a design ruling -
   see `scripts/check_groups.py`'s own "what this cannot see" section for
   what that distinction does and does not buy you.
3. **Is it actually read anywhere?** A producer nobody consumes is dead
   weight in this list, exactly as a declared-but-unregistered autoload is
   in `docs/globals.md` - *unless* the entry says `(none - write-only)`,
   which is the deliberate declaration that this one has never had a
   consumer and that is expected. `impact_body` and `money_log` are both
   this: real `add_to_group` calls, catalogued because rule 1 below requires
   it, with nothing reading them back. Writing `(none - write-only)` is what
   tells the checker "this is not drift, it is the actual shape of the
   thing" - leaving the field blank would not, and would fail the build on
   the very next run.

A small number of lookups are made through a same-file wrapper function
whose own argument is a parameter, not a literal - the checker cannot read
those statically. Those call sites are catalogued separately, in **Dynamic
call sites** below, and are exempt from the layer-permission check for the
same reason a compiler cannot type-check a `Variant`: there is nothing
static to check.

## How to add a group

1. Add the `add_to_group(...)` call. Prefer a `BalanceX.GROUP_Y` constant in
   `src/data/balance/` over a raw string literal - most of the newer
   producers do; a handful of the earliest ones (`wallet_service`,
   `docking_service`, `cargo_service`, and others below marked "raw string")
   predate that convention and have not been migrated, which is a cleanup,
   not a gate requirement.
2. Add an entry below, in the same commit, following this shape:

   ```
   ### `some_group` -> `src/systems/some/SomeService.gd`

   - **Added by:** `src/systems/some/SomeService.gd:42`
   - **Producer layer:** systems
   - **Permitted consumers:** systems, ui
   ```

   The heading line (`` ### `name` -> `path` ``) and the three bulleted
   fields directly under it are load-bearing - the checker parses exactly
   that shape. Everything else on this page is prose for humans.
3. Run `python scripts/check_groups.py`. Exit 0 means the catalog, the
   producer, and every consumer agree.

If a new lookup reaches a group from a layer not yet listed under
**Permitted consumers**, that is a real new boundary crossing. Decide
whether it belongs - the same judgement call `docs/globals.md`'s four tests
ask for an autoload - and update the entry to say so explicitly. The check
will not make that judgement for you; it only makes sure the judgement gets
written down.

---

# Catalog

### `wallet_service` -> `src/systems/wallet/WalletService.gd`

- **Added by:** `src/systems/wallet/WalletService.gd:37` (raw string)
- **Producer layer:** systems
- **Permitted consumers:** entities, systems, ui

Credits ledger. Looked up by `DockingService` and `RescueService` (entities),
by most of `src/systems` (cargo, mission, ship, fuel, hull, campaign, incident,
recovery, ops, the world clock), and by `CaptainSheet` / `StationHoldingUi`
(ui). Also reached via both dynamic wrappers - see below.

### `fuel_service` -> `src/systems/wallet/FuelService.gd`

- **Added by:** `src/systems/wallet/FuelService.gd:15` (raw string)
- **Producer layer:** systems
- **Permitted consumers:** entities, systems, ui

Looked up by `GateTravelService`, `PlayerShip` and `RescueService` (entities),
`WalletService` (systems, for spend-after-refuel), and `CaptainSheet` (ui).
Also reached via the `CareerSave.gd` wrapper.

### `hull_condition_service` -> `src/systems/wallet/HullConditionService.gd`

- **Added by:** `src/systems/wallet/HullConditionService.gd:16` (raw string)
- **Producer layer:** systems
- **Permitted consumers:** entities, systems, ui, world

Looked up by `HostileProjectile` (world), `DockingService` / `PlayerShip` /
`RescueService` (entities), `WalletService` (systems), and `CaptainSheet` (ui).
The only service whose static lookups already span all four layers. Also
reached via the `CareerSave.gd` wrapper. It is also the single answer to "can
this ship fly": the tow refuses a destroyed hull by asking `can_fly()` here
rather than keeping a flag of its own (Job 10).

### `cargo_service` -> `src/systems/cargo/CargoService.gd`

- **Added by:** `src/systems/cargo/CargoService.gd:29` (raw string)
- **Producer layer:** systems
- **Permitted consumers:** entities, systems, ui

Looked up by `DockingService` (entities), by `OperationService`,
`IncidentService`, `MissionService`, `ShipService` (systems), and by
`CaptainSheet` (ui). Also reached via both dynamic wrappers.

### `mission_service` -> `src/systems/mission/MissionService.gd`

- **Added by:** `src/systems/mission/MissionService.gd:47` (raw string)
- **Producer layer:** systems
- **Permitted consumers:** systems, ui, world

Looked up by `SystemWorld` and `MissionEscortShip` (world), by
`CampaignService`, `IncidentService` and `AttributionService` (systems), and by
`StationMenu` / `FlightHUD` / `CaptainSheet` (ui). Also reached via both dynamic
wrappers. `AttributionService` asks it whether the active job is a bounty and
which system it targets — the sanctioned-kill rule in
`docs/reputation_and_standing.md` §7. Both are questions, which is what this
channel is for; the offering Entity arrives separately on `on_mission_accepted`.

### `recovery_service` -> `src/systems/recovery/RecoveryService.gd`

- **Added by:** `src/systems/recovery/RecoveryService.gd:55` (raw string)
- **Producer layer:** systems
- **Permitted consumers:** (none)
- **Reached via dynamic sites:** `src/systems/save/CareerSave.gd:533`, `src/ui/station/StationMenu.gd:957`

The one group with **no static lookup site at all** - every reach is through
a same-file wrapper (`CareerSave._node_in_group`, `StationMenu._node_in_group`
/ `_group_bool`). The checker cannot verify a layer-permission for this one
the way it can for the others; the two dynamic sites above are the only
proof it is read anywhere, which is exactly why they are required, not
optional, entries.

### `attribution_service` -> `src/systems/attribution/AttributionService.gd`

- **Added by:** `src/systems/attribution/AttributionService.gd:19` (raw string)
- **Producer layer:** systems
- **Permitted consumers:** world

Looked up only by `TrafficShip` and `HostileNpc` - both world. A systems
service reached exclusively from world today; if a systems file ever needs
it too, that is a new permitted-consumer entry, not a silent pass.

### `ship_service` -> `src/systems/ship/ShipService.gd`

- **Added by:** `src/systems/ship/ShipService.gd:20` (`BalanceFlight.GROUP_SHIP_SERVICE`)
- **Producer layer:** systems
- **Permitted consumers:** entities, systems, ui

Looked up by `PlayerShip` (entities), `CargoService` / `HullConditionService`
/ `FuelService` (systems), and `CaptainSheet` (ui). Also reached via both
dynamic wrappers.

### `campaign_service` -> `src/systems/campaign/CampaignService.gd`

- **Added by:** `src/systems/campaign/CampaignService.gd:22` (`BalanceCampaign.GROUP_CAMPAIGN_SERVICE`)
- **Producer layer:** systems
- **Permitted consumers:** ui

Looked up only by `CampaignJournal`, `StationHoldingUi`, `StationCampaignUi`
- all ui. Also reached via the `CareerSave.gd` wrapper (systems).

### `operation_service` -> `src/systems/ops/OperationService.gd`

- **Added by:** `src/systems/ops/OperationService.gd:21` (`BalanceOps.GROUP_OPERATION_SERVICE`)
- **Producer layer:** systems
- **Permitted consumers:** ui

Looked up only by `StationMenu` - ui. Also reached via the `CareerSave.gd`
wrapper (systems).

### `hostile_npc` -> `src/world/HostileNpc.gd`

- **Added by:** `src/world/HostileNpc.gd:49` (`BalanceCombat.GROUP_HOSTILE`)
- **Producer layer:** world
- **Permitted consumers:** ui, world

Looked up by `SystemWorld` and by `HostileNpc` itself (world, `get_nodes_in_group`
scanning for other live hostiles), and by `FlightHUD` (ui).

### `lockable_ship` -> `src/world/TrafficShip.gd`

- **Added by:** `src/world/TrafficShip.gd:28` (`BalanceCombat.GROUP_LOCKABLE`)
- **Producer layer:** world
- **Also added by:** `src/world/HostileNpc.gd`
- **Permitted consumers:** entities

Looked up only by `PlayerShip` (`get_nodes_in_group`, building the Tab-lock
candidate list) - entities. `is_in_group(GROUP_LOCKABLE)` membership checks
also exist (`PlayerShip.gd:865`, `PlayerProjectile.gd:89`) but are out of
this gate's scope - see `scripts/check_groups.py`'s "what this cannot see."

### `npc_traffic` -> `src/world/NpcTraffic.gd`

- **Added by:** `src/world/NpcTraffic.gd:39` (`BalanceEconomy.GROUP_NPC_TRAFFIC`)
- **Producer layer:** world
- **Permitted consumers:** systems, world

Looked up by `TrafficShip` and `HostileNpc` (world), and by `IncidentService`
(systems, ambient-traffic budget check).

### `mission_escort` -> `src/world/MissionEscortShip.gd`

- **Added by:** `src/world/MissionEscortShip.gd:12` (`BalanceBoard.GROUP_MISSION_ESCORT`)
- **Producer layer:** world
- **Permitted consumers:** systems, world

Looked up by `SystemWorld` (world) and `IncidentService` (systems).

### `chase_camera` -> `src/entities/ChaseCamera.gd`

- **Added by:** `src/entities/ChaseCamera.gd:18` (`BalanceFlight.GROUP_CHASE_CAMERA`)
- **Producer layer:** entities
- **Permitted consumers:** systems

Looked up only by `SettingsService` (systems, applying FOV/sensitivity on
settings change) - the one group whose only consumer sits in a different
layer than every other producer's typical audience.

### `system_world` -> `src/Main.gd`

- **Added by:** `src/Main.gd:480` (`BalanceSession.GROUP_SYSTEM_WORLD`)
- **Producer layer:** root
- **Permitted consumers:** entities, systems, ui, world

Added by the composition root, not by a layer - `src/Main.gd` is exempt from
the four deciding layers the same way `check_boundaries.py` exempts it.
Looked up from all four: `DockingService` (entities - see the known
inconsistency below), `TrafficShip` / `HostileNpc` (world), `IncidentService`
/ `CareerSave` (systems), `CaptainSheet` (ui).

### `player_ship` -> `src/Main.gd`

- **Added by:** `src/Main.gd:488` (`BalanceSession.GROUP_PLAYER_SHIP`)
- **Producer layer:** root
- **Permitted consumers:** systems, ui, world

Also composition-root-produced. Looked up by `HostileNpc` / `SystemWorld`
(world), `WorldClock` / `CareerSave` (systems), and `FlightHUD` /
`CombatReticle` / `CaptainSheet` (ui). `is_in_group(GROUP_PLAYER_SHIP)` also
appears at `HostileProjectile.gd:87` - a membership check, out of scope.

### `docking_service` -> `src/entities/DockingService.gd`

- **Added by:** `src/entities/DockingService.gd:26` (raw string)
- **Producer layer:** entities
- **Permitted consumers:** entities, systems, ui, world

Looked up from all four layers: `HostileNpc` (world), `PlayerShip`
(entities), most of `src/systems` (campaign, cargo, ops, hull, mission,
world clock, fuel, ship), and `CombatReticle` (ui). Also reached via the
`CareerSave.gd` wrapper.

### `impact_body` -> `src/world/TrafficShip.gd`

- **Added by:** `src/world/TrafficShip.gd:29` (`BalanceCombat.GROUP_IMPACT_BODY`)
- **Producer layer:** world
- **Also added by:** `src/world/HostileNpc.gd`, `src/world/CelestialSky.gd`, `src/world/SystemWorld.gd`
- **Permitted consumers:** (none - write-only)

**Write-only.** Every world-layer collidable body is tagged into this group
(ships, celestial bodies, projectile-relevant colliders) but nothing calls
`get_first_node_in_group` or `get_nodes_in_group` for it anywhere - only
`is_in_group(GROUP_IMPACT_BODY)` membership checks against an already-held
collider reference (`PlayerProjectile.gd:89` and similar), which is out of
this gate's scope by design. Catalogued here (not skipped) because
`add_to_group` for it is real and the gate would otherwise flag every one of
its five call sites as an undeclared group on the very first clean run.

### `money_log` -> `src/systems/telemetry/MoneyLog.gd`

- **Added by:** `src/systems/telemetry/MoneyLog.gd:26` (raw string)
- **Producer layer:** systems
- **Permitted consumers:** (none - write-only)

**Write-only**, same situation as `impact_body`. `MoneyLog` is held directly
by `src/Main.gd` (`_money_log`) rather than located through its own group;
nothing in the tree looks this group up today. Not part of the original 17
groups this gate's design was scoped against - found during implementation.
See "what the census got wrong," `docs/groups.md`'s own commit message, or
just: it exists, it self-registers into a group nobody reads, and leaving
it out of this catalog would fail the gate on the very first run.

---

## Dynamic call sites

Both are the same shape - a private, same-file helper that forwards its own
`group: StringName` parameter straight into the real Godot call:

```gdscript
static func _node_in_group(tree: SceneTree, group: StringName) -> Node:
    return tree.get_first_node_in_group(group)
```

`scripts/check_groups.py` does not trace call sites back through a local
wrapper to recover what literal a caller supplied - it reports the wrapper's
own call as what it structurally is (a parameter, not a literal) and
requires it to be listed here.

### `src/systems/save/CareerSave.gd:533`

`_node_in_group(tree, group)`. Called throughout `CareerSave.gd`'s save/load
section functions with literal or `BalanceX.GROUP_Y` group names - directly,
and through a second layer of the same shape (`_merge_service_section`,
`_apply_or_reset_service`, both of which just forward their own `group`
parameter into `_node_in_group`). Groups reached this way: `wallet_service`,
`fuel_service`, `hull_condition_service`, `cargo_service`, `ship_service`,
`operation_service`, `campaign_service`, `mission_service`, `docking_service`,
`recovery_service`.

### `src/ui/station/StationMenu.gd:957`

`_node_in_group(group)`. Called directly with literal group names, and once
more through `_group_bool(group, method)` (same forwarding shape). Groups
reached this way: `cargo_service`, `wallet_service`, `ship_service`,
`mission_service`, `recovery_service`.

---

## Known inconsistencies

**`src/entities/DockingService.gd:184`** looks up `&"system_world"` as a raw
string literal instead of `BalanceSession.GROUP_SYSTEM_WORLD` - the constant
that holds that exact value. Functionally identical today (same resolved
string, so this gate does not and should not flag it as a violation), but
it is the one `system_world` lookup that would silently stop matching if the
constant's value ever changed. Worth fixing when someone is next in this
file; not worth a special-cased gate rule for one line.
