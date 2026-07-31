extends GutTest

## E4.2 life-path create UI — three axes, confirm gated, cancel clean, teeth copy.
##
## Implements: docs/BETA_E4_OPENING_CAST.md E4.2

const ENTITY_REACH: StringName = BalanceStanding.PATH_ENTITY_REACH


func after_each() -> void:
	StandingService.reset_to_defaults()
	CareerStart.reset()


func test_create_ui_theme_and_axes() -> void:
	var create: LifePathCreate = LifePathCreate.new()
	add_child_autofree(create)
	await get_tree().process_frame
	create.show_create()
	assert_true(create.is_open())
	var panel: PanelContainer = _find_panel(create)
	assert_ne(panel, null, "create panel")
	assert_ne(panel.theme, null, "theme reused")
	assert_true(panel.theme.has_stylebox("panel", "PanelContainer"))
	var texts: PackedStringArray = _all_label_and_button_text(create)
	assert_true(texts.has(BalanceSession.LIFE_PATH_CREATE_TITLE), "title")
	assert_true(texts.has(BalanceSession.LIFE_PATH_CREATE_AXIS_ORIGIN), "origin axis")
	assert_true(texts.has(BalanceSession.LIFE_PATH_CREATE_AXIS_TRADE), "trade axis")
	assert_true(texts.has(BalanceSession.LIFE_PATH_CREATE_AXIS_MARK), "mark axis")
	assert_true(texts.has(BalanceSession.LIFE_PATH_CREATE_CONFIRM), "confirm")
	assert_true(texts.has(BalanceSession.LIFE_PATH_CREATE_CANCEL), "cancel")
	# Nine option rows land as buttons (3 × 3) plus confirm/cancel.
	var option_btns: Array[Button] = _option_buttons(create)
	assert_eq(option_btns.size(), BalanceStanding.LIFE_PATH_OPTION_COUNT)


func test_confirm_disabled_until_three_picks() -> void:
	var create: LifePathCreate = LifePathCreate.new()
	add_child_autofree(create)
	await get_tree().process_frame
	create.show_create()
	var confirm: Button = _find_button(create, BalanceSession.LIFE_PATH_CREATE_CONFIRM)
	assert_ne(confirm, null)
	assert_true(confirm.disabled, "confirm starts disabled")
	assert_false(create.has_full_selection())

	_press_option_named(create, "Periphery-born")
	assert_true(confirm.disabled, "one pick not enough")
	_press_option_named(create, "Merchant marine")
	assert_true(confirm.disabled, "two picks not enough")
	_press_option_named(create, "Clean")
	assert_false(confirm.disabled, "three picks enable confirm")
	assert_true(create.has_full_selection())
	assert_eq(create.selected_origin(), &"origin_periphery")
	assert_eq(create.selected_trade(), &"trade_merchant")
	assert_eq(create.selected_mark(), &"mark_clean")


func test_confirm_emits_bus_once_with_ids() -> void:
	var create: LifePathCreate = LifePathCreate.new()
	add_child_autofree(create)
	await get_tree().process_frame
	create.show_create()

	var origins: Array[StringName] = []
	var trades: Array[StringName] = []
	var marks: Array[StringName] = []
	var handler := func(origin_id: StringName, trade_id: StringName, mark_id: StringName) -> void:
		origins.append(origin_id)
		trades.append(trade_id)
		marks.append(mark_id)
	EventBus.on_life_path_confirmed.connect(handler)

	_press_option_named(create, "Core World")
	_press_option_named(create, "Ex-Navy")
	_press_option_named(create, "Cancelled charter")
	var confirm: Button = _find_button(create, BalanceSession.LIFE_PATH_CREATE_CONFIRM)
	confirm.pressed.emit()
	confirm.pressed.emit()

	assert_eq(origins.size(), 1, "one-shot confirm")
	assert_eq(origins[0], &"origin_core")
	assert_eq(trades[0], &"trade_navy")
	assert_eq(marks[0], &"mark_cancelled")

	EventBus.on_life_path_confirmed.disconnect(handler)


