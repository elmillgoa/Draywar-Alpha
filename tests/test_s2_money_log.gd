extends GutTest

## MoneyLog CSV telemetry — Steam S2.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S2
##
## MoneyLog is added with plain add_child() (not add_child_autofree) and torn
## down by hand with remove_child()/free() right after each test's last
## flush(). GUT frees add_child_autofree() nodes only after after_each() runs
## (addons/gut/gut.gd), and MoneyLog holds an open FileAccess handle — on
## Windows a still-open handle can block the next test's before_each() from
## deleting the fixture. Closing it explicitly, before this file is read
## back, avoids that lock race entirely.

const UPKEEP_SECONDS: float = 5.0
const FUEL_BURN_SECONDS: float = 50.0
const DAMAGE_AMOUNT: float = 30.0
const SYSTEM_ALPHA: StringName = &"system_alpha"


func before_each() -> void:
	StandingService.reset_to_defaults()
	_delete_log_files()


func after_each() -> void:
	StandingService.reset_to_defaults()
	_delete_log_files()


func _delete_log_files() -> void:
	if FileAccess.file_exists(BalanceTelemetry.LOG_PATH):
		DirAccess.remove_absolute(BalanceTelemetry.LOG_PATH)
	if FileAccess.file_exists(BalanceTelemetry.ROTATED_PATH):
		DirAccess.remove_absolute(BalanceTelemetry.ROTATED_PATH)


## New MoneyLog, added under the test node and ready for one process frame.
func _new_money_log() -> MoneyLog:
	var money_log: MoneyLog = MoneyLog.new()
	add_child(money_log)
	return money_log


## Flushes, then removes and frees the node so its file handle is closed
## before the test reads the file back (see the header note above).
func _close_money_log(money_log: MoneyLog) -> void:
	money_log.flush()
	remove_child(money_log)
	money_log.free()


## Every data row (header excluded), parsed with Godot's own CSV reader so
## the test proves the writer and a real CSV parser agree on the escaping.
func _data_rows(path: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	var length: int = file.get_length()
	var first: bool = true
	while file.get_position() < length:
		var line: PackedStringArray = file.get_csv_line()
		if first:
			first = false
			continue
		rows.append(line)
	file.close()
	return rows


func test_upkeep_drain_writes_one_row_with_reason_delta_and_balance() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	var money_log: MoneyLog = _new_money_log()
	await get_tree().process_frame
	wallet.reset()

	var paid: int = wallet.tick_upkeep(UPKEEP_SECONDS, false)
	assert_gt(paid, 0, "balance upkeep rate must actually drain credits over 5s")
	var credits_after: int = wallet.credits()
	_close_money_log(money_log)

	var rows: Array[PackedStringArray] = _data_rows(BalanceTelemetry.LOG_PATH)
	assert_eq(rows.size(), 1)
	var row: PackedStringArray = rows[0]
	assert_eq(row.size(), BalanceTelemetry.CSV_COLUMN_COUNT)
	assert_eq(row[1], String(BalanceTelemetry.REASON_UPKEEP))
	assert_eq(int(row[2]), -paid)
	assert_eq(int(row[3]), credits_after)


func test_dock_fee_row_has_negative_delta() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	var money_log: MoneyLog = _new_money_log()
	await get_tree().process_frame
	wallet.reset()
	wallet.set_credits(1000)

	var paid: int = wallet.charge_dock_fee(SYSTEM_ALPHA)
	assert_gt(paid, 0, "system_alpha must charge a real dock fee for this to be meaningful")
	var credits_after: int = wallet.credits()
	_close_money_log(money_log)

	var rows: Array[PackedStringArray] = _data_rows(BalanceTelemetry.LOG_PATH)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0][1], String(BalanceTelemetry.REASON_DOCK_FEE))
	assert_eq(int(rows[0][2]), -paid)
	assert_eq(int(rows[0][3]), credits_after)


func test_refuel_row_has_negative_delta() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	var money_log: MoneyLog = _new_money_log()
	await get_tree().process_frame
	wallet.reset()
	wallet.burn_fuel(FUEL_BURN_SECONDS, 1.0, false)

	var credits_before: int = wallet.credits()
	var added: float = wallet.refuel_chunk()
	assert_gt(added, 0.0, "burned fuel must leave room to refuel")
	var spent: int = credits_before - wallet.credits()
	assert_gt(spent, 0)
	var credits_after: int = wallet.credits()
	_close_money_log(money_log)

	var rows: Array[PackedStringArray] = _data_rows(BalanceTelemetry.LOG_PATH)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0][1], String(BalanceTelemetry.REASON_REFUEL))
	assert_eq(int(rows[0][2]), -spent)
	assert_eq(int(rows[0][3]), credits_after)


func test_repair_row_has_negative_delta() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	var money_log: MoneyLog = _new_money_log()
	await get_tree().process_frame
	wallet.reset()
	wallet.apply_damage(DAMAGE_AMOUNT)

	var credits_before: int = wallet.credits()
	assert_true(wallet.repair_full())
	var spent: int = credits_before - wallet.credits()
	assert_gt(spent, 0)
	_close_money_log(money_log)

	var rows: Array[PackedStringArray] = _data_rows(BalanceTelemetry.LOG_PATH)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0][1], String(BalanceTelemetry.REASON_REPAIR))
	assert_eq(int(rows[0][2]), -spent)


