class_name StationLoanUi
extends RefCounted

## Pure emergency-loan Services helpers for StationMenu (E3.2).
##
## Implements: docs/BETA_E3_ECONOMY.md E3.2
## Keeps loan buttons, copy, and status text out of StationMenu line budget.


## Create Borrow / Repay buttons under parent. Returns [borrow_btn, repay_btn].
static func make_buttons(parent: Control, button_size: Vector2) -> Array[Button]:
	var borrow_btn: Button = Button.new()
	borrow_btn.text = (
		BalanceEconomy.STATION_BORROW_FORMAT
		% [BalanceEconomy.LOAN_PRINCIPAL, BalanceEconomy.LOAN_REPAY_TOTAL]
	)
	borrow_btn.custom_minimum_size = button_size
	borrow_btn.visible = false
	parent.add_child(borrow_btn)

	var repay_btn: Button = Button.new()
	repay_btn.text = BalanceEconomy.STATION_REPAY_LABEL
	repay_btn.custom_minimum_size = button_size
	repay_btn.visible = false
	parent.add_child(repay_btn)

	var out: Array[Button] = [borrow_btn, repay_btn]
	return out


## Refresh Borrow / Repay visibility and labels from wallet debt_state.
static func refresh_buttons(
	borrow_btn: Button, repay_btn: Button, wallet: Node, menu_visible: bool
) -> void:
	if borrow_btn == null or repay_btn == null:
		return
	if not menu_visible:
		borrow_btn.visible = false
		repay_btn.visible = false
		return
	var owed: int = debt_owed_from_wallet(wallet)
	var credits: int = 0
	if wallet != null and wallet.has_method(&"credits"):
		credits = _to_int(wallet.call(&"credits"))
	var can_borrow: bool = owed <= 0
	var has_debt: bool = owed > 0
	borrow_btn.visible = can_borrow
	borrow_btn.text = (
		BalanceEconomy.STATION_BORROW_FORMAT
		% [BalanceEconomy.LOAN_PRINCIPAL, BalanceEconomy.LOAN_REPAY_TOTAL]
	)
	borrow_btn.disabled = not can_borrow
	repay_btn.visible = has_debt
	if has_debt:
		repay_btn.text = BalanceEconomy.STATION_REPAY_FORMAT % owed
		repay_btn.disabled = credits <= 0
	else:
		repay_btn.text = BalanceEconomy.STATION_REPAY_LABEL
		repay_btn.disabled = true


static func debt_owed_from_wallet(wallet: Node) -> int:
	if wallet == null or not wallet.has_method(&"debt_state"):
		return 0
	var raw: Variant = wallet.call(&"debt_state")
	if typeof(raw) != TYPE_DICTIONARY:
		return 0
	var state: Dictionary = raw
	if state.has(&"owed"):
		return _to_int(state[&"owed"])
	if state.has("owed"):
		return _to_int(state["owed"])
	return 0


static func borrow_status_text(wallet: Node) -> String:
	if debt_owed_from_wallet(wallet) > 0:
		return (
			BalanceEconomy.STATION_BORROW_OK_FORMAT
			% [BalanceEconomy.LOAN_PRINCIPAL, BalanceEconomy.LOAN_REPAY_TOTAL]
		)
	return BalanceEconomy.STATION_BORROW_DENIED


static func repay_status_text(before_owed: int, wallet: Node) -> String:
	var owed: int = debt_owed_from_wallet(wallet)
	var paid: int = maxi(0, before_owed - owed)
	if paid <= 0:
		return BalanceEconomy.STATION_REPAY_BROKE
	if owed <= 0:
		return BalanceEconomy.STATION_REPAY_CLEARED
	return BalanceEconomy.STATION_REPAY_OK_FORMAT % [paid, owed]


## Refuel/repair labels, dock-fee line, and loan buttons (Services block).
static func refresh_core_services(
	refuel_btn: Button,
	repair_btn: Button,
	dock_fee_label: Label,
	borrow_btn: Button,
	repay_btn: Button,
	wallet: Node,
	station_id: StringName,
	menu_visible: bool
) -> void:
	if refuel_btn == null or repair_btn == null:
		return
	refuel_btn.visible = menu_visible
	repair_btn.visible = menu_visible
	_refresh_dock_fee_line(dock_fee_label, wallet, station_id, menu_visible)
	refresh_buttons(borrow_btn, repay_btn, wallet, menu_visible)
	if not menu_visible:
		refuel_btn.text = BalanceEconomy.STATION_REFUEL_LABEL
		repair_btn.text = BalanceEconomy.STATION_REPAIR_LABEL
		refuel_btn.disabled = false
		repair_btn.disabled = false
		return
	var tier: StringName = StationDockQueries.controller_tier(station_id)
	var service_mult: float = BalanceEconomy.service_cost_mult_for_tier(tier)
	if service_mult > BalanceEconomy.SERVICE_COST_MULT_DEFAULT:
		refuel_btn.text = BalanceEconomy.STATION_REFUEL_MARKUP_LABEL
	else:
		refuel_btn.text = BalanceEconomy.STATION_REFUEL_LABEL
	refuel_btn.disabled = false
	if BalanceEconomy.service_repair_denied_for_tier(tier):
		repair_btn.text = BalanceEconomy.STATION_REPAIR_DENIED_LABEL
		repair_btn.disabled = true
	else:
		repair_btn.text = BalanceEconomy.STATION_REPAIR_LABEL
		repair_btn.disabled = false


static func _refresh_dock_fee_line(
	dock_fee_label: Label, wallet: Node, station_id: StringName, menu_visible: bool
) -> void:
	if dock_fee_label == null:
		return
	if not menu_visible or String(station_id).is_empty():
		dock_fee_label.visible = false
		dock_fee_label.text = ""
		return
	if wallet == null or not wallet.has_method(&"dock_fee_for_system"):
		dock_fee_label.visible = false
		return
	var system_id: StringName = StationDockQueries.system_id(station_id)
	var fee: int = _to_int(wallet.call(&"dock_fee_for_system", system_id, station_id))
	var mult: float = BalanceEconomy.dock_fee_mult_for_tier(
		StationDockQueries.controller_tier(station_id)
	)
	if mult > BalanceEconomy.DOCK_FEE_STANDING_MULT_DEFAULT:
		dock_fee_label.text = BalanceEconomy.STATION_DOCK_FEE_SURCHARGE_FORMAT % fee
	else:
		dock_fee_label.text = BalanceEconomy.STATION_DOCK_FEE_FORMAT % fee
	dock_fee_label.visible = true


static func _to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var as_int: int = value
		return as_int
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = value
		return int(as_float)
	return 0
