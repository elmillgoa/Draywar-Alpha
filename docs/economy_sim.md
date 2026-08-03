# Economy simulator — S2 design

**Implements:** `docs/STEAM_PHASE_PLAN.md` §5 + Phase S2.
**Status:** design of record for the market sim. Numbers live in
`src/data/balance/BalanceMarket.gd`; this file explains the shapes and the
invariants the tests defend.

---

## 1. What changed

Before S2 prices came from `BalanceEconomy.TRADE_SYSTEM_BUY_MUL` /
`TRADE_SYSTEM_SELL_MUL` — a static table keyed by **system id**. Every station
in a system quoted the same number forever, and nothing the player did moved it.

After S2 prices come from **stock at a station**. Two docks in one system quote
different numbers. Buying moves the price up as you buy. Production, consumption
and background freight move it back over world-clock time.

The static tables are **gone**, not demoted. Opening stock is seeded from each
station's own `stock_targets` / `produces` / `consumes` (§3), so the tables fed
nothing once pricing moved to stock, and `BalanceEconomy.buy_price_at` /
`sell_price_at` / `trade_buy_mul` / `trade_sell_mul` went with them. Keeping a
second answer to "what does this good cost" is exactly the split that opens a
same-station money pump (§11), so there is now precisely one.

---

## 2. Ownership

| Thing | Owner |
|---|---|
| Stocks, prices, shocks | `MarketService` (single writer) |
| Money | `WalletService` |
| Hold contents | `CargoService` |
| Elapsed time / tick pulses | `WorldClock` |

`MarketService` is an **autoload with no `class_name`**, like `WorldClock` and
`StandingService` — see §12 for why the missing `class_name` is load-bearing.
It is argued against the `docs/globals.md` four tests there and in that
catalog: everything that prices a good asks it, two of them would split truth
about what a good costs (and open a same-station money pump), and it holds only
market state — not the hold, the wallet or world layout. Career state is
handled the same way `StandingService` handles standing: `ServiceRegistry`
resets it, and it carries its own optional save section.

`CargoService` no longer computes prices. It asks `MarketService` for a quote
and commits the trade through it.

---

## 3. Station economic identity

`Station` (`src/data/shapes/Station.gd`) gains economic fields. All content is
data — no hardcoded station economics.

| Field | Type | Meaning |
|---|---|---|
| `economy_role` | `StringName` | Content tag: `industrial`, `agricultural`, `refinery`, `military`, `frontier`, `trade_hub`. Drives the reason line and the seed defaults. |
| `produces` | `Dictionary` | commodity id → units produced per game hour. |
| `consumes` | `Dictionary` | commodity id → units consumed per game hour. |
| `stock_targets` | `Dictionary` | commodity id → target stock (the price-neutral level). |
| `market_scale` | `float` | Size multiplier on targets, capacity **and rates**. A hub absorbs a full hold; a spur does not. |

**`market_scale` scales production and consumption too**, not just targets. A
station's `produces` and `consumes` values are per game hour *at scale 1.0*; the
sim multiplies them by `market_scale` exactly as it does the targets. Otherwise
a tiny frontier spur would eat as much grain as a core hub.

**Black-market stock is deliberately not in S2.** §5.2 of the plan lists it in
the core model, but the Phase S2 bullet list does not, and making a controller's
restricted goods tradable under the counter is a *law* change — it would need
rules for who notices, what standing does, and how enforcement reacts. Inventing
those is out of bounds. S2 keeps the existing E3.3 behaviour exactly: a good its
controller restricts cannot be traded at that controller's docks at all. Left
for a phase that owns the law.

`position_offset` is now **required to be distinct per station**. Every station
carries a real in-system position; the world builder places all docks from that
field, including the first one in a system. No dock sits on the system anchor by
default.

### Derived per commodity

```
target   = stock_targets[c] * market_scale
capacity = target * CAPACITY_TO_TARGET
```

A commodity with no row at a station is **not traded there** — the station has
no market in it. Every commodity must still be traded somewhere (see §8).

---

## 4. Price model

One multiplier per (station, commodity), derived from stock against target.

```
t   = s^K / (s^K + target^K)        # s = stock, K = PRICE_ELASTICITY
mul = MUL_MAX - (MUL_MAX - MUL_MIN) * t
```

