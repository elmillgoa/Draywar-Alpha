class_name Balance
extends RefCounted

## The balance layer's entry file — Alpha A0.
##
## Every tunable lives here or under `src/data/balance/`.
## `scripts/check_magic_numbers.py` fails the build on a numeric literal
## anywhere under `src/` outside this layer.

## Content ceilings — keyed by content directory. S9 lifts toward Steam §10
## content-complete aims (docs/STEAM_PHASE_PLAN.md §10). E5 historical notes in
## `docs/BETA_E5_CONTENT_SCALE.md` remain for archaeology only.
##
## These are **ceilings, not targets**. Exceeding one is a stop condition, and
## `ContentLibrary` turns that into a loud failure at load. Categories listed
## with no directory yet cost nothing and document where the pipeline is going.
const CONTENT_BUDGET: Dictionary[StringName, int] = {
	## S9: Steam aim 8–10 systems.
	&"star_systems": 10,
	## S9: Steam aim 16–22 docks.
	&"stations": 22,
	## S9: Steam aim 8–12 Entities (includes player Holding).
	&"entities": 12,
	## S9: Steam aim 35–50 tracked People.
	&"people": 50,
	## S9: Steam aim 12 commodities.
	&"commodities": 12,
	## S9: spine + hand + flashpoint board rows under one ceiling.
	&"contract_types": 48,
	&"hulls": 2,
	&"weapons": 12,
	&"equipment": 10,
	## S9: Steam aim 8–12 personal recovery chains.
	&"recovery_chains": 12,
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
