class_name BalanceMarket
extends RefCounted

## Economy simulator tunables — Steam S2.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S2, docs/economy_sim.md
##
## Every number MarketService reads: step cadence, the stock-to-price curve,
## seeding, player weight caps, NPC freight, the long-run stability band, save
## keys, the tick budget, and the economy role tags stations declare. Station
## content (`src/data/content/stations/*.tres`) is data; this file is the only
## place its magnitudes are allowed to live.

# --- Tick cadence ------------------------------------------------------------

## One market step in game seconds — a quarter game-hour. Steps are derived
## from WorldClock.elapsed_seconds(), never a raw frame delta, so away-time
## and live time run the identical arithmetic (docs/economy_sim.md §7).
const STEP_SECONDS: float = 900.0

## STEP_SECONDS expressed in hours (BalanceWorldClock.SECONDS_PER_HOUR = 3600.0).
## Production/consumption rates are per game hour; this scales them to one step.
const STEP_HOURS: float = 0.25

# --- Price curve ---------------------------------------------------------

## Curve steepness in `t = s^K / (s^K + target^K)`. Higher K snaps the price
## toward MUL_MIN/MUL_MAX faster as stock moves off target, so a half-empty
## shelf already reads as scarce instead of barely dented.
const PRICE_ELASTICITY: float = 1.6

## Price multiplier floor (stock far above target). Kept symmetric with
## MUL_MAX around 1.0 so a station sitting exactly on target quotes the
## commodity's unmodified base price. The 0.4/1.6 span (widened from an
## earlier 0.5/1.5) has to clear the widest base_buy/base_sell ratio in the
## commodity library — grain is 10/6 = 1.667, scrap is 8/5 = 1.60. At 0.5/1.5
## the realistic producer-to-consumer spread landed only ~11% over the grain
## ratio, which left the cheap bulk goods with no profitable route anywhere
## in the sector and failed the no-dead-commodities acceptance test. 0.4/1.6
## leaves real headroom at the equilibrium stock levels the sim actually
## settles at — measured, that is 25–30% on the cheap bulk goods and far more
## on the expensive ones. Do not narrow this span without re-measuring the
## whole route table: on a good as cheap as scrap or grain, whole-credit
## rounding of the displayed price eats about one credit of margin, so a
## narrower span silently turns those routes into "buy 6 here, sell 6 there"
## and the commodity is dead to a player however healthy the decimals are.
const MUL_MIN: float = 0.4

## Price multiplier ceiling (stock near zero). Paired with MUL_MIN — see that
## constant for why the span is 0.4/1.6 and not the narrower 0.5/1.5.
const MUL_MAX: float = 1.6

## No resolved unit price may quote below this many credits, at any stock
## level. Mirrors `BalanceEconomy.TRADE_PRICE_MIN` so a price can never reach
## zero even at MUL_MIN on the cheapest commodity.
const PRICE_FLOOR_CREDITS: int = 1

## capacity = target * this. Gives every market real headroom above its
## price-neutral level so production tapers in gradually instead of hitting a
## hard ceiling the moment stock clears target.
const CAPACITY_TO_TARGET: float = 3.0

## hard_max = capacity * this. The absolute ceiling stock is clamped to after
## every step and after every player sale. Production tapering already stops a
## station overfilling itself, so this only exists to catch a player dumping a
## full hold into a market that is already brimming (docs/economy_sim.md §7).
const SELL_OVERFILL_LIMIT: float = 2.0

## Fraction of capacity a plant's silos have to be inside before production
## starts ramping down: `taper = clamp((1 - stock/capacity) / this, 0, 1)`.
##
## **This constant is the difference between a `produces` number meaning what
## it says and silently meaning 57% of it.** The naive taper `(1 - stock/
## capacity)` looks equivalent and is not. A producer parked on its freight
## keep line (FLOW_SOURCE_KEEP_FRACTION = 1.3 x target, against a capacity of
## 3.0 x target) sits at 43% of capacity, so the naive form multiplied every
## producer's output by 0.567 forever. Nameplate production of 1.35x sector
## consumption became 0.77x actual: a structural famine that starved 25 of 64
## markets to exactly zero over 10,000 unattended steps, with no formula
## anywhere looking wrong. With the band a plant runs flat out until its silos
## are genuinely nearly full, then ramps to nothing at capacity — which still
## gives every (station, commodity) a stable fixed point, and keeps stock below
## capacity because production per step is far smaller than `this * capacity`.
const PRODUCTION_TAPER_BAND: float = 0.35

