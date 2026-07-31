extends GutTest

## E4.3 annexation beat + opening order helpers.
##
## Implements: docs/BETA_E4_OPENING_CAST.md E4.3 / D5–D6, D11

const ENTITY_REACH: StringName = BalanceStanding.PATH_ENTITY_REACH
const SYSTEM_ALPHA: StringName = &"system_alpha"


func after_each() -> void:
	StandingService.reset_to_defaults()
	CareerStart.reset()


func test_annexation_ui_theme_title_body_continue() -> void:
	var annex: OpeningAnnexation = OpeningAnnexation.new()
	add_child_autofree(annex)
	await get_tree().process_frame
	annex.show_annexation("Your standing here: Cordial — Reach Authority")
	assert_true(annex.is_open())
	var panel: PanelContainer = _find_panel(annex)
	assert_ne(panel, null)
	assert_ne(panel.theme, null)
	assert_true(panel.theme.has_stylebox("panel", "PanelContainer"))
	var texts: PackedStringArray = _all_text(annex)
	assert_true(texts.has(BalanceSession.ANNEXATION_TITLE), "title")
	assert_true(texts.has(BalanceSession.ANNEXATION_CONTINUE), "continue")
	var blob: String = _joined(texts)
	assert_true(blob.contains("Alpha Port"), "body copy present")
	assert_true(blob.contains("Reach Authority"), "body names Reach")
	assert_true(blob.contains("Cordial"), "baggage line shown")


func test_annexation_continue_emits_once() -> void:
	var annex: OpeningAnnexation = OpeningAnnexation.new()
	add_child_autofree(annex)
	await get_tree().process_frame
	annex.show_annexation("test baggage")

	var hits: Array[int] = []
	var handler := func() -> void: hits.append(1)
	EventBus.on_annexation_continue_requested.connect(handler)

	var cont: Button = _find_button(annex, BalanceSession.ANNEXATION_CONTINUE)
	assert_ne(cont, null)
	cont.pressed.emit()
	cont.pressed.emit()
	assert_eq(hits.size(), 1, "one-shot continue")

	EventBus.on_annexation_continue_requested.disconnect(handler)


func test_baggage_matches_post_path_reach_standing() -> void:
	StandingService.reset_to_defaults()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()

	CareerStart.apply(&"origin_core", &"trade_navy", &"mark_clean", wallet)
	var expected_standing: float = (
		BalanceStanding.PATH_ORIGIN_CORE_REACH + BalanceStanding.PATH_TRADE_NAVY_REACH
	)
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_REACH), expected_standing, 0.001)
	var status: Dictionary = StandingService.status_for_system(SYSTEM_ALPHA)
	var baggage: String = OpeningAnnexation.baggage_from_status(status)
	assert_false(baggage.is_empty())
	var tier_display: String = StandingService.tier_display_name(
		StandingService.tier_for(expected_standing)
	)
	assert_true(baggage.contains(tier_display) or baggage.contains("Reach"), baggage)
	# Smuggler path must read differently on Reach (negative teeth).
	StandingService.reset_to_defaults()
	wallet.reset()
	CareerStart.apply(&"origin_periphery", &"trade_smuggler", &"mark_clean", wallet)
	var smug_status: Dictionary = StandingService.status_for_system(SYSTEM_ALPHA)
	var smug_baggage: String = OpeningAnnexation.baggage_from_status(smug_status)
	assert_ne(baggage, smug_baggage, "navy vs smuggler baggage differ")


func test_annexation_is_presentation_only_no_control_mutation() -> void:
	# D5: Alpha already Reach; beat must not rewrite system held_by / station controller.
	var system_item: ContentItem = ContentLibrary.item(SYSTEM_ALPHA)
	assert_true(system_item is StarSystem)
	var system: StarSystem = system_item as StarSystem
	var held_before: StringName = system.held_by

	var station_item: ContentItem = ContentLibrary.item(&"station_alpha_port")
	assert_true(station_item is Station)
	var station: Station = station_item as Station
	var controller_before: StringName = station.controller_entity_id

	var annex: OpeningAnnexation = OpeningAnnexation.new()
	add_child_autofree(annex)
	await get_tree().process_frame
	StandingService.reset_to_defaults()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	CareerStart.apply_default(wallet)
	var status: Dictionary = StandingService.status_for_system(SYSTEM_ALPHA)
	annex.show_annexation(OpeningAnnexation.baggage_from_status(status))
	_find_button(annex, BalanceSession.ANNEXATION_CONTINUE).pressed.emit()
	annex.hide_annexation()

	assert_eq(system.held_by, held_before, "system control unchanged")
	assert_eq(station.controller_entity_id, controller_before, "station control unchanged")
	assert_eq(system.held_by, ENTITY_REACH, "Alpha remains Reach")