func test_cancel_emits_bus_once() -> void:
	var create: LifePathCreate = LifePathCreate.new()
	add_child_autofree(create)
	await get_tree().process_frame
	create.show_create()

	var cancels: Array[int] = []
	var handler := func() -> void: cancels.append(1)
	EventBus.on_life_path_cancel_requested.connect(handler)

	var cancel: Button = _find_button(create, BalanceSession.LIFE_PATH_CREATE_CANCEL)
	cancel.pressed.emit()
	cancel.pressed.emit()
	assert_eq(cancels.size(), 1, "one-shot cancel")

	EventBus.on_life_path_cancel_requested.disconnect(handler)


func test_teeth_summary_smuggler_vs_navy() -> void:
	var smuggler: LifePathOption = ContentLibrary.item(&"trade_smuggler") as LifePathOption
	var navy: LifePathOption = ContentLibrary.item(&"trade_navy") as LifePathOption
	assert_ne(smuggler, null)
	assert_ne(navy, null)
	var smuggler_text: String = LifePathCreate.format_teeth_summary(smuggler)
	var navy_text: String = LifePathCreate.format_teeth_summary(navy)
	assert_true(smuggler_text.contains("Drift") or smuggler_text.contains("+18"), smuggler_text)
	assert_true(smuggler_text.contains("Reach") or smuggler_text.contains("-15"), smuggler_text)
	assert_true(navy_text.contains("Reach") or navy_text.contains("+18"), navy_text)
	assert_true(navy_text.contains("Drift") or navy_text.contains("-12"), navy_text)
	assert_ne(smuggler_text, navy_text, "smuggler and navy teeth must differ")
	var clean: LifePathOption = ContentLibrary.item(&"mark_clean") as LifePathOption
	assert_eq(
		LifePathCreate.format_teeth_summary(clean), BalanceSession.LIFE_PATH_CREATE_TEETH_NONE
	)
	var debt: LifePathOption = ContentLibrary.item(&"mark_debt") as LifePathOption
	var debt_text: String = LifePathCreate.format_teeth_summary(debt)
	assert_true(debt_text.contains(str(BalanceEconomy.LOAN_PRINCIPAL)), debt_text)
	assert_true(debt_text.contains(str(BalanceEconomy.LOAN_REPAY_TOTAL)), debt_text)


func test_confirm_applies_teeth_via_career_start_pattern() -> void:
	# Mirror Main confirm path without loading Main.tscn.
	StandingService.reset_to_defaults()
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()

	var create: LifePathCreate = LifePathCreate.new()
	add_child_autofree(create)
	await get_tree().process_frame
	create.show_create()

	var applied: Array = []
	var handler := func(origin_id: StringName, trade_id: StringName, mark_id: StringName) -> void:
		CareerStart.apply(origin_id, trade_id, mark_id, wallet)
		applied.append([origin_id, trade_id, mark_id])
	EventBus.on_life_path_confirmed.connect(handler)

	_press_option_named(create, "Core World")
	_press_option_named(create, "Ex-Navy")
	_press_option_named(create, "Clean")
	_find_button(create, BalanceSession.LIFE_PATH_CREATE_CONFIRM).pressed.emit()

	assert_eq(applied.size(), 1)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH),
		BalanceStanding.PATH_ORIGIN_CORE_REACH + BalanceStanding.PATH_TRADE_NAVY_REACH,
		0.001
	)
	assert_eq(StandingService.last_delta_reason, BalanceStanding.REASON_LIFE_PATH)

	EventBus.on_life_path_confirmed.disconnect(handler)


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


func _option_buttons(root: Node) -> Array[Button]:
	var out: Array[Button] = []
	_collect_option_buttons(root, out)
	return out


func _collect_option_buttons(node: Node, out: Array[Button]) -> void:
	if node is Button:
		var btn: Button = node as Button
		if (
			btn.text != BalanceSession.LIFE_PATH_CREATE_CONFIRM
			and btn.text != BalanceSession.LIFE_PATH_CREATE_CANCEL
		):
			out.append(btn)
	for child: Node in node.get_children():
		_collect_option_buttons(child, out)


func _all_label_and_button_text(root: Node) -> PackedStringArray:
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


func _press_option_named(create: LifePathCreate, display_name: String) -> void:
	for btn: Button in _option_buttons(create):
		if btn.text.begins_with(display_name) or btn.text.contains(display_name + "\n"):
			btn.pressed.emit()
			return
	fail_test("option button not found for %s" % display_name)