# --- Content categories -----------------------------------------------------

## ContentLibrary category directory the market seeds stations from.
## (Commodities come from `BalanceEconomy.COMMODITY_CONTENT_CATEGORY` — one
## name, one owner, so the two cannot drift apart.)
const STATION_CONTENT_CATEGORY: StringName = &"stations"

# --- Seeding ---------------------------------------------------------------

## Opening stock factor (× target) for a station that produces a commodity
## and does not consume it. Producers start comfortably stocked, above
## target, so the first prices a player sees already read as "made here"
## rather than starting artificially scarce.
##
## **2.0 is load-bearing, and the rounder-looking 1.8 it replaced was a bug.**
## Together with SEED_CONSUMER_FACTOR this sets the widest price gap the sector
## can show on turn one: 2.0 × target quotes at multiplier 0.6977, 0.35 × target
## at 1.4114. Whole-credit rounding then decides whether the two cheapest goods
## have any route at all, because a buy total rounds **up** and a sell total
## rounds **down** (docs/economy_sim.md §5), which costs about a credit of margin
## whatever the good is worth. At the old 1.8/0.45 pair (0.7370 / 1.3385) grain
## (10/6) was `ceil(10 × 0.7370)` = 8 against `floor(6 × 1.3385)` = 8, and scrap
## (8/5) was 6 against 6: both dead on a fresh career, and §5.6's "no dead
## commodities" unmet. At 2.0/0.35 grain and scrap each clear +1 credit a unit
## and nothing else loses margin. tests/test_s2_acceptance.gd asserts it and
## prints the whole boot route table on every run.
##
## Only the *starting* state moves. Where the sim settles is set by production,
## consumption and freight, not by initial conditions — measured over 10,000
## unattended steps the settled sector is identical at 1.8/0.45 and 2.0/0.35, so
## the stability band and the sector production ratios are untouched. That is why
## the seeds are the right lever here and MUL_MIN/MUL_MAX or the cheap goods'
## base prices are not: those move the equilibrium, the round-trip loss and the
## production ratios all at once. Bounds to keep if this is ever retuned: 2.0 is
## well under CAPACITY_TO_TARGET (3.0), so a producer does not seed inside its
## own production taper, and above FLOW_SOURCE_KEEP_FRACTION (1.3), so freight
## leaves the dock from step one.
const SEED_PRODUCER_FACTOR: float = 2.0

## Opening stock factor (× target) for a station that consumes a commodity
## and does not produce it. Consumers start drawn down, below target, so a
## fresh save already shows real demand instead of every dock reading full.
##
## **0.35 rather than the 0.45 it replaced, for the rounding reason written out
## in full on SEED_PRODUCER_FACTOR — read that note before moving either.** The
## two are a pair: they decide whether grain and scrap have a profitable route on
## turn one, and at 1.8/0.45 both topped out at a margin of exactly 0 credits a
## unit. 0.35 × target quotes at multiplier 1.4114 and still sits well clear of
## STOCK_FLOOR_FRACTION (0.05) and BAND_MIN_LIVE_FRACTION (0.08), so a consumer
## opens drawn down but with a real shelf, not an empty one.
const SEED_CONSUMER_FACTOR: float = 0.35

## Opening stock factor (× target) for every other case — no declared
## relationship to the commodity, or both produced and consumed. Seeds
## exactly at target: price-neutral until the sim moves it.
const SEED_NEUTRAL_FACTOR: float = 1.0

# --- Player weight caps ------------------------------------------------------

## Hard ceiling on units moved in one trade, regardless of stock. Stops a
## single click from being the whole story even at a hub with a huge shelf.
const MAX_UNITS_PER_TRADE: int = 250

## A trade may also never move more than this fraction of current stock in
## one go — `min(MAX_UNITS_PER_TRADE, floor(stock * this))`. Scales the cap
## down automatically at small or starved stations where 250 units would be
## the whole shelf and then some.
const MAX_STOCK_FRACTION_PER_TRADE: float = 0.35

## A buy may not take a station's stock below this fraction of target for a
## commodity that station consumes — the locals eat first
## (docs/economy_sim.md §6).
const STOCK_FLOOR_FRACTION: float = 0.05

