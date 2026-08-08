# Global names

Every name that is reachable from anywhere in the game just by typing it, what
it points at, and why it earned the slot.

**This document is checked against the configuration.**
`scripts/check_globals.py` compares the `[autoload]` section of `project.godot`
against the Catalog below, and separately compares every `static func` /
`static var`-bearing `class_name` under `src/` against the Static namespaces
catalog further down - and fails the build if either pair disagrees in either
direction.

Autoloads under `addons/` are ignored (editor tools, not architecture). So is
the static-namespace scan, plus `tests/` (test fixtures, not architecture).

---

## The four tests

A thing may occupy a global name slot only if **all four** hold:

1. **Genuinely everything needs it** — not merely several things.
2. **It holds no game state owned by a particular system.**
3. **Having two of them would be nonsense.**
4. **It is declared here with a one-line justification, and a check fails the
   build when the real set and this list disagree.**

## Adding a global

1. Argue it against all four tests.
2. Register the autoload in `project.godot`.
3. Add an entry below with the justification against the four tests.
4. Run `python scripts/check_globals.py`.

**Entry format (load-bearing):**

```
### `SomeGlobal` -> `res://src/systems/SomeGlobal.gd`
```

---

# Catalog

### `EventBus` -> `res://src/systems/EventBus.gd`

Cross-system signal bus. The sanctioned channel for cross-domain communication.
Everything that crosses a boundary needs it; two buses would split the game into
two conversations; it holds no game state of its own.

### `ContentLibrary` -> `res://src/systems/ContentLibrary.gd`

Content scan and lookup for every `.tres` under `src/data/content/`. Every
system that resolves an id needs one library; two would disagree about what
exists; it holds content references, not career state.

### `TimeScale` -> `res://src/systems/time/TimeScale.gd`

How fast game time runs. Every clock must ask the same number; two authorities
would run two games; it holds only the rate and combat lock, not world state.

### `ServiceRegistry` -> `res://src/systems/ServiceRegistry.gd`

Career-reset registration for services that own session state. New services
self-register a reset callable so Main is not the only place that knows their
names; two registries would split reset; it holds only callables, not game data.

### `WorldClock` -> `res://src/systems/time/WorldClock.gd`

Accumulated game time and sim tick categories. Every sim system must share one
elapsed timeline; two clocks would desync markets and upkeep; it holds elapsed
seconds and category subscribers (not world layout or standing).

### `StandingService` -> `res://src/systems/standing/StandingService.gd`

Player standing ledger for Entities and People. Everyone that needs standing
queries this service; two writers would split truth; it holds only the standing
maps (and console registration), not world layout or combat state.

### `MarketService` -> `res://src/systems/market/MarketService.gd`

Station stock and prices for the whole sector. Trade, cargo, jobs, the news
ticker and the sector map all price against this one service; two writers would
split truth about what a good costs and open a same-station money pump; it holds
only market state (stocks, step count, shocks), not the hold, the wallet or
world layout.

### `BoardService` -> `res://src/systems/board/BoardService.gd`

Station job boards and radiant offer generation for the whole sector. Station
menus and mission accept all list work against this one service; two writers
would split which jobs exist this restock cycle; it holds only board step count
and mid-cycle claimed offer ids (offers re-derive from market + clock).

### `IncidentService` -> `res://src/systems/incident/IncidentService.gd`

Opportunistic space incidents (distress, intercept, customs light) for the
sector. Flight prompts and promote-to-mission all go through this one service;
two writers would split which events exist this security step; it holds only
security step count, offered incident prompts, and news echoes (not missions —
those stay on MissionService after promote). Reads heat pressure/hunt from
`EnforcementService` for intercept frequency and patrol-response spawns (S4).

### `EnforcementService` -> `res://src/systems/enforcement/EnforcementService.gd`

Per-Entity heat for patrol pressure (S4). Not standing and never writes
standing. Heat accrues on attributed crime in patrolled/contested space, customs
flee, and contraband seizure; decays on security steps. IncidentService asks it
for pressure/hunt in patrolled systems only.

### `SettingsService` -> `res://src/systems/settings/SettingsService.gd`

Player options (FOV, sensitivity, volumes, fullscreen, key rebinds) for the
whole app (S10). Menus, camera, flight turn rate and audio all read one writer;
two would desync binds and display; it holds only preferences in `user://`, not
career save state.

### `AudioService` -> `res://src/systems/audio/AudioService.gd`

