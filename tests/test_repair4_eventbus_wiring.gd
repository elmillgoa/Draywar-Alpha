extends GutTest

## REPAIR-4 — UI/world routes three direct service calls through EventBus.
##
## Job 12 declared on_incident_respond_requested and on_combat_lock_requested
## and kept on_recovery_offered. This brief only wires emitters and listeners;
## EventBus.gd signal set is untouched.
##
## Proves:
##   1. FlightHUD respond path emits on_incident_respond_requested; service
##      resolves via that signal (not a direct IncidentService.respond call).
##   2. HostileNpc combat lock open/close rides on_combat_lock_requested.
##   3. StationMenu Talk button appears after a real dock when RecoveryService
##      (earlier sibling) emits on_recovery_offered before the menu's
##      _on_docked — the ordering trap Job 12 named.
##   3b. After that dock, the Talk person survives a refresh with the recovery
##      service unreachable — bus cache, not a re-query (route guard; attempt-1
##      bounce).
##   3c. Multi-offer dock (Delta Yard) keeps the FIRST person, matching the
##      pre-REPAIR-4 query order (attempt-1 bounce: last-wins flipped Reed→Wren).
##   3d–3f. The cache lifecycle (attempt-2 bounce). Replacing a per-refresh query
##      with a cache filled once at dock made the Talk button unrecoverable: any
##      handler that blanked the cache stranded it until the player undocked.
##      RecoveryService now re-announces on every transition that can change what
##      has_offer_for_person answers, so these three cover a blank-and-refill for
##      each kind — chain progress, an unrelated Person closing, and a standing
##      move that genuinely withdraws the offer (which must NOT come back).

const PERSON_MENDI: StringName = &"person_ra_mendi"
const PERSON_REED: StringName = &"person_fh_reed"
const PERSON_WREN: StringName = &"person_fh_wren"
const STATION_ALPHA: StringName = &"station_alpha_port"
const STATION_DELTA_YARD: StringName = &"station_delta_yard"
const ALPHA: StringName = &"system_alpha"
const LETHAL: float = 10_000.0

var _respond_hits: Array[Dictionary] = []
var _lock_request_hits: Array[bool] = []


func before_each() -> void:
	_respond_hits.clear()
	_lock_request_hits.clear()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()
	WorldClockHelpers.reset_clock()
	IncidentService.reset()
	StandingService.reset_to_defaults()
	MarketService.reset()
	BoardService.reset()
	EventBus.on_incident_respond_requested.connect(_on_respond_requested)
	EventBus.on_combat_lock_requested.connect(_on_lock_requested)


func after_each() -> void:
	if EventBus.on_incident_respond_requested.is_connected(_on_respond_requested):
		EventBus.on_incident_respond_requested.disconnect(_on_respond_requested)
	if EventBus.on_combat_lock_requested.is_connected(_on_lock_requested):
		EventBus.on_combat_lock_requested.disconnect(_on_lock_requested)
	IncidentService.reset()
	StandingService.reset_to_defaults()
	MarketService.reset()
	BoardService.reset()
	WorldClockHelpers.reset_clock()
	TimeScale.set_combat_lock(false)
	TimeScale.reset()


func _on_respond_requested(incident_id: StringName, choice: StringName) -> void:
	_respond_hits.append({&"id": incident_id, &"choice": choice})


func _on_lock_requested(locked: bool) -> void:
	_lock_request_hits.append(locked)


# --- Item 1: incident respond request -----------------------------------------


func test_flight_hud_respond_emits_request_and_service_resolves() -> void:
	## HUD must not call IncidentService.respond; the bus carries the choice.
	var mission: MissionService = MissionService.new()
	add_child_autofree(mission)
	mission.reset()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()

	IncidentService.set_ship_count_override(1)
	var id: StringName = IncidentService.force_offer(BalanceIncident.KIND_DISTRESS, ALPHA)
	assert_false(String(id).is_empty(), "fixture offer must land")

	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	# Simulate free-flight active prompt (same fields on_incident_prompt sets).
	hud._active_incident_id = id
	hud._active_incident_kind = BalanceIncident.KIND_DISTRESS
	hud._docked_station_id = &""

	hud._respond_active_incident(true)
	assert_eq(_respond_hits.size(), 1, "HUD must emit on_incident_respond_requested")
	var hit: Dictionary = _respond_hits[0]
	var hit_id: StringName = StringName(str(hit[&"id"]))
	var hit_choice: StringName = StringName(str(hit[&"choice"]))
	assert_eq(hit_id, id)
	assert_eq(hit_choice, BalanceIncident.CHOICE_HELP)
	assert_eq(
		IncidentService.offered_count(),
		0,
		"IncidentService must resolve the offer after listening to the request signal"
	)


# --- Item 2: combat lock request ----------------------------------------------


func test_hostile_spawn_and_death_request_combat_lock_via_bus() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)

	var hostile: HostileNpc = HostileNpc.spawn_under(host, Vector3(8.0, 0.0, 0.0))
	await get_tree().process_frame
	assert_true(_lock_request_hits.has(true), "spawn must request combat lock via bus")
	assert_true(TimeScale.is_combat_locked(), "TimeScale must honour the request signal")

	hostile.take_damage(LETHAL)
	assert_true(_lock_request_hits.has(false), "last death must request lock release via bus")
	assert_false(TimeScale.is_combat_locked(), "TimeScale must release on the request signal")


