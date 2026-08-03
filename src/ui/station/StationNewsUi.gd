class_name StationNewsUi
extends RefCounted

## One-line sector news ticker for the station screen — Steam S2.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S2 + §5.5, docs/economy_sim.md §8
##
## Deliberately minimal: one headline from MarketService, pinned above the
## scrolling body so a captain who has just docked after a jump reads it before
## anything else and sees that the sector moved while they were flying. The full
## rumour layer is S3; this exists so the simulation is visible at all.
##
## MarketService is reached by bare autoload name — it carries no `class_name`,
## so this is a question asked of a service, not a static reference across a
## layer boundary.


## Build the ticker label and add it to `parent`. Hidden until there is news.
static func make_label(parent: Control) -> Label:
	var label: Label = Label.new()
	label.add_theme_color_override("font_color", BalanceUi.ACCENT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.text = ""
	label.visible = false
	parent.add_child(label)
	return label


## Re-read the current headline. Call on dock, on on_market_news and on
## on_market_ticked; the service only changes the line when it really changed.
static func refresh(label: Label, menu_visible: bool) -> void:
	if label == null:
		return
	if not menu_visible:
		label.text = ""
		label.visible = false
		return
	var line: String = MarketService.news_line()
	label.text = "" if line.is_empty() else BalanceEconomy.STATION_NEWS_PREFIX_FORMAT % line
	label.visible = not label.text.is_empty()