## Slack allowed when a whole-unit cap is read off a float shelf, so binary
## representation error cannot cost the captain the last legal unit.
##
## **Not cosmetic — this is a whole unit of difference and it was live.** Stock
## is a double, and a seeded shelf of `target * SEED_CONSUMER_FACTOR` lands a
## hair off the whole number it means: `360 * 0.35` is 125.99999999999999, not
## 126. Buying that shelf down to its locals-eat-first floor then leaves
## `18.999999999999986 - 18.0` above the floor, a bare `floori` reads that as
## zero units left to release, and the dock refuses a unit it owes — one unit
## stranded for a reason no player could ever see, and one that moves with every
## seed or target retune. A tolerance this small can only absorb representation
## error; nothing in this game is measured in a billionth of a unit.
const UNIT_CAP_EPSILON: float = 1e-9

# --- NPC freight (background flow) -----------------------------------------
#
# Background haulers move goods from a station holding a SURPLUS to a linked
# station holding a DEFICIT. This is deliberately not diffusion toward equal
# stock: diffusion would drag an importer up to its supplier's relative level,
# flatten the price gap between them and kill the route. Aiming at each
# station's own target instead leaves exporters sitting above target (cheap)
# and importers below theirs (dear), which is the whole pillar
# (docs/economy_sim.md §7).

## A source only ships what it holds ABOVE this multiple of its own target —
## `surplus = stock - target * this`. Above 1.0 on purpose: a station keeps a
## working reserve for itself before a hauler is allowed to take any of it, so
## a producer never strips itself back down to price-neutral.
const FLOW_SOURCE_KEEP_FRACTION: float = 1.3

## A destination only pulls freight up to this fraction of its own target —
## `deficit = target * this - stock`. **Background freight is deliberately
## insufficient.** It tops a station up to 45% of what that station actually
## wants and then stops, so demand is never satisfied and there is always a
## standing premium for the player to go and collect. An earlier version filled
## to 100% of target and every route in the sector went to zero margin within a
## game month: the sim was stable, and pointless.
const FLOW_TARGET_FILL_FRACTION: float = 0.45

## Fraction of `min(surplus, deficit)` a hauler moves per step between two
## stations in the SAME system. The short local run, so the faster of the two.
const FLOW_RATE_INTRA_SYSTEM: float = 0.10

## Same fraction across ONE gate to another system. Lower, because a
## cross-system supply line is longer and slower than a local one. Further
## systems still get served, at this rate decayed per extra gate — see
## FLOW_HOP_DECAY and FLOW_MAX_HOPS.
const FLOW_RATE_INTER_SYSTEM: float = 0.06

## Furthest apart, in gates, two stations may be and still be linked by
## background freight. The sector's widest gate span is 4 (Alpha to Zeta, and
## Delta to Zeta), so this reaches everything.
##
## **Freight used to cross exactly one gate, and that starved half the sector.**
## Grain and rations are produced only in Delta, medical and luxuries only in
## Alpha; Gamma, Epsilon and Zeta are 2 to 4 gates from those and so received
## nothing, ever. Intermediate stations cannot relay on their own — a station
## stops importing at FLOW_TARGET_FILL_FRACTION of target and only exports above
## FLOW_SOURCE_KEEP_FRACTION, so it is never simultaneously a sink and a source.
## Distance-decayed direct links fix that without a routing simulation
## (docs/economy_sim.md §7).
const FLOW_MAX_HOPS: int = 4

## Freight rate multiplier per extra gate beyond the first:
## `rate = FLOW_RATE_INTER_SYSTEM * pow(this, hops - 1)`.
##
## **The decay is the fiction as well as the mechanism** — the far spur is
## barely served, which is precisely why it pays the most. It is not free to
## choose: measured over 10,000 unattended steps, 0.55 leaves three markets
## dead (Zeta luxuries and medical, Epsilon luxuries — all made only at Alpha
## Port, three to four gates away), 0.75 still leaves one, and 0.80 is the first
## value that clears the band but only reaches 0.094 x target against a 0.08
## floor. 0.85 settles the thinnest market at 0.153 x target — nearly double the
## headroom — and costs almost nothing in route margin: medical Alpha to Zeta
## goes from +21.96 to +21.12 credits a unit. Flattening it further would start
## paying for stability with the price gap the whole economy rests on.
const FLOW_HOP_DECAY: float = 0.85

## Hard per-step cap on units moved by one freight link, so a huge surplus
## meeting a huge deficit cannot resolve itself in a single step.
const FLOW_MAX_UNITS_PER_STEP: float = 4.0

