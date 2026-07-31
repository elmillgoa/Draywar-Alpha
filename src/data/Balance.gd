class_name Balance
extends RefCounted

## The balance layer's entry file — Alpha A0.
##
## Every tunable lives here or under `src/data/balance/`.
## `scripts/check_magic_numbers.py` fails the build on a numeric literal
## anywhere under `src/` outside this layer.

## Alpha content ceilings — `Alpha/ALPHA_SCOPE.md`, keyed by content directory.
##
## These are **ceilings, not targets**. Exceeding one is a stop condition, and
## `ContentLibrary` turns that into a loud failure at load. Categories listed
## with no directory yet cost nothing and document where the pipeline is going.
const CONTENT_BUDGET: Dictionary[StringName, int] = {
	&"star_systems": 4,
	## E1 cap: stations ≤7 (second docks in existing systems).
	&"stations": 7,
	&"entities": 6,
	## E1 cap: people ≤20 (density pack contacts).
	&"people": 20,
	&"commodities": 8,
	## E1.2 room for multi-job boards; E1.3 bounty kind needs headroom.
	&"contract_types": 8,
	&"hulls": 2,
	&"weapons": 12,
	&"equipment": 10,
	## Alpha A4: one personal recovery chain total (Alpha Scope).
	&"recovery_chains": 1,
}

## Time control — three speeds and nothing between them.
##
## `TIME_SCALE_NORMAL` is also the rate the combat lock forces and the rate a
## load returns to, so it is one constant rather than three copies of 1.0.
const TIME_SCALE_NORMAL: float = 1.0
const TIME_SCALE_FAST: float = 4.0
const TIME_SCALE_FASTEST: float = 16.0

## Every scale the time-scale service will accept, slowest first.
##
## The whole allow-list. `TimeScale.request_scale()` refuses anything not in it.
const TIME_SCALES: Array[float] = [TIME_SCALE_NORMAL, TIME_SCALE_FAST, TIME_SCALE_FASTEST]
