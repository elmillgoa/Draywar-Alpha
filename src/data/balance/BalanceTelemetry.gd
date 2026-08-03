class_name BalanceTelemetry
extends RefCounted

## Money-event telemetry log tunables — Steam S2.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S2
##
## Log location, CSV shape, rotation cap, flush threshold, and the reason /
## detail-key tags every money-emitting system uses to tag
## EventBus.on_money_event for MoneyLog (src/systems/telemetry/MoneyLog.gd).
## Reuses the existing BalanceEconomy reason tags (loan borrow/repay/garnish,
## contraband fine) rather than duplicating them; only the activity tags
## missing from BalanceEconomy are declared here.

# --- File location (user://) ------------------------------------------------

## Directory the telemetry log lives under. Created on first write.
const LOG_DIRECTORY: String = "user://telemetry"

## The live CSV file every session appends to.
const LOG_PATH: String = "user://telemetry/money_events.csv"

## Single rotation backup. Overwritten (not chained) each time the live file
## exceeds MAX_FILE_BYTES, so telemetry history never grows without bound.
const ROTATED_PATH: String = "user://telemetry/money_events.csv.1"

# --- CSV shape ---------------------------------------------------------------

## Column order: world-clock seconds, reason, signed credits, balance after,
## then the optional detail fields (empty string when a row carries none).
const CSV_HEADER: String = (
	"elapsed_seconds,reason,credits_delta,credits_after,"
	+ "commodity_id,units,unit_price,station_id,system_id"
)

## Column count a well-formed row parses into (matches CSV_HEADER).
const CSV_COLUMN_COUNT: int = 9

## Decimal places written for the elapsed-seconds column.
const ELAPSED_SECONDS_FORMAT: String = "%.3f"

# --- Rotation / flush ---------------------------------------------------------

## Live file rotates to ROTATED_PATH once it reaches this many bytes, so a
## long playtest cannot grow the log without bound.
const MAX_FILE_BYTES: int = 5242880

## Buffered rows are written to disk once this many are pending.
const FLUSH_ROW_THRESHOLD: int = 50

# --- Reason tags (StringName) -------------------------------------------------
# Loan borrow/repay/garnish and the contraband fine already live in
# BalanceEconomy (REASON_LOAN_BORROW / REASON_LOAN_REPAY / REASON_LOAN_GARNISH /
# REASON_CONTRABAND_FINE) — emit those directly rather than duplicating them
# here. Only the activity tags missing from BalanceEconomy are declared below.

const REASON_UPKEEP: StringName = &"upkeep"
const REASON_DOCK_FEE: StringName = &"dock_fee"
const REASON_REFUEL: StringName = &"refuel"
const REASON_REPAIR: StringName = &"repair"
const REASON_JOB_PAY: StringName = &"job_pay"
const REASON_TRADE_BUY: StringName = &"trade_buy"
const REASON_TRADE_SELL: StringName = &"trade_sell"
const REASON_DEBUG_CREDITS_SET: StringName = &"debug_credits_set"
## Station outfitting install (S5).
const REASON_OUTFIT_BUY: StringName = &"outfit_buy"
## Station outfitting uninstall refund (S5).
const REASON_OUTFIT_SELL: StringName = &"outfit_sell"

# --- Detail dictionary keys (StringName) --------------------------------------

const DETAIL_KEY_COMMODITY_ID: StringName = &"commodity_id"
const DETAIL_KEY_UNITS: StringName = &"units"
const DETAIL_KEY_UNIT_PRICE: StringName = &"unit_price"
const DETAIL_KEY_STATION_ID: StringName = &"station_id"
const DETAIL_KEY_SYSTEM_ID: StringName = &"system_id"
## Outfit install/remove item content id (S5).
const DETAIL_KEY_ITEM_ID: StringName = &"item_id"