Properties that make this safe:

- `s = 0` → `t = 0` → `mul = MUL_MAX`. No division by zero anywhere.
- `s = target` → `t = 0.5` → `mul = 1.0` (constants are chosen symmetric).
- `s → ∞` → `t → 1` → `mul → MUL_MIN`. Bounded at both ends, so a price can
  never reach zero and can never explode.
- Strictly decreasing in stock. More stock is always cheaper.
- No randomness, no history — a price is a pure function of stock. Deterministic
  by construction.

Unit prices reuse the existing content fields:

```
unit_buy(s)  = commodity.base_buy_price  * mul(s) * station_mults
unit_sell(s) = commodity.base_sell_price * mul(s) * station_mults
```

The **displayed** single-unit prices are the prices the next unit actually
transacts at: buy at the current stock level, sell at `stock + 1` — the rung the
first sold unit lands on. Quoting the sell price at the current level would put
the number on the row one step away from what the quote pays.

`base_sell_price < base_buy_price` in all content, so `unit_sell(s) <
unit_buy(s)` at **every** stock level. That is the structural reason a
same-station round trip can never profit (§7).

---

## 5. Quantity pricing (the marginal ladder)

A trade of `q` units is **not** `q × price(current stock)`. It walks the stock
one unit at a time and prices each unit at the stock level it moves through.

**Buying `q`** from stock `s`: the player pays
`unit_buy(s) + unit_buy(s-1) + … + unit_buy(s-q+1)` — each unit priced at the
stock *before* it is removed. Prices climb as the shelf empties.

**Selling `q`** into stock `s`: the player receives
`unit_sell(s+1) + unit_sell(s+2) + … + unit_sell(s+q)` — each unit priced at the
stock *after* it lands. Prices fall as the shelf fills.

The two ladders walk the **same set of stock levels** in opposite directions.
That is what makes the round-trip loss a theorem rather than a tuning accident.

Totals are integers: buy total rounds **up**, sell total rounds **down**.

---

## 6. Player weight caps

One captain must not be able to permanently zero a hub.

- **Per-trade unit cap:** `min(MAX_UNITS_PER_TRADE, floor(stock × MAX_STOCK_FRACTION))`.
  The player cannot clear a shelf in one click. One unit is always allowed when
  stock ≥ 1 **and** taking it would still leave the station above its stock
  floor — otherwise a thin shelf shows a buy button that can never work, which
  reads as a bug rather than as scarcity.
- **Stock floor:** a buy may not take stock below `STOCK_FLOOR_FRACTION × target`
  for staples at a station that consumes them — the locals eat first.
- **Sell absorption:** selling into a station at or above capacity pays the
  floor price. Dumping 200 units of scrap on a scrapyard is not a payday.
- **Soft cap:** the marginal ladder already makes each additional unit worse.
  The hard caps only stop the pathological case.

Recovery is production + freight (§7), not a timer.

---

## 7. The tick

Markets advance in **fixed steps** (`STEP_SECONDS`, a quarter game-hour), never
in raw frame deltas. Step count is derived from the clock:

```
target_steps = floor(WorldClock.elapsed_seconds() / STEP_SECONDS)
while steps_done < target_steps: step(); steps_done += 1
```

This is why away-time equals live time: a jump that advances 8 game hours runs
exactly the same 32 steps that 8 hours of live flying would have run, in the
same order, with the same arithmetic. There is no separate "catch-up" code path
to get wrong.

Each step, for every station and commodity, computed from a **snapshot** so
iteration order cannot change the result:

1. **Production** — `produces[c] × market_scale × step_hours × taper`, where

   ```
   taper = clamp((1 - stock/capacity) / PRODUCTION_TAPER_BAND, 0, 1)
   ```

   A plant runs **flat out** until its silos are genuinely nearly full, then
   ramps to zero at capacity. The naive `(1 - stock/capacity)` taper looks
   equivalent and is not: a producer parked at its freight keep line sits at
   43% of capacity, so that version silently throttled every producer in the
   sector to 57% of its stated output. Nameplate production of 1.35× sector
   consumption became 0.77× actual — a structural famine that starved 25 of 64
   markets to exactly zero over 10,000 steps, with no formula anywhere looking
   wrong. The taper band is why a station's `produces` number means what it says.