# --- Player shocks (temporary modifiers) -----------------------------------
#
# One player trade big enough to matter leaves a mark the sector remembers for
# a while. The multiplier applies IDENTICALLY to the buy and the sell side —
# if it ever applied to one side only, a shock would open a same-station money
# pump (docs/economy_sim.md §7).

## A trade must move at least this fraction of a market's target to raise a
## shock at all. Below it the marginal ladder is the only consequence.
const SHOCK_TRIGGER_FRACTION: float = 0.10

## Shock magnitude per whole target moved: `|target fraction| * this`, before
## the clamp below. One full target's worth of trade earns most of the cap.
const SHOCK_MAGNITUDE_PER_TARGET: float = 0.80

## Hardest a shock may push price, up or down, before the per-commodity spread
## ceiling below is applied. Bounded so repeated dumping cannot stack a market
## into free goods or unaffordable ones.
const SHOCK_MAGNITUDE_MAX: float = 0.35

## Fraction of a commodity's own buy/sell spread a shock may consume
## (`shock_magnitude_ceiling`). Below 1.0 on purpose: at exactly 1.0 a full
## shock makes a same-station round trip break even, and this is the margin
## that keeps it a loss.
const SHOCK_SPREAD_SAFETY_FRACTION: float = 0.9

## Game hours a shock takes to decay linearly back to no effect at all.
const SHOCK_DURATION_HOURS: float = 12.0

## Shock kind: the player bought heavily and the shelf has not recovered —
## price up on both sides.
const SHOCK_KIND_STRIP: StringName = &"strip"

## Shock kind: the player dumped a hold here — price down on both sides.
const SHOCK_KIND_GLUT: StringName = &"glut"

# --- Long-run stability band (tests) ---------------------------------------

## A traded commodity's stock must never sit below this fraction of its
## target after long unattended running (10,000-step stability test). Names
## the floor of "in band" from docs/economy_sim.md §11 so the test asserts a
## tunable rather than a number invented in the test file.
const BAND_MIN_LIVE_FRACTION: float = 0.08

## Ceiling: stock must never sit above this fraction of **capacity** after long
## unattended running. Deliberately 1.0 — capacity itself, not a fraction of it.
##
## An earlier 0.95 read a correct market as a failure. A pure producer whose
## output nobody nearby will buy legitimately saturates: it fills to where
## production tapers to match what freight can carry away, and sits there
## quoting rock-bottom prices. That is a scrapyard drowning in scrap, which is
## good gameplay — it is where a captain goes to buy scrap cheap — not a bug.
## The real invariant is that nothing runs away past the level production
## tapers to zero at. Player dumps may briefly push stock above capacity toward
## hard_max, so the assertion is about the **unattended** steady state, measured
## after a settle with no player.
const BAND_MAX_LIVE_FRACTION: float = 1.0

## Slack allowed on the ceiling check, as a fraction of capacity, so accumulated
## floating-point drift over 10,000 steps cannot fail a market that is sitting
## exactly on its limit.
const BAND_CEILING_EPSILON: float = 0.0001

# --- Content headroom (sector-wide, seeded content tests) -------------------

## For every commodity, sector-wide production (Σ produces[c] × market_scale
## across producer stations) must be at least this many times sector-wide
## consumption (Σ consumes[c] × market_scale across consumer stations). Below
## this a consumer station starves toward zero over a long unattended run
## instead of settling at a stable fixed point.
const SECTOR_PRODUCTION_MIN_RATIO: float = 1.2

## Sector-wide production must also stay below this multiple of consumption.
## Above this the surplus is pure glut with no gameplay tension — nothing a
## player does can move a market that already drowns in its own output.
const SECTOR_PRODUCTION_MAX_RATIO: float = 1.6

# --- Quote contract (MarketService.quote_buy / quote_sell) -----------------

## Units the quote actually covers, after weight caps (may be below asked).
const QUOTE_KEY_UNITS: StringName = &"units"

## Whole credits for the whole quote — buy rounds up, sell rounds down.
const QUOTE_KEY_TOTAL: StringName = &"total"

## `total / units` rounded, for a per-unit line in the trade UI.
const QUOTE_KEY_UNIT_AVG: StringName = &"unit_avg"

## True when a weight cap cut the quote below what was asked for.
const QUOTE_KEY_CAPPED: StringName = &"capped"

## Machine-readable outcome tag; see the QUOTE_REASON_* constants.
const QUOTE_KEY_REASON: StringName = &"reason"