Thin SFX/UI audio floor (S10). Weapon, dock and menu clicks share one player set
and bus routing; two would double-fire or fight volume; it holds no career state.

### `SteamService` -> `res://src/systems/steam/SteamService.gd`

Steam packaging hook (S10). Presence and achievement call sites stay stable
without requiring the SDK yet; two stubs would diverge; it holds only ephemeral
presence/debug marks, not career state.

---

# Static namespaces

*(Audit finding #80, decided 2026-08-06.)* An autoload is not the only way a
name becomes reachable from anywhere by typing it. A `class_name` script that
declares a top-level `static func` or `static var` is callable and mutable
from anywhere in the game by bare name - `CareerSave.reset()` needs no
autoload, no instance and no `res://` path, so it reaches exactly the way an
autoload does. It occupies the same kind of name slot the four tests above
are about, and `scripts/check_globals.py` checks it the same way: a build
fails when the real set of static namespaces under `src/` and the catalog
below disagree, in either direction.

**A `class_name` with no static member is not a global.** Most of `src/`'s
`class_name` scripts exist only so another file can hold a typed reference -
`var ship: PlayerShip` - and a plain type name carries no ambient authority
on its own: nothing reaches through it without also holding an instance.
Requiring a declaration for every typed reference in the codebase (there are
dozens of them) would make this gate noisy enough that switching it off
starts to look reasonable, which is exactly the failure
`check_magic_numbers.py`'s own header warns against: "A checker noisy enough
to be switched off is worse than no checker." A plain type name is
deliberately out of scope, on purpose, not by oversight.

**A top-level `const` on a `class_name` is also out of scope**, even on a
script that is a static namespace by the rule above. `Balance.SOME_LIMIT` is
reached by bare name the same way `CareerSave.reset()` is, but a constant
cannot be reassigned - it reads as data, not as authority, the same
reasoning the `Balance*.gd` files already lean on for holding tuning numbers
instead of behaviour. Only `static var` (mutable global state) and
`static func` (a callable with no instance gating it) put a script in this
catalog. `static var` is the one that matters most, because it is the
mutable half - a `class_name` quietly holding session state that nothing
resets is exactly the kind of drift the four tests exist to stop.

## Adding a static namespace

1. Confirm it is real: the script declares a top-level `static func` or
   `static var`, not only a `class_name` and/or a `const`.
2. Add an entry below with a short justification - what needs to reach it by
   bare name, and whether it holds any mutable static state.
3. Run `python scripts/check_globals.py`.

**Entry format (load-bearing) - note the `=>`, not the autoload catalog's
`->` above, so the two catalogs cannot be confused by a heading that happens
to resemble both:**

```
### `SomeNamespace` => `res://src/systems/SomeNamespace.gd`
```

---

## Catalog

*Generated from the real tree by walking every `.gd` file under `src/`
(excluding `addons/` and `tests/`, same reasoning as the autoload catalog's
`addons/` exclusion above) and keeping the ones that declare a top-level
`static func` or `static var`. 60 static namespaces as of 2026-08-06. Two
carry actual mutable state (`static var`) - `CareerPathState` and
`CareerStart` - the other 58 are pure static-function namespaces with no
state of their own. The per-entry counts below are the same generated fact,
not a design justification for each one; the four tests still apply and are
still a human argument, same as the autoload catalog.*

### `AttributionService` => `res://src/systems/attribution/AttributionService.gd`

4 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `BalanceBoard` => `res://src/data/balance/BalanceBoard.gd`

2 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `BalanceCampaign` => `res://src/data/balance/BalanceCampaign.gd`

3 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `BalanceCombat` => `res://src/data/balance/BalanceCombat.gd`

23 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `BalanceEconomy` => `res://src/data/balance/BalanceEconomy.gd`

10 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `BalanceEnforcement` => `res://src/data/balance/BalanceEnforcement.gd`

6 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `BalanceFlight` => `res://src/data/balance/BalanceFlight.gd`

17 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `BalanceHolding` => `res://src/data/balance/BalanceHolding.gd`

5 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `BalanceIncident` => `res://src/data/balance/BalanceIncident.gd`

3 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `BalanceMarket` => `res://src/data/balance/BalanceMarket.gd`

6 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `BalanceOps` => `res://src/data/balance/BalanceOps.gd`

4 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `BalanceOutfit` => `res://src/data/balance/BalanceOutfit.gd`

3 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `BalancePresentation` => `res://src/data/balance/BalancePresentation.gd`

6 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `BalanceStanding` => `res://src/data/balance/BalanceStanding.gd`

5 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `CareerPathState` => `res://src/data/CareerPathState.gd`

8 static func(s), 4 static var(s). Mutable static state reachable from
anywhere by bare name - the shape point 4 exists to catch. Session memory
for chosen life-path ids (origin, trade, mark, opening_complete).

### `CareerSave` => `res://src/systems/save/CareerSave.gd`

36 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `CareerStart` => `res://src/data/CareerStart.gd`

10 static func(s), 4 static var(s). Mutable static state reachable from
anywhere by bare name - the shape point 4 exists to catch. The four static
vars are compatibility accessors that delegate straight through to
`CareerPathState`, not a second copy of the state.

### `CargoService` => `res://src/systems/cargo/CargoService.gd`

1 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `CargoTrade` => `res://src/systems/cargo/CargoTrade.gd`

11 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `CelestialSky` => `res://src/world/CelestialSky.gd`

13 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `CombatReticle` => `res://src/ui/hud/CombatReticle.gd`

1 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `ConsoleService` => `res://src/systems/console/ConsoleService.gd`

2 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own. `is_enabled_for_build` (REPAIR-24) is the pure
release gate; `tokenise` parses typed lines.


### `DraywarUiTheme` => `res://src/ui/DraywarUiTheme.gd`

5 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `EntityLink` => `res://src/data/shapes/EntityLink.gd`

1 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `FlightHUD` => `res://src/ui/hud/FlightHUD.gd`

1 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `FlightInput` => `res://src/entities/FlightInput.gd`

4 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `FlightMath` => `res://src/entities/FlightMath.gd`

7 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `HostileNpc` => `res://src/world/HostileNpc.gd`

1 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `HostileProjectile` => `res://src/world/HostileProjectile.gd`

1 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `LifePathCreate` => `res://src/ui/session/LifePathCreate.gd`

2 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `MarketNews` => `res://src/systems/market/MarketNews.gd`

7 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `MarketPricing` => `res://src/systems/market/MarketPricing.gd`

9 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `MarketSeed` => `res://src/systems/market/MarketSeed.gd`

11 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `MarketShocks` => `res://src/systems/market/MarketShocks.gd`

11 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `MarketSim` => `res://src/systems/market/MarketSim.gd`

5 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `MissionOffer` => `res://src/systems/mission/MissionOffer.gd`

3 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `MissionService` => `res://src/systems/mission/MissionService.gd`

3 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `OpeningAnnexation` => `res://src/ui/session/OpeningAnnexation.gd`

1 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `PerfProbe` => `res://src/systems/perf/PerfProbe.gd`

2 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `Person` => `res://src/data/shapes/Person.gd`

1 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `RadiantJobGenerator` => `res://src/systems/board/RadiantJobGenerator.gd`

26 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `RecoveryService` => `res://src/systems/recovery/RecoveryService.gd`

3 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `SaveResult` => `res://src/systems/save/SaveResult.gd`

1 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `SaveService` => `res://src/systems/save/SaveService.gd`

5 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `SectorGraph` => `res://src/data/SectorGraph.gd`

7 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `ShipOutfit` => `res://src/systems/ship/ShipOutfit.gd`

18 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `StarSystem` => `res://src/data/shapes/StarSystem.gd`

1 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `StationBoardUi` => `res://src/ui/station/StationBoardUi.gd`

8 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `StationCampaignUi` => `res://src/ui/station/StationCampaignUi.gd`

10 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `StationDockQueries` => `res://src/ui/station/StationDockQueries.gd`

11 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `StationHoldingUi` => `res://src/ui/station/StationHoldingUi.gd`

10 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `StationHullUi` => `res://src/ui/station/StationHullUi.gd`

7 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `StationLoanUi` => `res://src/ui/station/StationLoanUi.gd`

8 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `StationMenuChrome` => `res://src/ui/station/StationMenuChrome.gd`

3 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `StationNewsUi` => `res://src/ui/station/StationNewsUi.gd`

2 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `StationOpsUi` => `res://src/ui/station/StationOpsUi.gd`

20 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `StationOutfitUi` => `res://src/ui/station/StationOutfitUi.gd`

16 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `StationTradeUi` => `res://src/ui/station/StationTradeUi.gd`

7 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `SystemWorld` => `res://src/world/SystemWorld.gd`

3 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.

### `WalletService` => `res://src/systems/wallet/WalletService.gd`

2 static func(s), no static var. Callable by bare name; holds no mutable
static state of its own.
