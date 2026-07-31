extends GutTest

## E4.5 / E4.6 — captain path lines, career save section, softlock scenarios.
##
## Implements: docs/BETA_E4_OPENING_CAST.md E4.5–E4.6 / D10–D11

const FIXTURE_PATH: String = "user://e4_career_path_test.sav"
const ENTITY_REACH: StringName = BalanceStanding.PATH_ENTITY_REACH
const ENTITY_HAULERS: StringName = BalanceStanding.PATH_ENTITY_HAULERS
const ENTITY_DRIFT: StringName = BalanceStanding.PATH_ENTITY_DRIFT
const PERSON_JAX: StringName = BalanceStanding.PATH_PERSON_JAX
const PERSON_MENDI: StringName = &"person_ra_mendi"


func after_each() -> void:
	StandingService.reset_to_defaults()
	CareerStart.reset()
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(FIXTURE_PATH)


func test_career_start_stores_path_ids_on_apply() -> void:
	CareerStart.reset()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	assert_false(CareerStart.has_path())
	CareerStart.apply(&"origin_core", &"trade_navy", &"mark_clean", wallet)
	assert_true(CareerStart.has_path())
	assert_eq(CareerStart.origin_id, &"origin_core")
	assert_eq(CareerStart.trade_id, &"trade_navy")
	assert_eq(CareerStart.mark_id, &"mark_clean")
	assert_false(CareerStart.opening_complete)
	CareerStart.mark_opening_complete()
	assert_true(CareerStart.opening_complete)


func test_captain_sheet_shows_origin_trade_mark_when_path_set() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	CareerStart.apply_default(wallet)
	CareerStart.mark_opening_complete()

	var sheet: CaptainSheet = CaptainSheet.new()
	add_child_autofree(sheet)
	await get_tree().process_frame
	EventBus.on_captain_sheet_open_requested.emit()
	await get_tree().process_frame

	var texts: PackedStringArray = _all_label_text(sheet)
	assert_true(_joined(texts).contains("Periphery"), "origin display")
	assert_true(_joined(texts).contains("Merchant"), "trade display")
	assert_true(_joined(texts).contains("Clean"), "mark display")
	assert_true(_joined(texts).contains(BalanceSession.SHEET_ORIGIN_FORMAT.substr(0, 6)))


func test_captain_sheet_hides_path_when_unset() -> void:
	CareerStart.reset()
	var sheet: CaptainSheet = CaptainSheet.new()
	add_child_autofree(sheet)
	await get_tree().process_frame
	EventBus.on_captain_sheet_open_requested.emit()
	await get_tree().process_frame
	var texts: PackedStringArray = _all_label_text(sheet)
	assert_false(_joined(texts).contains("Origin  "), "no origin line without path")


func test_career_section_round_trip_via_career_save() -> void:
	var host: Node = Node.new()
	add_child_autofree(host)
	var wallet: WalletService = WalletService.new()
	host.add_child(wallet)
	await get_tree().process_frame
	wallet.reset()
	CareerStart.apply(&"origin_charterfall", &"trade_smuggler", &"mark_cancelled", wallet)
	CareerStart.mark_opening_complete()

	var sections: Dictionary = CareerSave.gather_sections(get_tree())
	assert_true(sections.has(BalanceSession.SAVE_SECTION_CAREER), "career section written")
	var career_sec: Dictionary = sections[BalanceSession.SAVE_SECTION_CAREER]
	assert_eq(str(career_sec[BalanceSession.CAREER_KEY_ORIGIN_ID]), "origin_charterfall")
	assert_eq(str(career_sec[BalanceSession.CAREER_KEY_TRADE_ID]), "trade_smuggler")
	assert_eq(str(career_sec[BalanceSession.CAREER_KEY_MARK_ID]), "mark_cancelled")
	var open_flag: Variant = career_sec[BalanceSession.CAREER_KEY_OPENING_COMPLETE]
	var opening_saved: bool = false
	if typeof(open_flag) == TYPE_BOOL:
		var as_bool: bool = open_flag
		opening_saved = as_bool
	assert_true(opening_saved)

	var service: SaveService = SaveService.new()
	var envelope: Dictionary = SaveService.envelope(sections, "e4_path")
	var written: SaveResult = service.save_to(FIXTURE_PATH, envelope)
	assert_true(written.ok(), written.summary())

	CareerStart.reset()
	StandingService.reset_to_defaults()
	assert_false(CareerStart.has_path())

	var loaded: SaveResult = CareerSave.load_envelope(FIXTURE_PATH)
	assert_true(loaded.ok(), loaded.summary())
	var loaded_sections: Dictionary = {}
	if loaded.envelope.has(SaveService.KEY_SECTIONS):
		var raw: Variant = loaded.envelope[SaveService.KEY_SECTIONS]
		if typeof(raw) == TYPE_DICTIONARY:
			loaded_sections = raw
	CareerSave.apply_meta_sections(get_tree(), loaded_sections)
	assert_eq(CareerStart.origin_id, &"origin_charterfall")
	assert_eq(CareerStart.trade_id, &"trade_smuggler")
	assert_eq(CareerStart.mark_id, &"mark_cancelled")
	assert_true(CareerStart.opening_complete)
	# Standing teeth restored via standing section, not re-applied from path.
	assert_lt(StandingService.get_entity_standing(ENTITY_REACH), 0.0)
	assert_gt(StandingService.get_entity_standing(ENTITY_DRIFT), 0.0)


