# Global names

Every name that is reachable from anywhere in the game just by typing it, what
it points at, and why it earned the slot.

**This document is checked against the configuration.**
`scripts/check_globals.py` compares the `[autoload]` section of `project.godot`
with the entries below and fails the build if they disagree in either direction.

Autoloads under `addons/` are ignored (editor tools, not architecture).

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
those stay on MissionService after promote).