func test_loan_borrow_row_has_positive_delta() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	var money_log: MoneyLog = _new_money_log()
	await get_tree().process_frame
	wallet.reset()

	var received: int = wallet.borrow()
	assert_eq(received, BalanceEconomy.LOAN_PRINCIPAL)
	var credits_after: int = wallet.credits()
	_close_money_log(money_log)

	var rows: Array[PackedStringArray] = _data_rows(BalanceTelemetry.LOG_PATH)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0][1], String(BalanceEconomy.REASON_LOAN_BORROW))
	assert_eq(int(rows[0][2]), received)
	assert_eq(int(rows[0][3]), credits_after)


func test_job_pay_with_open_debt_produces_garnish_and_net_rows() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	var money_log: MoneyLog = _new_money_log()
	await get_tree().process_frame
	wallet.reset()
	assert_eq(wallet.borrow(), BalanceEconomy.LOAN_PRINCIPAL)
	var count_before: int = money_log.row_count()

	var gross: int = BalanceEconomy.MISSION_PAY_DEFAULT
	var expected_garnish: int = int(floorf(float(gross) * BalanceEconomy.GARNISH_RATE))
	var net: int = wallet.apply_job_pay_with_garnish(gross)
	assert_gt(expected_garnish, 0, "balance garnish must be nonzero for this scenario")
	assert_eq(net, gross - expected_garnish)

	assert_eq(money_log.row_count() - count_before, 2, "garnish must log two rows, not one")
	_close_money_log(money_log)

	var rows: Array[PackedStringArray] = _data_rows(BalanceTelemetry.LOG_PATH)
	assert_eq(rows.size(), 3, "borrow row + garnish row + net pay row")
	var garnish_row: PackedStringArray = rows[1]
	var pay_row: PackedStringArray = rows[2]
	assert_eq(garnish_row[1], String(BalanceEconomy.REASON_LOAN_GARNISH))
	assert_eq(int(garnish_row[2]), -expected_garnish)
	assert_eq(pay_row[1], String(BalanceTelemetry.REASON_JOB_PAY))
	assert_eq(int(pay_row[2]), net)


func test_comma_and_quote_field_escapes_and_parses_back_cleanly() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	var money_log: MoneyLog = _new_money_log()
	await get_tree().process_frame
	wallet.reset()
	wallet.set_credits(1000)

	var messy_station: StringName = StringName('Alpha "Prime", Station')
	wallet.charge_dock_fee(SYSTEM_ALPHA, messy_station)
	_close_money_log(money_log)

	var raw_text: String = FileAccess.get_file_as_string(BalanceTelemetry.LOG_PATH)
	assert_true(raw_text.contains('""'), "an embedded quote must be doubled")

	var rows: Array[PackedStringArray] = _data_rows(BalanceTelemetry.LOG_PATH)
	assert_eq(rows.size(), 1)
	var row: PackedStringArray = rows[0]
	assert_eq(row.size(), BalanceTelemetry.CSV_COLUMN_COUNT, "comma must not split the row")
	assert_eq(row[7], String(messy_station), "parsed field must round-trip unescaped")


func test_header_written_once_when_log_is_reopened() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	wallet.reset()

	var log_a: MoneyLog = _new_money_log()
	await get_tree().process_frame
	wallet.tick_upkeep(UPKEEP_SECONDS, false)
	_close_money_log(log_a)

	var log_b: MoneyLog = _new_money_log()
	await get_tree().process_frame
	wallet.tick_upkeep(UPKEEP_SECONDS, false)
	_close_money_log(log_b)

	var text: String = FileAccess.get_file_as_string(BalanceTelemetry.LOG_PATH)
	var header_hits: int = 0
	for line: String in text.split("\n", false):
		if line == BalanceTelemetry.CSV_HEADER:
			header_hits += 1
	assert_eq(header_hits, 1, "header must not repeat across a reopen")

	var rows: Array[PackedStringArray] = _data_rows(BalanceTelemetry.LOG_PATH)
	assert_eq(rows.size(), 2)


func test_set_enabled_false_stops_new_rows() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	var money_log: MoneyLog = _new_money_log()
	await get_tree().process_frame
	wallet.reset()

	wallet.tick_upkeep(UPKEEP_SECONDS, false)
	var count_after_first: int = money_log.row_count()
	assert_eq(count_after_first, 1)

	money_log.set_enabled(false)
	assert_false(money_log.is_enabled())
	wallet.tick_upkeep(UPKEEP_SECONDS, false)
	assert_eq(money_log.row_count(), count_after_first, "disabled log must not count new rows")
	_close_money_log(money_log)

	var rows: Array[PackedStringArray] = _data_rows(BalanceTelemetry.LOG_PATH)
	assert_eq(rows.size(), 1, "disabled log must not write new rows either")


func test_rows_parse_back_in_recorded_order() -> void:
	var wallet: WalletService = WalletService.new()
	add_child_autofree(wallet)
	var money_log: MoneyLog = _new_money_log()
	await get_tree().process_frame
	wallet.reset()
	wallet.set_credits(1000)

	wallet.charge_dock_fee(SYSTEM_ALPHA)
	wallet.burn_fuel(FUEL_BURN_SECONDS, 1.0, false)
	wallet.refuel_chunk()
	wallet.borrow()
	_close_money_log(money_log)

	var rows: Array[PackedStringArray] = _data_rows(BalanceTelemetry.LOG_PATH)
	assert_eq(rows.size(), 3)
	assert_eq(rows[0][1], String(BalanceTelemetry.REASON_DOCK_FEE))
	assert_eq(rows[1][1], String(BalanceTelemetry.REASON_REFUEL))
	assert_eq(rows[2][1], String(BalanceEconomy.REASON_LOAN_BORROW))
