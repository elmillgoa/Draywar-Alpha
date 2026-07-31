class_name BalanceUi
extends RefCounted

## Shared UI chrome colours and theme layout — Path C B1.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B1
##
## Station menu and FlightHUD both read these so presentation stays one look.

const PANEL_BG: Color = Color(0.08, 0.10, 0.14, 0.92)
const PANEL_BORDER: Color = Color(0.35, 0.55, 0.72, 0.85)
const BUTTON_BG: Color = Color(0.16, 0.22, 0.30, 1.0)
const BUTTON_HOVER: Color = Color(0.22, 0.32, 0.42, 1.0)
const BUTTON_PRESSED: Color = Color(0.12, 0.18, 0.24, 1.0)
const BUTTON_BORDER: Color = Color(0.45, 0.65, 0.80, 0.9)
const BUTTON_DISABLED_BG: Color = Color(0.12, 0.12, 0.14, 0.7)
const FONT_COLOR: Color = Color(0.92, 0.94, 0.96, 1.0)
const FONT_COLOR_MUTED: Color = Color(0.72, 0.78, 0.86, 1.0)
const TITLE_COLOR: Color = Color(0.95, 0.88, 0.55, 1.0)
const ACCENT: Color = Color(0.35, 0.78, 0.95, 1.0)
const CORNER_RADIUS: int = 6
const BORDER_WIDTH: int = 2
const BUTTON_BORDER_WIDTH: int = 1
const CONTENT_MARGIN: int = 12
const BUTTON_CONTENT_MARGIN: int = 8
