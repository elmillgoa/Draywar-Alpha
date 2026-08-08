class_name BalanceUi
extends RefCounted

## Shared UI chrome colours and theme layout — Path C B1.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B1
##
## Station menu and FlightHUD both read these so presentation stays one look.

## S10 chrome pass — deeper navy panels, sharper cyan edge, gold titles.
const PANEL_BG: Color = Color(0.06, 0.09, 0.14, 0.94)
const PANEL_BORDER: Color = Color(0.32, 0.58, 0.78, 0.9)
const BUTTON_BG: Color = Color(0.14, 0.20, 0.30, 1.0)
const BUTTON_HOVER: Color = Color(0.20, 0.32, 0.44, 1.0)
const BUTTON_PRESSED: Color = Color(0.10, 0.16, 0.24, 1.0)
const BUTTON_BORDER: Color = Color(0.42, 0.68, 0.88, 0.95)
const BUTTON_DISABLED_BG: Color = Color(0.10, 0.11, 0.14, 0.75)
const FONT_COLOR: Color = Color(0.94, 0.96, 0.98, 1.0)
const FONT_COLOR_MUTED: Color = Color(0.70, 0.78, 0.88, 1.0)
## Credits / funds warning (E3.1 low-funds HUD).
const FONT_COLOR_WARNING: Color = Color(0.96, 0.74, 0.30, 1.0)
## Journal row for a campaign ending that can never be reached again (Job 6
## phase 2). Its own colour, because grey "Locked" reads as "not yet".
const FONT_COLOR_CLOSED: Color = Color(0.94, 0.44, 0.40, 1.0)
const TITLE_COLOR: Color = Color(0.98, 0.90, 0.52, 1.0)
const ACCENT: Color = Color(0.38, 0.82, 0.98, 1.0)
const CORNER_RADIUS: int = 8
const BORDER_WIDTH: int = 2
const BUTTON_BORDER_WIDTH: int = 1
const CONTENT_MARGIN: int = 14
const BUTTON_CONTENT_MARGIN: int = 10

## Brief full-screen dock / undock flash (FlightHUD ColorRect — E1.1).
const DOCK_FADE_COLOR: Color = Color(0.12, 0.22, 0.35, 1.0)
const UNDOCK_FADE_COLOR: Color = Color(0.18, 0.16, 0.10, 1.0)
const DOCK_FADE_PEAK_ALPHA: float = 0.55
const DOCK_FADE_DURATION: float = 0.28
