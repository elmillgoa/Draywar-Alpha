class_name BalanceWorldClock
extends RefCounted

## World clock and sim-time tunables — Steam S1.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S1
##
## Accumulated game time, tick category names, jump away-time, and the optional
## `world_clock` save section. Live rate still comes from TimeScale; this layer
## owns magnitudes and section keys only.

# --- Save (optional section, schema v1 — no envelope bump) -----------------

## Optional save section key for accumulated world time.
const SAVE_SECTION_KEY: StringName = &"world_clock"

## Elapsed game seconds (float) inside the world_clock section.
const SAVE_KEY_ELAPSED_SECONDS: StringName = &"elapsed_seconds"

# --- Units -----------------------------------------------------------------

## Seconds in one game hour (canonical conversion for advance_hours).
const SECONDS_PER_HOUR: float = 3600.0

## Hours in one game day (test helpers / multi-day advances).
const HOURS_PER_DAY: float = 24.0

# --- Away-time -------------------------------------------------------------

## Scaled game hours applied on a successful gate jump (compressed transit).
## 8h is a short haul feel: enough for later market ticks to move without
## wiping a free-fly session's upkeep math in one hop.
const JUMP_AWAY_HOURS: float = 8.0

# --- Tick categories (StringName keys for WorldClock subscribers) ----------

const CATEGORY_MARKET: StringName = &"market"
const CATEGORY_BOARD: StringName = &"board"
const CATEGORY_SECURITY: StringName = &"security"
const CATEGORY_WALLET_UPKEEP: StringName = &"wallet_upkeep"
## Ops fleet upkeep + abstract haul progress (S6).
const CATEGORY_OPS: StringName = &"ops"