2. **Consumption** — `consumes[c] × market_scale × step_hours`, limited by what
   is actually there. A station cannot eat stock it does not have.
3. **NPC freight** — background haulers move goods from stations holding a
   **surplus** (stock above target) to linked stations holding a **deficit**
   (stock below target):

   ```
   surplus = stock_at_source      - target_at_source      * FLOW_SOURCE_KEEP_FRACTION
   deficit = target_at_destination * FLOW_TARGET_FILL_FRACTION - stock_at_destination
   move    = rate * min(max(surplus, 0), max(deficit, 0))
   move    = min(move, FLOW_MAX_UNITS_PER_STEP)

   rate    = FLOW_RATE_INTRA_SYSTEM                             (same system)
           = FLOW_RATE_INTER_SYSTEM * FLOW_HOP_DECAY^(hops - 1)  (1..FLOW_MAX_HOPS gates)
           = 0                                                   (further than that)
   ```

   **Freight relays across the gate graph, weakening with distance.** A single
   hop is not enough: grain is made only in Delta and medical only in Alpha, so
   with one-hop freight the three outer systems received nothing, ever, and
   their markets flatlined. Intermediate stations do not relay on their own —
   a station stops importing at 45% of target and only exports above 130%, so
   it is never simultaneously a sink and a source. Distance-decayed direct
   links fix that without a routing simulation, and the decay *is* the fiction:
   the far spur is barely served, which is precisely why it pays the most.

   **Background freight is deliberately insufficient.** It tops a station up to
   `FLOW_TARGET_FILL_FRACTION` (0.45) of what that station actually wants — not
   to the target. Haulers keep a market alive; they never satisfy it. Measured
   over 6,000 unattended steps a consumer station settles at ~43% of target and
   stays there, which is a standing premium the player can go and collect. An
   earlier version filled to 100% of target and every route in the sector went
   to zero margin within a game month — the sim was stable, and pointless.

   Intra-system links move faster than gate links. When several destinations
   pull on one source, all outflows are scaled down proportionally so a source
   can never ship more surplus than it has.

   This is deliberately **not** diffusion toward equal stock levels. Diffusion
   would drag a consumer station up to the same relative stock as its supplier,
   flattening the price difference between them and killing the route — the
   exact opposite of the pillar. Freight aimed at *targets* leaves exporters
   sitting above their target (cheap) and importers below theirs (dear), which
   is a price gap that persists because it comes from what the stations *are*,
   not from a transient imbalance. It is also why two docks in one system keep
   different prices for the same good.

4. **Clamp** stock to `[0, capacity × SELL_OVERFILL_LIMIT]`. The upper bound is
   only a safety net for player dumps: production tapering already stops a
   station overfilling itself, so nothing can run away.

Production tapering against consumption gives every (station, commodity) a
**stable fixed point**. That is the mathematical reason 10,000 unattended steps
stay in band instead of drifting to zero or to the ceiling.

### Shocks

A shock is a named temporary multiplier on a (station, commodity) with an expiry
in world-clock seconds: `player_dump`, `shortage`, `war_demand`. They feed the
reason line and the news ticker. Player mass-dumps raise a `glut` shock so the
sector remembers what the player did for a while. Shocks are bounded and expire;
they never stack without limit.

**A shock is capped against the commodity's own buy/sell spread, not only
against a flat maximum** (`BalanceMarket.shock_magnitude_ceiling`). This is
load-bearing, and a flat cap alone is wrong. A trade is priced from the quote
taken *before* it records its own shock, so the second half of a round trip is
charged under a modifier the first half never paid: dump a load, raise a glut,
and the buy-back is charged at `1 - magnitude`. That comes out ahead the moment
the magnitude exceeds `1 - base_sell / base_buy`. Shipped content at a flat 0.35
put seven of ten commodities over that line — Beta Hub fuel cells returned +89
credits a cycle with the shelf back at its opening stock, repeatable for ever.
Capping every shock at `SHOCK_SPREAD_SAFETY_FRACTION` of the spread makes the
round trip lose by `(1 - that fraction) x (base_buy - base_sell)` per unit for
**any** content whose sell price is below its buy price, which
`Commodity.validation_errors` already requires. The cap applies to the step a
trade moves the shock by as well as to the stored result: capping only the
result leaves an asymmetric residue that pumps on every cycle after the first.