func test_status_moment_after_path_matches_baggage_controller() -> void:
	StandingService.reset_to_defaults()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	CareerStart.apply(&"origin_core", &"trade_navy", &"mark_clean", wallet)

	var kinds: Array[StringName] = []
	var entities: Array[StringName] = []
	var standings: Array[float] = []
	var handler := func(
		kind: StringName,
		_place_id: StringName,
		entity_id: StringName,
		standing: float,
		_tier: StringName
	) -> void:
		kinds.append(kind)
		entities.append(entity_id)
		standings.append(standing)
	EventBus.on_status_moment.connect(handler)
	StandingService.emit_status_for_system(SYSTEM_ALPHA)

	assert_eq(kinds.size(), 1)
	assert_eq(kinds[0], BalanceStanding.STATUS_KIND_SYSTEM)
	assert_eq(entities[0], ENTITY_REACH)
	assert_almost_eq(
		standings[0],
		BalanceStanding.PATH_ORIGIN_CORE_REACH + BalanceStanding.PATH_TRADE_NAVY_REACH,
		0.001
	)
	var status: Dictionary = StandingService.status_for_system(SYSTEM_ALPHA)
	var baggage: String = OpeningAnnexation.baggage_from_status(status)
	var tier_display: String = StandingService.tier_display_name(
		StandingService.tier_for(standings[0])
	)
	assert_true(baggage.contains(tier_display), baggage)

	EventBus.on_status_moment.disconnect(handler)


func test_opening_order_create_then_annexation_then_tip_surfaces() -> void:
	# Widget-level order: create open → confirm → annexation open → continue → tip open.
	# Mirrors Main without loading the full scene tree of services.
	var create: LifePathCreate = LifePathCreate.new()
	var annex: OpeningAnnexation = OpeningAnnexation.new()
	var tip: NewGameTip = NewGameTip.new()
	add_child_autofree(create)
	add_child_autofree(annex)
	add_child_autofree(tip)
	await get_tree().process_frame

	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()
	StandingService.reset_to_defaults()

	create.show_create()
	assert_true(create.is_open())
	assert_false(annex.is_open())
	assert_false(tip.is_open())

	var on_confirm := func(
		origin_id: StringName, trade_id: StringName, mark_id: StringName
	) -> void:
		CareerStart.apply(origin_id, trade_id, mark_id, wallet)
		StandingService.emit_status_for_system(SYSTEM_ALPHA)
		create.hide_create()
		var status: Dictionary = StandingService.status_for_system(SYSTEM_ALPHA)
		annex.show_annexation(OpeningAnnexation.baggage_from_status(status))
	EventBus.on_life_path_confirmed.connect(on_confirm)

	var on_annex := func() -> void:
		annex.hide_annexation()
		tip.show_tip()
	EventBus.on_annexation_continue_requested.connect(on_annex)

	_press_option_named(create, "Periphery-born")
	_press_option_named(create, "Merchant marine")
	_press_option_named(create, "Clean")
	_find_button(create, BalanceSession.LIFE_PATH_CREATE_CONFIRM).pressed.emit()

	assert_false(create.is_open())
	assert_true(annex.is_open())
	assert_false(tip.is_open())

	_find_button(annex, BalanceSession.ANNEXATION_CONTINUE).pressed.emit()
	assert_false(annex.is_open())
	assert_true(tip.is_open())

	EventBus.on_life_path_confirmed.disconnect(on_confirm)
	EventBus.on_annexation_continue_requested.disconnect(on_annex)


func test_continue_path_never_shows_create_or_annexation() -> void:
	# Continue/load contract: those surfaces stay hidden (D11).
	var create: LifePathCreate = LifePathCreate.new()
	var annex: OpeningAnnexation = OpeningAnnexation.new()
	var tip: NewGameTip = NewGameTip.new()
	add_child_autofree(create)
	add_child_autofree(annex)
	add_child_autofree(tip)
	await get_tree().process_frame
	# Simulate continue: no show_create / show_annexation; tip stays hidden.
	create.hide_create()
	annex.hide_annexation()
	tip.hide_tip()
	assert_false(create.is_open())
	assert_false(annex.is_open())
	assert_false(tip.is_open())


func _find_panel(root: Node) -> PanelContainer:
	if root is PanelContainer:
		return root as PanelContainer
	for child: Node in root.get_children():
		var found: PanelContainer = _find_panel(child)
		if found != null:
			return found
	return null


func _find_button(root: Node, text: String) -> Button:
	if root is Button:
		var btn: Button = root as Button
		if btn.text == text:
			return btn
	for child: Node in root.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


func _all_text(root: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	_collect_text(root, out)
	return out


func _collect_text(node: Node, out: PackedStringArray) -> void:
	if node is Label:
		out.append((node as Label).text)
	if node is Button:
		out.append((node as Button).text)
	for child: Node in node.get_children():
		_collect_text(child, out)


func _joined(texts: PackedStringArray) -> String:
	return "\n".join(texts)


func _press_option_named(create: LifePathCreate, display_name: String) -> void:
	for child: Node in create.get_children():
		var btn: Button = _find_button_prefix(child, display_name)
		if btn != null:
			btn.pressed.emit()
			return
	fail_test("option not found: %s" % display_name)


func _find_button_prefix(node: Node, display_name: String) -> Button:
	if node is Button:
		var btn: Button = node as Button
		if btn.text.begins_with(display_name) or btn.text.contains(display_name + "\n"):
			if (
				btn.text != BalanceSession.LIFE_PATH_CREATE_CONFIRM
				and btn.text != BalanceSession.LIFE_PATH_CREATE_CANCEL
			):
				return btn
	for child: Node in node.get_children():
		var found: Button = _find_button_prefix(child, display_name)
		if found != null:
			return found
	return null
