class_name Balance
extends RefCounted

## The balance layer's entry file — Alpha A0.
##
## Every tunable lives here or under `src/data/balance/`.
## `scripts/check_magic_numbers.py` fails the build on a numeric literal
## anywhere under `src/` outside this layer.

## Content ceilings — keyed by content directory. E5 lifts systems/stations/people
## past Alpha; see `docs/BETA_E5_CONTENT_SCALE.md` (E5.1). Destination §10 is the
## hard upper bound for those three.
##
## These are **ceilings, not targets**. Exceeding one is a stop condition, and
## `ContentLibrary` turns that into a loud failure at load. Categories listed
## with no directory yet cost nothing and document where the pipeline is going.
const CONTENT_BUDGET: Dictionary[StringName, int] = {
	## E5.1: Destination v1 ceiling (ship target 6 systems in E5.2+).
	&"star_systems": 8,
	## E5.1: Destination §10 (~10 docks).
	&"stations": 10,
	&"entities": 6,
	## E5.1: people ≤24 (small lift under Destination 20–35).
	&"people": 24,
	## E1.4 trade contrast: commodities toward 8–10 (E1 cap ≤10).
	&"commodities": 10,
	## E3.4 smuggle kind + denser boards; budget raised to 12 (E3 caps).
	&"contract_types": 12,
	&"hulls": 2,
	&"weapons": 12,
	&"equipment": 10,
	## E4.4: two personal recovery chains (Mendi/Reach + Jax/Drift). Ceiling, not target.
	&"recovery_chains": 2,
	## E4.1: 3 axes × 3 options (origin / trade / mark). Ceiling is the set size.
	&"life_path_options": 9,
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