func test_missing_career_section_is_old_save() -> void:
	CareerStart.apply(&"origin_core", &"trade_navy", &"mark_clean", null)
	CareerStart.mark_opening_complete()
	assert_true(CareerStart.has_path())
	# Apply sections without career key.
	CareerSave.apply_meta_sections(get_tree(), {})
	assert_false(CareerStart.has_path())
	assert_false(CareerStart.opening_complete)


func test_softlock_default_playable_not_all_neutral() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	CareerStart.apply_default(wallet)
	# Default leaves Haulers + Fringe above zero.
	assert_gt(StandingService.get_entity_standing(ENTITY_HAULERS), 0.0)
	assert_gt(wallet.credits(), 0)
	# Can dock Alpha (Reach) at default standing.
	assert_true(StandingService.can_dock_at_station(&"station_alpha_port"))


func test_softlock_debt_start_has_debt() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	var before: int = wallet.credits()
	CareerStart.apply(&"origin_periphery", &"trade_merchant", &"mark_debt", wallet)
	var owed: int = _owed(wallet)
	assert_eq(owed, BalanceEconomy.LOAN_REPAY_TOTAL)
	assert_eq(wallet.credits(), before + BalanceEconomy.LOAN_PRINCIPAL)


func test_softlock_cancelled_smuggler_still_has_mendi_and_jax_paths() -> void:
	# Cancelled + smuggler digs into Reach but Mendi/Jax recovery contacts stay open.
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	CareerStart.apply(&"origin_core", &"trade_smuggler", &"mark_cancelled", wallet)
	assert_lt(StandingService.get_entity_standing(ENTITY_REACH), 0.0)
	# Personal contacts not closed by life path.
	assert_false(StandingService.is_person_closed(PERSON_MENDI))
	assert_false(StandingService.is_person_closed(PERSON_JAX))
	# Mendi recovery still exists as content + dock offer machinery (Friendly personal gate).
	assert_true(ContentLibrary.has_item(&"recovery_reach_mendi"))
	assert_true(ContentLibrary.has_item(&"recovery_drift_jax"))
	# Smuggler boosts Jax personal — Friendly band reachable for Drift foothold.
	assert_gt(StandingService.get_person_standing(PERSON_JAX), 0.0)


func test_main_menu_tagline_present() -> void:
	var menu: MainMenu = MainMenu.new()
	add_child_autofree(menu)
	await get_tree().process_frame
	var texts: PackedStringArray = _all_label_text(menu)
	assert_true(texts.has(BalanceSession.MAIN_TITLE) or _joined(texts).contains("DRAYWAR"))
	if not BalanceSession.MAIN_TAGLINE.is_empty():
		assert_true(_joined(texts).contains(BalanceSession.MAIN_TAGLINE), "tagline on menu")


func test_alpha_port_flavor_annexation_language() -> void:
	var port: Station = ContentLibrary.item(&"station_alpha_port") as Station
	assert_ne(port, null)
	assert_true(
		port.flavor_line.contains("Reach") or port.flavor_line.contains("pad"), port.flavor_line
	)


func _owed(wallet: WalletService) -> int:
	var state: Dictionary = wallet.debt_state()
	var raw: Variant = state.get(&"owed", 0)
	if typeof(raw) == TYPE_INT:
		var as_int: int = raw
		return as_int
	if typeof(raw) == TYPE_FLOAT:
		var as_float: float = raw
		return int(as_float)
	return 0


func _all_label_text(root: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	_collect_labels(root, out)
	return out


func _collect_labels(node: Node, out: PackedStringArray) -> void:
	if node is Label:
		out.append((node as Label).text)
	for child: Node in node.get_children():
		_collect_labels(child, out)


func _joined(texts: PackedStringArray) -> String:
	return "\n".join(texts)
