extends GutTest

## REPAIR-19: Captain sheet fits shipping viewport; standing rows keep a11y.
##
## Audit PT-9 (baseline ee17eab5): at 1152×648 the Standing header, all six
## faction rows, and Close sat below the window. Accessibility content (color +
## glyph + tier word) was already correct — layout only. Brief requires:
##   (a)+(b) test_captain_sheet_fits_shipping_viewport
##   (c)     test_captain_sheet_rows_have_tier_color_glyph_and_word
##
## Out of scope: StandingService, save schema, EventBus signals, tier content,
## docs/S10_RC_PLAYTEST.md.

const SHIP_W: int = 1152
const SHIP_H: int = 648


func after_each() -> void:
	StandingService.reset_to_defaults()


func test_captain_sheet_fits_shipping_viewport() -> void:
	var sheet: CaptainSheet = CaptainSheet.new()
	add_child_autofree(sheet)
	await get_tree().process_frame

	var win: Window = sheet.get_window()
	assert_ne(win, null, "sheet must be under a Window")
	var prev_size: Vector2i = win.size
	win.size = Vector2i(SHIP_W, SHIP_H)
	await get_tree().process_frame

	EventBus.on_captain_sheet_open_requested.emit()
	# Fit + standing rows + container layout settle.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var vp_h: float = float(sheet.get_viewport().get_visible_rect().size.y)
	assert_gt(vp_h, 0.0, "viewport height available")

	# (a) Close button bottom edge on-screen at shipping size.
	var close_btn: Button = _find_button_with_text(sheet, BalanceSession.SHEET_CLOSE)
	assert_ne(close_btn, null, "Close button exists")
	var close_rect: Rect2 = close_btn.get_global_rect()
	assert_lte(
		close_rect.end.y,
		vp_h,
		(
			"Close bottom must be on-screen at %dx%d (was y=%.1f vp=%.1f)"
			% [SHIP_W, SHIP_H, close_rect.end.y, vp_h]
		)
	)
	assert_gte(close_rect.position.y, 0.0, "Close top must be on-screen")

	# (b) Every standing row bottom edge on-screen at shipping size.
	var standing_box: VBoxContainer = _standing_box(sheet)
	assert_ne(standing_box, null, "_standing_box must exist")
	var row_count: int = 0
	for child: Node in standing_box.get_children():
		if not (child is Label):
			continue
		var row: Label = child as Label
		row_count += 1
		var row_rect: Rect2 = row.get_global_rect()
		assert_lte(
			row_rect.end.y,
			vp_h,
			(
				"standing row '%s' bottom must be on-screen at %dx%d (was y=%.1f vp=%.1f)"
				% [row.text, SHIP_W, SHIP_H, row_rect.end.y, vp_h]
			)
		)
		assert_gte(row_rect.position.y, 0.0, "standing row top on-screen: %s" % row.text)
	assert_eq(
		row_count,
		BalanceSession.SHEET_MAX_STANDING_LINES,
		"expected %d standing rows" % BalanceSession.SHEET_MAX_STANDING_LINES
	)

	win.size = prev_size


## (c) Green on arrival — guards signed S10 a11y on the captain-sheet half.
## Layout fix must not drop color / glyph / tier word from any standing row.
func test_captain_sheet_rows_have_tier_color_glyph_and_word() -> void:
	var sheet: CaptainSheet = CaptainSheet.new()
	add_child_autofree(sheet)
	await get_tree().process_frame

	EventBus.on_captain_sheet_open_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var standing_box: VBoxContainer = _standing_box(sheet)
	assert_ne(standing_box, null, "_standing_box must exist")

	var entity_ids: Array[StringName] = ContentLibrary.ids_in(
		BalanceSession.ENTITY_CONTENT_CATEGORY
	)
	assert_gt(entity_ids.size(), 0, "entities content must load")

	# Rebuild the same ranking the sheet uses so each row maps to a tier.
	var ranked: Array[Dictionary] = []
	for entity_id: StringName in entity_ids:
		var standing: float = StandingService.get_entity_standing(entity_id)
		var item: ContentItem = null
		if ContentLibrary.has_item(entity_id):
			item = ContentLibrary.item(entity_id)
		var display: String = String(entity_id)
		if item != null and not item.display_name.is_empty():
			display = item.display_name
		(
			ranked
			. append(
				{
					&"id": entity_id,
					&"name": display,
					&"standing": standing,
					&"abs": absf(standing),
				}
			)
		)
	ranked.sort_custom(_standing_sort)

	var expected_count: int = mini(BalanceSession.SHEET_MAX_STANDING_LINES, ranked.size())
	var labels: Array[Label] = []
	for child: Node in standing_box.get_children():
		if child is Label:
			labels.append(child as Label)
	assert_eq(labels.size(), expected_count, "row count matches max standing lines")

	for i: int in range(expected_count):
		var row_data: Dictionary = ranked[i]
		var standing: float = row_data[&"standing"]
		var tier: StringName = StandingService.tier_for(standing)
		var glyph: String = BalanceStanding.tier_glyph(tier)
		var tier_word: String = StandingService.tier_display_name(tier)
		var expected_color: Color = BalanceStanding.tier_color(tier)
		var label: Label = labels[i]
		assert_eq(
			label.get_theme_color("font_color"),
			expected_color,
			"row %d font_color must be tier_color(%s)" % [i, tier]
		)
		assert_true(
			label.text.contains(glyph),
			"row %d must carry tier glyph '%s'; got: %s" % [i, glyph, label.text]
		)
		assert_true(
			label.text.contains(tier_word),
			"row %d must carry tier word '%s'; got: %s" % [i, tier_word, label.text]
		)
		assert_true(
			label.text.contains(str(row_data[&"name"])),
			"row %d must name entity; got: %s" % [i, label.text]
		)


func _standing_box(sheet: CaptainSheet) -> VBoxContainer:
	var raw: Variant = sheet.get("_standing_box")
	if raw is VBoxContainer:
		var box: VBoxContainer = raw
		return box
	return null


func _standing_sort(a: Dictionary, b: Dictionary) -> bool:
	var abs_a: float = a[&"abs"]
	var abs_b: float = b[&"abs"]
	if not is_equal_approx(abs_a, abs_b):
		return abs_a > abs_b
	return str(a[&"name"]) < str(b[&"name"])


func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button:
		var button: Button = node
		if button.text == text:
			return button
	for child: Node in node.get_children():
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null
