class_name StationHoldingUi
extends RefCounted

## Holding section helpers for StationMenu — Steam S8.
##
## Shows milestone progress, price, purchase, claimed/ignited status at
## candidate or claimed docks. Buttons emit EventBus only.


## Connect Holding bus signals to a zero-arg refresh callable.
static func connect_refresh(refresh: Callable) -> void:
	EventBus.on_holding_claimed.connect(refresh.unbind(BalanceHolding.BUS_ARGS_CLAIMED))
	EventBus.on_holding_ignited.connect(refresh.unbind(BalanceHolding.BUS_ARGS_IGNITED))
	EventBus.on_campaign_flag_set.connect(refresh.unbind(BalanceCampaign.BUS_ARGS_FLAG_SET))
	EventBus.on_credits_changed.connect(refresh.unbind(BalanceHolding.BUS_ARGS_CREDITS_CHANGED))
	EventBus.on_debt_changed.connect(refresh.unbind(BalanceHolding.BUS_ARGS_DEBT_CHANGED))
	EventBus.on_spine_completed.connect(refresh.unbind(BalanceCampaign.BUS_ARGS_SPINE_COMPLETED))


## Disconnect refresh callables from connect_refresh.
static func disconnect_refresh(refresh: Callable) -> void:
	_safe_disconnect(EventBus.on_holding_claimed, refresh.unbind(BalanceHolding.BUS_ARGS_CLAIMED))
	_safe_disconnect(EventBus.on_holding_ignited, refresh.unbind(BalanceHolding.BUS_ARGS_IGNITED))
	_safe_disconnect(
		EventBus.on_campaign_flag_set, refresh.unbind(BalanceCampaign.BUS_ARGS_FLAG_SET)
	)
	_safe_disconnect(
		EventBus.on_credits_changed, refresh.unbind(BalanceHolding.BUS_ARGS_CREDITS_CHANGED)
	)
	_safe_disconnect(EventBus.on_debt_changed, refresh.unbind(BalanceHolding.BUS_ARGS_DEBT_CHANGED))
	_safe_disconnect(
		EventBus.on_spine_completed, refresh.unbind(BalanceCampaign.BUS_ARGS_SPINE_COMPLETED)
	)


static func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


## Section header + empty box under `layout`. Returns the holding VBox.
static func make_box(layout: VBoxContainer) -> VBoxContainer:
	var header: Label = Label.new()
	header.text = BalanceHolding.STATION_SECTION_HOLDING
	header.add_theme_color_override("font_color", BalanceUi.TITLE_COLOR)
	layout.add_child(header)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(box)
	return box


## Resolve campaign from the scene tree and refresh.
static func refresh_for_tree(
	box: VBoxContainer, tree: SceneTree, station_id: StringName, menu_visible: bool
) -> void:
	var campaign: Node = null
	if tree != null:
		campaign = tree.get_first_node_in_group(BalanceCampaign.GROUP_CAMPAIGN_SERVICE)
	refresh_box(box, campaign, station_id, menu_visible)