# --- Item 3: recovery offered → StationMenu Talk button -----------------------


func test_station_menu_talk_button_appears_after_real_dock_via_offer_signal() -> void:
	## RecoveryService must be an earlier sibling than StationMenu so its
	## on_docked handler (and on_recovery_offered emit) runs first — the trap
	## Job 12 named. Emitting on_recovery_offered by hand would not prove that.
	StandingService.set_person_standing(PERSON_MENDI, BalanceStanding.TIER_FRIENDLY_MIN + 5.0)

	var host: Node = Node.new()
	add_child_autofree(host)

	var recovery: RecoveryService = RecoveryService.new()
	host.add_child(recovery)
	await get_tree().process_frame
	recovery.reset()

	var menu: StationMenu = StationMenu.new()
	host.add_child(menu)
	await get_tree().process_frame

	# Real dock path — both listen to EventBus.on_docked; recovery fires first.
	EventBus.on_docked.emit(STATION_ALPHA)
	await get_tree().process_frame

	var person_item: ContentItem = ContentLibrary.item(PERSON_MENDI)
	assert_ne(person_item, null, "Mendi content must exist")
	var talk_label: String = BalanceStanding.STATION_RECOVERY_TALK_FORMAT % person_item.display_name
	var talk_btn: Button = _find_button_with_text(menu, talk_label)
	assert_ne(talk_btn, null, "Talk button must exist after dock")
	assert_true(
		talk_btn.visible,
		(
			"REPAIR-4: Talk button must stay visible after StationMenu._on_docked "
			+ "clears/refreshes — offer cache must survive the ordering trap"
		)
	)

	# Route guard (attempt-1 bounce): pin the bus cache, not the old query path.
	# Old StationMenu re-read has_offer_for_person inside _refresh_recovery_buttons;
	# with the service group gone that re-query returns empty and hides Talk.
	# The bus cache must keep the person after the same refresh.
	recovery.remove_from_group(&"recovery_service")
	menu._refresh_recovery_buttons()
	assert_true(
		talk_btn.visible, "Talk must stay visible after refresh with recovery_service unreachable"
	)
	assert_eq(
		talk_btn.text,
		talk_label,
		"Talk must still name the bus-cached person when the query cannot run"
	)

	EventBus.on_undocked.emit(STATION_ALPHA)
	await get_tree().process_frame
	assert_false(talk_btn.visible, "Talk button must hide on undock (offer cache cleared)")


func test_station_menu_talk_keeps_first_offer_at_delta_yard() -> void:
	## Free Haulers control Delta Yard and own two recovery chains (Reed then
	## Wren, alphabetical content order). RecoveryService emits once per chain;
	## the menu must keep the first person so Talk matches pre-REPAIR-4 query
	## order (first match), not the last emit.
	StandingService.set_person_standing(PERSON_REED, BalanceStanding.TIER_FRIENDLY_MIN + 5.0)
	StandingService.set_person_standing(PERSON_WREN, BalanceStanding.TIER_FRIENDLY_MIN + 5.0)

	var host: Node = Node.new()
	add_child_autofree(host)

	var recovery: RecoveryService = RecoveryService.new()
	host.add_child(recovery)
	await get_tree().process_frame
	recovery.reset()
	assert_true(recovery.has_offer_for_person(PERSON_REED), "Reed must be offerable")
	assert_true(recovery.has_offer_for_person(PERSON_WREN), "Wren must be offerable")

	var menu: StationMenu = StationMenu.new()
	host.add_child(menu)
	await get_tree().process_frame

	EventBus.on_docked.emit(STATION_DELTA_YARD)
	await get_tree().process_frame

	var reed_item: ContentItem = ContentLibrary.item(PERSON_REED)
	var wren_item: ContentItem = ContentLibrary.item(PERSON_WREN)
	assert_ne(reed_item, null)
	assert_ne(wren_item, null)
	var reed_label: String = BalanceStanding.STATION_RECOVERY_TALK_FORMAT % reed_item.display_name
	var wren_label: String = BalanceStanding.STATION_RECOVERY_TALK_FORMAT % wren_item.display_name

	var reed_btn: Button = _find_button_with_text(menu, reed_label)
	assert_ne(reed_btn, null, "Talk button must name Reed (first Free Haulers offer)")
	assert_true(reed_btn.visible, "Reed Talk must be visible at Delta Yard")
	assert_eq(
		_find_button_with_text(menu, wren_label),
		null,
		"Talk must not flip to Wren (last emit) — first offer wins for the dock"
	)

	EventBus.on_undocked.emit(STATION_DELTA_YARD)
	await get_tree().process_frame


# --- Item 3d–3f: the cache lifecycle -----------------------------------------