## Quote outcome: the full asked-for quantity is available at this price.
const QUOTE_REASON_OK: StringName = &"ok"

## Quote outcome: this station keeps no market in this commodity at all.
const QUOTE_REASON_NO_MARKET: StringName = &"no_market"

## Quote outcome: a weight cap trimmed the quantity but a trade is still on.
const QUOTE_REASON_CAPPED: StringName = &"capped"

## Quote outcome: the caps leave nothing to trade right now (empty shelf, or
## a station already stuffed to its overfill ceiling).
const QUOTE_REASON_NONE_AVAILABLE: StringName = &"none_available"

## Quote outcome: the caller asked for zero or fewer units.
const QUOTE_REASON_INVALID: StringName = &"invalid"

# --- Reason lines (docs/economy_sim.md §8) ----------------------------------

## Stock below this fraction of target reads as a shortage.
const REASON_SHORTAGE_FRACTION: float = 0.60

## Stock above this fraction of target reads as a glut.
const REASON_GLUT_FRACTION: float = 1.60

## Reason line when a player buying spree is still holding the price up.
const REASON_SHOCK_STRIP: String = "Bought out recently — price still up"

## Reason line when a player dump is still holding the price down.
const REASON_SHOCK_GLUT: String = "Dumped on recently — price still down"

## Shortage line. Arguments: stock, target.
const REASON_SHORTAGE_FORMAT: String = "Shortage — %d in stock, wants %d"

## Glut line. Arguments: stock, target.
const REASON_GLUT_FORMAT: String = "Glut — %d in stock, wants %d"

## Producer line. Arguments: stock, target.
const REASON_PRODUCED_FORMAT: String = "Made here — %d in stock, wants %d"

## Consumer line. Arguments: stock, target.
const REASON_CONSUMED_FORMAT: String = "Bought in here — %d in stock, wants %d"

## Everything else. Arguments: stock, target.
const REASON_NEUTRAL_FORMAT: String = "Steady — %d in stock, wants %d"

## Reason line for a commodity this station keeps no market in.
const REASON_NO_MARKET: String = "No market here"

# --- News ticker (docs/economy_sim.md §8) -----------------------------------

## A market must be at least this far off its target, as a fraction of target,
## before it is worth a headline at all.
const NEWS_DEVIATION_MIN_FRACTION: float = 0.35

## How many of the sharpest markets the headline rotates through. Bigger means
## a more varied ticker; smaller means it stays on the genuinely worst news.
const NEWS_ROTATION_POOL: int = 5

## Shortage headline. Arguments: commodity name, station name.
const NEWS_SHORTAGE_FORMAT: String = "%s running short at %s."

## Glut headline. Arguments: commodity name, station name.
const NEWS_GLUT_FORMAT: String = "%s piling up at %s."

## Headline when nothing in the sector is far enough off target to report.
const NEWS_QUIET: String = "Sector steady — nothing moving much."

# --- Save (optional section, schema v1 — no envelope bump) -----------------

## Optional save section key for market state.
const SAVE_SECTION_KEY: StringName = &"market"

## Market steps applied since career start — couples the market to WorldClock
## so a load resumes mid-timeline instead of restarting it.
const SAVE_KEY_STEPS: StringName = &"steps_done"

## station id → { commodity id → float stock }.
const SAVE_KEY_STOCKS: StringName = &"stocks"

## Active shocks: station, commodity, kind, magnitude, expiry seconds.
const SAVE_KEY_SHOCKS: StringName = &"shocks"

## Station content id inside one entry of the `shocks` array.
const SHOCK_KEY_STATION: StringName = &"station"

## Commodity content id inside one entry of the `shocks` array.
const SHOCK_KEY_COMMODITY: StringName = &"commodity"

## SHOCK_KIND_STRIP or SHOCK_KIND_GLUT inside one entry of `shocks`.
const SHOCK_KEY_KIND: StringName = &"kind"

## Signed peak multiplier offset inside one entry of `shocks`.
const SHOCK_KEY_MAGNITUDE: StringName = &"magnitude"

## World-clock second the shock decays to nothing, inside one entry of `shocks`.
const SHOCK_KEY_EXPIRY: StringName = &"expiry_seconds"

# --- Performance -------------------------------------------------------------

## A full sector market step must complete within this many milliseconds
## (docs/economy_sim.md §11 — "measured, not vibes").
const TICK_BUDGET_MS: float = 2.0