---

## 8. Readability contract

The captain answers three questions at the dock without a wiki:

- **What's expensive here?** — trade rows are sorted and show stock.
- **Why?** — a reason line per row, from real state: `Shortage — 12 in stock,
  needs 90`, `Production hub — yard output`, `Glut — recent dump`, `War demand`.
- **Where might this sell?** — the news ticker names shortages elsewhere.

Trade UI carries a **quantity control** with max-affordable / max-fit buttons,
live total, and the stock number. One-unit-per-click is gone.

**No dead commodities:** at boot, and after 10,000 unattended steps, every
commodity in the library has at least one profitable buy-here/sell-there pair in
the live sector — measured on the **displayed integer prices**, because a row
quoting "buy 6" here and "sell 6" there is a dead route however healthy the
underlying floats are. This is a seeded-content guarantee and a test, not a hope.

### The rounding cliff on cheap bulk goods

The settled sector prices every producer at roughly `MUL 0.61–0.69` and every
consumer at roughly `1.35`, because the taper band and the
`SECTOR_PRODUCTION_*_RATIO` bounds pin a producer near 2.1–2.6× its target and
`FLOW_TARGET_FILL_FRACTION` pins a consumer near 0.44× its. So the raw per-unit
margin is about `base_buy × (1.35 / R − 0.65)` where `R = base_buy/base_sell`.

Buy totals round **up** and sell totals round **down** (§5, and that asymmetry is
load-bearing — it is why a same-station round trip cannot break even). On a
40-credit alloy that costs under 5% of the margin. On 8-credit scrap it costs
most of it: a raw spread of 1.58 credits became `ceil(5.16) = 6` against
`floor(6.73) = 6`, a visibly dead commodity.

The fix is a content one, and the lever is **which** producer is over-supplied.
A producer's settled stock is `capacity × (1 − PRODUCTION_TAPER_BAND × outflow /
production)`, and its outflow is set by how close it is to the consumers. So the
cheapest dock for a good is the one whose output most exceeds what freight pulls
out of it. Gamma Rim is now the sector's scrap pile (its flavour line already
said so): it settles at 2.62× target, quotes 5, and Alpha pays 6 two gates away.
Grain and rations sit on the same cliff at +1 and +2 a unit — thin on purpose,
bulk goods should be — but a future rate change near them is the change most
likely to flip one back to zero, so re-read the printed route table after any
`produces`/`consumes` edit.

**At boot the same cliff exists, it is decided by different numbers, and it was
live.** A fresh career has simulated nothing yet, so the widest price gap in the
sector is whatever the seed factors set: `SEED_PRODUCER_FACTOR × target` against
`SEED_CONSUMER_FACTOR × target`, and nothing else. At the original 1.8 / 0.45
those quote at `MUL 0.7370` and `1.3385`, so grain came out `ceil(10 × 0.7370) =
8` against `floor(6 × 1.3385) = 8`, and scrap `6` against `6`. Two dead
commodities on turn one while the *settled* sector was perfectly healthy — which
is exactly why boot needs its own test and cannot be inferred from the 10,000-
step one. The seeds are now **2.0 / 0.35** (`MUL 0.6977` and `1.4114`) and every
commodity clears by at least a credit, grain and scrap at +1.

The seed factors are the safe lever for this, and `MUL_MIN`/`MUL_MAX` or the
cheap goods' base prices are not. Seeds only set where the sim *starts*; where it
*ends* is set by production, consumption and freight, so 10,000 unattended steps
land on the identical settled sector at either setting — same 0 markets below
band, same thinnest 0.153× target, same fullest 0.872× capacity. Widening the
multiplier span or editing base prices would move the equilibrium, the
round-trip-loss margin and the `SECTOR_PRODUCTION_*_RATIO` bounds all at once.

---

## 9. Save

Optional section `market` (schema v1, no envelope bump).

| Key | Type | Meaning |
|---|---|---|
| `steps_done` | `int` | Market steps applied since career start. Couples the market to the world clock — a load resumes mid-timeline instead of restarting it. |
| `stocks` | `Dictionary` | station id → { commodity id → float stock }. |
| `shocks` | `Array` | Active shocks: station, commodity, kind, magnitude, expiry seconds. |

Missing section → markets seeded from station profiles at their targets, steps
zero. Unknown station/commodity ids are dropped on load, not repaired.

Byte-determinism holds because stocks are plain floats written in canonical
form and every code path that produces them is deterministic.

---

## 10. Telemetry

Every credit movement appends one row to `user://telemetry/money_events.csv`:

```
elapsed_seconds,event,commodity,qty,unit_price,total,credits_after,station,system
```

This is balance fuel for S9 — where money actually comes from and goes, measured
instead of guessed. Local file only; nothing leaves the machine.

---

## 11. Invariants the tests defend

| Invariant | Why it matters |
|---|---|
| Same good scarce here, abundant there, **because of stock** | The pillar |
| Buying out a shelf raises the price and limits the next buy | Market fights back |
| 10,000 unattended steps: every traded market stays at or above `BAND_MIN_LIVE_FRACTION × target` and never exceeds capacity; no NaN, no infinity | Long-run stability |
| Away-time is **identical** to live time, float for float — asserted as exact equality, not a tolerance | Jump compression is honest |
| Same seed + same actions → byte-identical `market` section | Determinism |
| A same-station round trip always loses credits — **either order**, at any stock level, with or without a shock, and across a step boundary | No money pump |
| Every commodity has a profitable route at boot | No dead cargo |
| Full sector step under the named millisecond budget | Performance, measured |
| Contraband still refuses on the open market at controlling docks | E3.3 law intact |

---

## 12. Service contract

`MarketService` is an **autoload with no `class_name`** (same shape as
`StandingService` / `WorldClock`). That is deliberate: a bare autoload name is
the sanctioned way for one system to *ask* another something and get a return
value, and `scripts/check_boundaries.py` would flag a `class_name` reference
across systems. Helper classes under `src/systems/market/` do carry
`class_name` — they are the same system talking to itself, which is allowed.

```gdscript
# --- Reads ---
func stock(station_id: StringName, commodity_id: StringName) -> int
func stock_exact(station_id: StringName, commodity_id: StringName) -> float
func target_stock(station_id: StringName, commodity_id: StringName) -> float
func capacity_stock(station_id: StringName, commodity_id: StringName) -> float
func trades(station_id: StringName, commodity_id: StringName) -> bool
func unit_buy_price(station_id: StringName, commodity_id: StringName) -> int
func unit_sell_price(station_id: StringName, commodity_id: StringName) -> int
func max_buy_units(station_id: StringName, commodity_id: StringName) -> int
func max_sell_units(station_id: StringName, commodity_id: StringName) -> int

# --- Quotes (never mutate) ---
# Returns { units: int, total: int, unit_avg: int, capped: bool, reason: StringName }
func quote_buy(station_id: StringName, commodity_id: StringName, units: int) -> Dictionary
func quote_sell(station_id: StringName, commodity_id: StringName, units: int) -> Dictionary

# --- Commits (the only stock writers) ---
func commit_buy(station_id: StringName, commodity_id: StringName, units: int) -> int
func commit_sell(station_id: StringName, commodity_id: StringName, units: int) -> int

# --- Readability ---
func price_reason(station_id: StringName, commodity_id: StringName) -> String
func news_line() -> String

# --- Lifecycle / sim ---
func reset() -> void          # re-seed from content, steps back to zero
func catch_up() -> void       # run pending steps against the world clock
func steps_done() -> int
func to_section() -> Dictionary
func apply_section(raw: Variant) -> void
```

`quote_*` is a pure function of current state — calling it twice returns the
same answer and changes nothing. `commit_*` is the only path that moves stock.
`CargoService` owns the transaction order: quote → check money and hold →
spend → commit → move cargo, with a refund if a later step fails.

### Bus signals added by S2

| Signal | When |
|---|---|
| `on_market_changed(station_id, commodity_id, stock, unit_buy_price)` | A player trade moved a market. Not emitted per sim step. |
| `on_market_ticked(steps_applied, elapsed_seconds)` | A catch-up batch finished. One emit per batch, never per step. |
| `on_market_news(line)` | A new headline is available for the ticker. |
| `on_money_event(reason, credits_delta, credits_after, detail)` | Any credit movement, for the telemetry log. |