func test_station_menu_talk_returns_for_next_chain_step_without_undocking() -> void:
	## Every shipped chain is multi-step and the follow-on unlocks the instant the
	## step before it is completed, so finishing a step at a station must put Talk
	## straight back. The cache is blanked by _on_recovery_closed; only the
	## service's re-announce can refill it, and nothing else in the game can.
	StandingService.set_person_standing(PERSON_MENDI, BalanceStanding.TIER_FRIENDLY_MIN + 5.0)
	var menu: StationMenu = await _docked_menu(STATION_ALPHA)
	var talk: Button = _talk_button(menu, PERSON_MENDI)
	assert_ne(talk, null, "Talk button must exist after dock")
	assert_true(talk.visible, "Talk visible for step 1 after dock")

	var recovery: RecoveryService = _recovery_node(menu)
	assert_true(recovery.accept(PERSON_MENDI), "step 1 must accept")
	await get_tree().process_frame
	var report: Dictionary = recovery.complete()
	assert_true(_report_ok(report), "step 1 must complete")
	await get_tree().process_frame

	assert_true(
		recovery.has_offer_for_person(PERSON_MENDI),
		"fixture check: a further step is offerable the moment step 1 lands"
	)
	assert_true(
		menu._recovery_btn.visible,
		"REPAIR-4: Talk must return for the next step in the same dock, without undocking"
	)


func test_station_menu_talk_survives_an_unrelated_person_being_closed() -> void:
	## Delta Yard offers Reed and Wren. The menu blanks its cache on
	## on_person_closed without knowing who closed, so closing Wren must not cost
	## Reed his Talk button — the re-announce is what puts Reed back.
	StandingService.set_person_standing(PERSON_REED, BalanceStanding.TIER_FRIENDLY_MIN + 5.0)
	StandingService.set_person_standing(PERSON_WREN, BalanceStanding.TIER_FRIENDLY_MIN + 5.0)
	var menu: StationMenu = await _docked_menu(STATION_DELTA_YARD)
	var talk: Button = _talk_button(menu, PERSON_REED)
	assert_ne(talk, null, "Reed's Talk button must exist after dock")
	assert_true(talk.visible, "Reed's Talk visible after dock")

	StandingService.close_person(PERSON_WREN, BalanceStanding.RECOVERY_CLOSE_REASON_BETRAYAL)
	await get_tree().process_frame

	var recovery: RecoveryService = _recovery_node(menu)
	assert_true(
		recovery.has_offer_for_person(PERSON_REED),
		"fixture check: Reed is untouched by Wren closing"
	)
	assert_true(
		menu._recovery_btn.visible,
		"REPAIR-4: closing one Person must not hide another Person's Talk button"
	)
	assert_eq(
		menu._recovery_btn.text,
		_talk_label(PERSON_REED),
		"REPAIR-4: the surviving offer must still name Reed"
	)


func test_station_menu_talk_withdraws_when_standing_drops_below_friendly() -> void:
	## The other direction, and the one a refill can hide: an offer that is really
	## gone must not be re-announced. Before REPAIR-4 the per-refresh query took
	## this away by itself; the cache has to do the same or the button lies.
	StandingService.set_person_standing(PERSON_MENDI, BalanceStanding.TIER_FRIENDLY_MIN + 1.0)
	var menu: StationMenu = await _docked_menu(STATION_ALPHA)
	assert_true(menu._recovery_btn.visible, "Talk visible while Mendi is Friendly")

	var recovery: RecoveryService = _recovery_node(menu)
	StandingService.set_person_standing(PERSON_MENDI, BalanceStanding.TIER_FRIENDLY_MIN - 10.0)
	await get_tree().process_frame

	assert_false(
		recovery.has_offer_for_person(PERSON_MENDI),
		"fixture check: below Friendly, Mendi no longer offers"
	)
	assert_false(
		menu._recovery_btn.visible,
		"REPAIR-4: Talk must go when the offer is genuinely withdrawn, not linger on a stale cache"
	)


## Real RecoveryService + StationMenu as siblings, berthed at `station_id`.
func _docked_menu(station_id: StringName) -> StationMenu:
	var host: Node = Node.new()
	add_child_autofree(host)
	var recovery: RecoveryService = RecoveryService.new()
	host.add_child(recovery)
	await get_tree().process_frame
	recovery.reset()
	var menu: StationMenu = StationMenu.new()
	host.add_child(menu)
	await get_tree().process_frame
	EventBus.on_docked.emit(station_id)
	await get_tree().process_frame
	return menu


func _report_ok(report: Dictionary) -> bool:
	return report.get(RecoveryService.REPORT_KEY_OK, false) == true


func _recovery_node(menu: StationMenu) -> RecoveryService:
	for child: Node in menu.get_parent().get_children():
		if child is RecoveryService:
			return child as RecoveryService
	return null


func _talk_label(person_id: StringName) -> String:
	var item: ContentItem = ContentLibrary.item(person_id)
	return BalanceStanding.STATION_RECOVERY_TALK_FORMAT % item.display_name


func _talk_button(menu: StationMenu, person_id: StringName) -> Button:
	return _find_button_with_text(menu, _talk_label(person_id))


func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button:
		var btn: Button = node as Button
		if btn.text == text:
			return btn
	for child: Node in node.get_children():
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null