## Clear and rebuild Holding rows for the docked station.
static func refresh_box(
	box: VBoxContainer, campaign: Node, station_id: StringName, menu_visible: bool
) -> void:
	if box == null:
		return
	_clear_children(box)
	if not menu_visible or campaign == null or String(station_id).is_empty():
		return

	var claimed: bool = false
	var claimed_id: StringName = &""
	var ignited: bool = false
	if campaign.has_method(&"is_holding_claimed"):
		claimed = campaign.call(&"is_holding_claimed") == true
	if campaign.has_method(&"claimed_station_id"):
		claimed_id = _as_name(campaign.call(&"claimed_station_id"))
	if campaign.has_method(&"is_holding_ignited"):
		ignited = campaign.call(&"is_holding_ignited") == true

	var is_candidate: bool = false
	if campaign.has_method(&"is_candidate_station"):
		is_candidate = campaign.call(&"is_candidate_station", station_id) == true
	var is_claimed_here: bool = claimed and claimed_id == station_id
	if not is_candidate and not is_claimed_here:
		return

	if is_claimed_here:
		_add_label(box, BalanceHolding.STATION_HOLDING_CLAIMED_LINE, false)
		if ignited:
			var celebration: String = ""
			if campaign.has_method(&"celebration_line"):
				celebration = str(campaign.call(&"celebration_line"))
			if celebration.is_empty():
				celebration = BalanceHolding.STATION_HOLDING_IGNITED_CELEBRATION
			_add_label(box, celebration, false)
		return

	if claimed and claimed_id != station_id:
		_add_label(box, BalanceHolding.STATION_HOLDING_ALREADY_ELSEWHERE, true)
		return

	# Unclaimed candidate dock: milestones + price + purchase.
	var milestones: int = 0
	if campaign.has_method(&"milestone_count"):
		milestones = _as_int(campaign.call(&"milestone_count"))
	var price: int = BalanceHolding.price_for_milestone_count(milestones)
	if campaign.has_method(&"effective_holding_price"):
		price = _as_int(campaign.call(&"effective_holding_price"))
	var discount: int = BalanceHolding.MILESTONE_DISCOUNT * milestones

	_add_label(
		box,
		(
			BalanceHolding.STATION_HOLDING_MILESTONES_FORMAT
			% [milestones, BalanceHolding.MILESTONE_COUNT]
		),
		true
	)
	_add_label(
		box,
		BalanceHolding.STATION_HOLDING_PRICE_FORMAT % [price, BalanceHolding.BASE_PRICE, discount],
		true
	)

	var debt_clear: bool = true
	if campaign.has_method(&"can_purchase_holding"):
		# Prefer explicit debt message when purchase would fail for debt.
		pass
	var wallet_tree: SceneTree = box.get_tree() if box.is_inside_tree() else null
	if wallet_tree != null:
		var wallet: Node = wallet_tree.get_first_node_in_group(&"wallet_service")
		if wallet != null and wallet.has_method(&"debt_state"):
			var state_raw: Variant = wallet.call(&"debt_state")
			if typeof(state_raw) == TYPE_DICTIONARY:
				var state: Dictionary = state_raw
				debt_clear = _as_int(state.get(&"owed", 0)) == 0
	if not debt_clear:
		_add_label(box, BalanceHolding.STATION_HOLDING_DEBT_BLOCKED, true)
	elif milestones < BalanceHolding.MILESTONE_COUNT:
		_add_label(box, BalanceHolding.STATION_HOLDING_NEED_MILESTONES, true)

	var can_buy: bool = false
	if campaign.has_method(&"can_purchase_holding"):
		can_buy = campaign.call(&"can_purchase_holding", station_id) == true
	if not can_buy and debt_clear and milestones >= BalanceHolding.MILESTONE_COUNT:
		_add_label(box, BalanceHolding.STATION_HOLDING_NEED_CREDITS, true)

	var btn: Button = Button.new()
	btn.text = BalanceHolding.STATION_HOLDING_PURCHASE_FORMAT % price
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = not can_buy
	var captured: StringName = station_id
	btn.pressed.connect(func() -> void: EventBus.on_holding_purchase_requested.emit(captured))
	box.add_child(btn)


static func _add_label(box: VBoxContainer, text: String, muted: bool) -> void:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if muted:
		label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR_MUTED)
	else:
		label.add_theme_color_override("font_color", BalanceUi.FONT_COLOR)
	label.text = text
	box.add_child(label)


static func _clear_children(box: VBoxContainer) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


static func _as_name(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		var as_name: StringName = value
		return as_name
	if typeof(value) == TYPE_STRING:
		var as_text: String = value
		return StringName(as_text)
	return StringName(str(value))


static func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float_val: float = value
		return int(as_float_val)
	return 0
