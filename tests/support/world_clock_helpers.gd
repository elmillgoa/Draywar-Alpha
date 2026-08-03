class_name WorldClockHelpers
extends RefCounted

## Shared WorldClock test helpers — Steam S1.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S1 (test-support scaffolding)


## Reset elapsed time and leave TimeScale alone.
static func reset_clock() -> void:
	WorldClock.reset()


## Advance by whole game days (24h each via BalanceWorldClock.HOURS_PER_DAY).
static func advance_days(days: float) -> void:
	WorldClock.advance_hours(days * BalanceWorldClock.HOURS_PER_DAY)


## Advance by game hours (thin wrapper for call-site clarity).
static func advance_hours(hours: float) -> void:
	WorldClock.advance_hours(hours)


## Advance by game seconds (thin wrapper for call-site clarity).
static func advance_seconds(seconds: float) -> void:
	WorldClock.advance_seconds(seconds)


## Current elapsed seconds (wrapper so tests do not touch the autoload bare).
static func elapsed_seconds() -> float:
	return WorldClock.elapsed_seconds()


## Current elapsed hours.
static func elapsed_hours() -> float:
	return WorldClock.elapsed_hours()
