class_name DraywarUiTheme
extends RefCounted

## Shared UI theme for Path C presentation floor — B1.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B1
##
## Builds a Theme at runtime from BalanceUi. Station menu and FlightHUD both
## pull from this so chrome reads as one game, not default gray.


## Fresh Theme resource for menus and HUD labels.
static func build() -> Theme:
	var theme: Theme = Theme.new()
	_apply_panel(theme)
	_apply_button(theme)
	_apply_label(theme)
	return theme


static func _apply_panel(theme: Theme) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BalanceUi.PANEL_BG
	style.border_color = BalanceUi.PANEL_BORDER
	style.set_border_width_all(BalanceUi.BORDER_WIDTH)
	style.set_corner_radius_all(BalanceUi.CORNER_RADIUS)
	style.set_content_margin_all(BalanceUi.CONTENT_MARGIN)
	theme.set_stylebox("panel", "PanelContainer", style)


static func _apply_button(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", _button_style(BalanceUi.BUTTON_BG))
	theme.set_stylebox("hover", "Button", _button_style(BalanceUi.BUTTON_HOVER))
	theme.set_stylebox("pressed", "Button", _button_style(BalanceUi.BUTTON_PRESSED))
	theme.set_stylebox("disabled", "Button", _button_style(BalanceUi.BUTTON_DISABLED_BG))
	theme.set_stylebox("focus", "Button", _button_style(BalanceUi.BUTTON_HOVER))
	theme.set_color("font_color", "Button", BalanceUi.FONT_COLOR)
	theme.set_color("font_hover_color", "Button", BalanceUi.FONT_COLOR)
	theme.set_color("font_pressed_color", "Button", BalanceUi.ACCENT)
	theme.set_color("font_disabled_color", "Button", BalanceUi.FONT_COLOR_MUTED)
	theme.set_font_size("font_size", "Button", BalanceFlight.HUD_FONT_SIZE)


static func _apply_label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", BalanceUi.FONT_COLOR)
	theme.set_font_size("font_size", "Label", BalanceFlight.HUD_FONT_SIZE)


static func _button_style(bg: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = BalanceUi.BUTTON_BORDER
	style.set_border_width_all(BalanceUi.BUTTON_BORDER_WIDTH)
	style.set_corner_radius_all(BalanceUi.CORNER_RADIUS)
	style.set_content_margin_all(BalanceUi.BUTTON_CONTENT_MARGIN)
	return style