# --- Economy role tags -------------------------------------------------------

## Station content tag: buys and sells wide, thin local production — goods
## pass through rather than get made here.
const ROLE_TRADE_HUB: StringName = &"trade_hub"

## Station content tag: turns raw goods into manufactured ones (alloy, spares).
const ROLE_INDUSTRIAL: StringName = &"industrial"

## Station content tag: staple food production (grain, rations).
const ROLE_AGRICULTURAL: StringName = &"agricultural"

## Station content tag: extracts or processes raw materials (ore, fuel cells).
const ROLE_REFINERY: StringName = &"refinery"

## Station content tag: arms and defence goods (munitions, fuel for patrols).
const ROLE_MILITARY: StringName = &"military"

## Station content tag: thin, far-out post — low production, high demand.
const ROLE_FRONTIER: StringName = &"frontier"

## Every role a station's `economy_role` may declare. `Station.validation_errors`
## checks membership here so a typoed tag fails loudly instead of silently
## falling back to "no reason line".
const KNOWN_ROLES: Array[StringName] = [
	ROLE_TRADE_HUB,
	ROLE_INDUSTRIAL,
	ROLE_AGRICULTURAL,
	ROLE_REFINERY,
	ROLE_MILITARY,
	ROLE_FRONTIER,
]


## Stock capacity for a commodity given its already market_scale-weighted
## target. capacity = target * CAPACITY_TO_TARGET (docs/economy_sim.md §3).
static func capacity_for(target: float) -> float:
	return target * CAPACITY_TO_TARGET


## Absolute stock ceiling for a commodity given its market_scale-weighted
## target. hard_max = capacity * SELL_OVERFILL_LIMIT (docs/economy_sim.md §7).
static func hard_max_for(target: float) -> float:
	return capacity_for(target) * SELL_OVERFILL_LIMIT


## Background freight rate between two stations `hops` gates apart
## (docs/economy_sim.md §7). 0 hops is the same system — the fast local run.
## 1..FLOW_MAX_HOPS decays FLOW_RATE_INTER_SYSTEM once per extra gate. Anything
## further, or unreachable (a negative hop count), is not linked at all.
static func freight_rate_for_hops(hops: int) -> float:
	if hops < 0 or hops > FLOW_MAX_HOPS:
		return 0.0
	if hops == 0:
		return FLOW_RATE_INTRA_SYSTEM
	return FLOW_RATE_INTER_SYSTEM * pow(FLOW_HOP_DECAY, float(hops - 1))


## SHOCK_DURATION_HOURS in world-clock seconds.
static func shock_duration_seconds() -> float:
	return SHOCK_DURATION_HOURS * BalanceWorldClock.SECONDS_PER_HOUR


## Hardest a shock may push **this commodity's** price, up or down.
##
## **This is what stops a same-station money pump, and a flat cap cannot do it.**
## A trade is priced from the quote taken *before* it records its own shock, so
## the second half of a round trip is charged under a shock the first half did
## not pay. Selling a load raises a glut and the buy-back is then charged at
## `1 - magnitude` — profitable the moment `magnitude` exceeds the commodity's
## own buy/sell spread `1 - base_sell/base_buy`. Measured against shipped
## content at a flat 0.35: Beta Hub fuel cells returned +89 credits a cycle with
## the shelf back at its opening stock, repeatable for ever.
##
## Capping at a fraction of that spread makes the loss algebraic for any content
## whose sell price is below its buy price (which `Commodity.validation_errors`
## already requires): the round trip nets
## `(1 - SHOCK_SPREAD_SAFETY_FRACTION) * (base_buy - base_sell)` against the
## captain per unit, whatever the numbers are.
static func shock_magnitude_ceiling(base_buy: int, base_sell: int) -> float:
	if base_buy <= 0 or base_sell <= 0 or base_sell >= base_buy:
		return 0.0
	var spread: float = 1.0 - float(base_sell) / float(base_buy)
	return minf(SHOCK_MAGNITUDE_MAX, spread * SHOCK_SPREAD_SAFETY_FRACTION)


## Opening stock factor for a station's relationship to one commodity.
static func seed_factor_for(produces: bool, consumes: bool) -> float:
	if produces and not consumes:
		return SEED_PRODUCER_FACTOR
	if consumes and not produces:
		return SEED_CONSUMER_FACTOR
	return SEED_NEUTRAL_FACTOR
