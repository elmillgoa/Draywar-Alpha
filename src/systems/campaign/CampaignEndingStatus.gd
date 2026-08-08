extends RefCounted

## Whether an Act III ending can still be reached — Job 6 phase 2.
##
## Decision: Draywar Review/DECISION_campaign-dead-end.md (Elliot, 2026-08-07):
## the dead end may stand, so the game says so at the moment it happens and
## tells a recoverable grind apart from a career that is genuinely finished.
##
## Law: docs/reputation_and_standing.md. This file is READ-ONLY. It writes no
## standing, invents no threshold, and adds no way to earn standing. It only
## reads the rules already in the code and reports what they leave reachable.
##
## Held by CampaignService as a preloaded const (no class_name, no autoload).
##
## ## Where this is approximate, and which way it errs
##
## The repairability test is deliberately GENEROUS. It counts a route as live
## whenever the mechanism exists at all, ignoring how long the grind would be,
## the trade soft cap, stickiness below -40, and the per-event ripple cap. So it
## will call a brutal thousand-job climb "still reachable", and it will almost
## never call a career finished. That is the direction Elliot asked for: telling
## a player they have ended the campaign when they could still climb out is
## worse than saying nothing.
##
## Concretely it counts three ways standing with an Entity can still rise, which
## are the three the code actually implements:
##   1. Work at a dock that Entity controls and the player may still enter —
##      the radiant board, legal trade, and their recovery contacts all live
##      there (BoardService / CargoService / StationDockQueries).
##   2. Raise an ally that lists them — the one-hop positive echo in
##      StandingService._apply_one_hop_ripple. Needs a dock to do the work at.
##   3. Hurt a rival that lists them — the same hop, inverted. Attributed kills
##      need no dock, only a system that rival holds.
## No multi-hop, because the ripple does not cascade (law §8).

const RESULT_KEY_GRADE: StringName = &"grade"
const RESULT_KEY_LINE: StringName = &"line"

const SYSTEM_CONTENT_CATEGORY: StringName = &"star_systems"


## Verdict for a claimed Holding: grade plus a player-facing line.
## `templates` are the unfinished ignition beats offered at the claimed dock.
static func evaluate(prior_id: StringName, templates: Array[ContractType]) -> Dictionary:
	if templates.is_empty():
		return _result(BalanceCampaign.ENDING_GRADE_OPEN, "")
	var blocked: bool = true
	var possible: bool = false
	for template: ContractType in templates:
		if template == null:
			continue
		if offerer_ok(template) and standoff_ok(prior_id, template.id):
			blocked = false
		if _route_possible(prior_id, template):
			possible = true
	if not blocked:
		return _result(BalanceCampaign.ENDING_GRADE_OPEN, "")
	var grade: StringName = BalanceCampaign.ENDING_GRADE_CLOSED
	if possible:
		grade = BalanceCampaign.ENDING_GRADE_STALLED
	return _result(grade, _needs_line(prior_id, templates, grade))


## Offering-Entity standing floor on a contract (the third lock the memo found:
## every ignition beat is offered by Free Haulers). Single home for the rule —
## CampaignService._standing_ok calls this rather than repeating it.
static func offerer_ok(template: ContractType) -> bool:
	if template == null:
		return false
	if template.min_entity_standing <= BalanceCampaign.STANDING_NO_FLOOR:
		return true
	var standing: float = StandingService.get_entity_standing(template.offering_entity_id)
	return standing >= template.min_entity_standing


## Standoff rule: papers when the prior controller is Neutral+, force only when
## papers is shut and a backer is Friendly. Single home for the rule —
## CampaignService._ignition_standoff_ok calls this.
static func standoff_ok(prior_id: StringName, template_id: StringName) -> bool:
	var prior_standing: float = StandingService.get_entity_standing(prior_id)
	var papers_ok: bool = prior_standing >= BalanceHolding.STANDOFF_PAPERS_STANDING_MIN
	if BalanceHolding.is_papers_ignition(template_id):
		return papers_ok
	if BalanceHolding.is_force_ignition(template_id):
		if papers_ok:
			return false
		return has_backing()
	return true


## True when either backing Entity is Friendly enough to back a contested claim.
static func has_backing() -> bool:
	for entity_id: StringName in BalanceHolding.STANDOFF_BACKING_ENTITY_IDS:
		var standing: float = StandingService.get_entity_standing(entity_id)
		if standing >= BalanceHolding.STANDOFF_BACKING_STANDING_MIN:
			return true
	return false


## True when any live mechanism can still raise player standing with this
## Entity. Generous on purpose — see the file header.
static func can_still_earn_standing(entity_id: StringName) -> bool:
	if String(entity_id).strip_edges().is_empty():
		return false
	if has_workable_dock(entity_id):
		return true
	for source_id: StringName in ContentLibrary.ids_in(BalanceSession.ENTITY_CONTENT_CATEGORY):
		if source_id == entity_id:
			continue
		var item: ContentItem = ContentLibrary.item(source_id)
		if not (item is Entity):
			continue
		var source: Entity = item as Entity
		if _source_can_echo_to(source, entity_id, source_id):
			return true
	return false


## True when this Entity controls a dock the player may still walk into.
## Dock refusal already lets an open recovery contact through (law §5), so a
## Hostile player with a contact still counts as able to work here.
static func has_workable_dock(entity_id: StringName) -> bool:
	for station_id: StringName in ContentLibrary.ids_in(BalanceMarket.STATION_CONTENT_CATEGORY):
		if StandingService.station_controller_id(station_id) != entity_id:
			continue
		if StandingService.can_dock_at_station(station_id):
			return true
	return false


## True when this Entity holds a star system, i.e. there is somewhere the player
## can act against them and have it attributed (AttributionService reads
## StarSystem.held_by).
static func holds_a_system(entity_id: StringName) -> bool:
	for system_id: StringName in ContentLibrary.ids_in(SYSTEM_CONTENT_CATEGORY):
		var item: ContentItem = ContentLibrary.item(system_id)
		if not (item is StarSystem):
			continue
		var system: StarSystem = item as StarSystem
		if system.held_by == entity_id:
			return true
	return false


static func _source_can_echo_to(
	source: Entity, target_id: StringName, source_id: StringName
) -> bool:
	for link: EntityLink in source.relationship_links:
		if link == null or link.target_id != target_id:
			continue
		if _is_ally_relation(link.relation_type) and has_workable_dock(source_id):
			return true
		if _is_rival_relation(link.relation_type) and holds_a_system(source_id):
			return true
	return false


static func _is_ally_relation(relation_type: StringName) -> bool:
	return (
		relation_type == EntityLink.RELATION_ALLIED
		or relation_type == EntityLink.RELATION_SUBSIDIARY
		or relation_type == EntityLink.RELATION_MEMBER_OF
	)


static func _is_rival_relation(relation_type: StringName) -> bool:
	return relation_type == EntityLink.RELATION_RIVAL or relation_type == EntityLink.RELATION_ENEMY


## Could this one route be reopened by standing the player can still move?
static func _route_possible(prior_id: StringName, template: ContractType) -> bool:
	if template == null:
		return false
	if not offerer_ok(template) and not can_still_earn_standing(template.offering_entity_id):
		return false
	if BalanceHolding.is_papers_ignition(template.id):
		var prior_standing: float = StandingService.get_entity_standing(prior_id)
		if prior_standing >= BalanceHolding.STANDOFF_PAPERS_STANDING_MIN:
			return true
		return can_still_earn_standing(prior_id)
	if BalanceHolding.is_force_ignition(template.id):
		if has_backing():
			return true
		for entity_id: StringName in BalanceHolding.STANDOFF_BACKING_ENTITY_IDS:
			if can_still_earn_standing(entity_id):
				return true
		return false
	return true


## The player-facing sentence: what is short, by name, and how far.
static func _needs_line(
	prior_id: StringName, templates: Array[ContractType], grade: StringName
) -> String:
	var needs: PackedStringArray = _offerer_needs(templates)
	needs.append_array(_standoff_needs(prior_id, templates))
	if needs.is_empty():
		return ""
	var joined: String = BalanceCampaign.ENDING_NEED_JOIN.join(needs)
	if grade == BalanceCampaign.ENDING_GRADE_CLOSED:
		return BalanceCampaign.ENDING_CLOSED_FORMAT % joined
	return BalanceCampaign.ENDING_STALLED_FORMAT % joined


static func _offerer_needs(templates: Array[ContractType]) -> PackedStringArray:
	var needs: PackedStringArray = []
	var seen: Dictionary[StringName, bool] = {}
	for template: ContractType in templates:
		if template == null or offerer_ok(template):
			continue
		var offerer: StringName = template.offering_entity_id
		if seen.has(offerer):
			continue
		seen[offerer] = true
		needs.append(_need_text(offerer, template.min_entity_standing))
	return needs


static func _standoff_needs(
	prior_id: StringName, templates: Array[ContractType]
) -> PackedStringArray:
	var needs: PackedStringArray = []
	var wants_papers: bool = false
	var wants_force: bool = false
	for template: ContractType in templates:
		if template == null:
			continue
		if BalanceHolding.is_papers_ignition(template.id):
			wants_papers = true
		elif BalanceHolding.is_force_ignition(template.id):
			wants_force = true
	var prior_standing: float = StandingService.get_entity_standing(prior_id)
	if wants_papers and prior_standing < BalanceHolding.STANDOFF_PAPERS_STANDING_MIN:
		needs.append(_need_text(prior_id, BalanceHolding.STANDOFF_PAPERS_STANDING_MIN))
	if wants_force and not has_backing():
		needs.append(_backing_text())
	return needs


static func _backing_text() -> String:
	var names: PackedStringArray = []
	for entity_id: StringName in BalanceHolding.STANDOFF_BACKING_ENTITY_IDS:
		names.append(_display_name(entity_id))
	var tier: StringName = StandingService.tier_for(BalanceHolding.STANDOFF_BACKING_STANDING_MIN)
	return (
		BalanceCampaign.ENDING_NEED_BACKING_FORMAT
		% [BalanceCampaign.ENDING_BACKING_JOIN.join(names), StandingService.tier_display_name(tier)]
	)


static func _need_text(entity_id: StringName, floor_value: float) -> String:
	var wanted: StringName = StandingService.tier_for(floor_value)
	var held: StringName = StandingService.tier_for(StandingService.get_entity_standing(entity_id))
	return (
		BalanceCampaign.ENDING_NEED_TIER_FORMAT
		% [
			_display_name(entity_id),
			StandingService.tier_display_name(wanted),
			StandingService.tier_display_name(held),
		]
	)


static func _display_name(id: StringName) -> String:
	if String(id).is_empty():
		return String(id)
	if ContentLibrary.has_item(id):
		var item: ContentItem = ContentLibrary.item(id)
		if item != null and not item.display_name.is_empty():
			return item.display_name
	return String(id)


static func _result(grade: StringName, line: String) -> Dictionary:
	return {
		RESULT_KEY_GRADE: grade,
		RESULT_KEY_LINE: line,
	}
