## Shared "cell tech" styling for gameplay panels (Nanobot info, level-up choices).
##
## Keeps the Nanobot stats panel and the upgrade menu visually identical without
## duplicating StyleBoxFlat resources in every scene.
class_name BioPanelTheme
extends RefCounted

const BG: Color = Color(0.043, 0.075, 0.11, 0.96)
const BG_INNER: Color = Color(0.07, 0.115, 0.16, 0.92)
const BG_ROW: Color = Color(0.09, 0.14, 0.19, 0.85)
const BORDER: Color = Color(0.33, 0.66, 0.84, 0.85)
const BORDER_SOFT: Color = Color(0.28, 0.52, 0.66, 0.5)
const ACCENT: Color = Color(0.55, 0.9, 1.0)
const ACCENT_DIM: Color = Color(0.42, 0.68, 0.82)
const TEXT: Color = Color(0.88, 0.95, 1.0)
const TEXT_DIM: Color = Color(0.6, 0.73, 0.83)
const HIGHLIGHT: Color = Color(0.98, 0.84, 0.38)
const XP_FILL: Color = Color(0.42, 0.86, 0.96)
const XP_TRACK: Color = Color(0.11, 0.18, 0.24, 0.95)


static func panel(radius: int = 10, bg: Color = BG, border: Color = BORDER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	box.shadow_size = 8
	return box


## Card used for one upgrade choice / one grouped section.
static func card(accent: Color = BORDER_SOFT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BG_INNER
	box.border_color = accent
	box.set_border_width_all(1)
	box.border_width_left = 3
	box.set_corner_radius_all(6)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


static func badge(bg: Color = BG_ROW, border: Color = BORDER_SOFT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	return box


static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 5.0
	return box


## Applies normal / hover / pressed / disabled styling to a button.
static func style_button(button: Button, primary: bool = false) -> void:
	if button == null:
		return
	var base: Color = Color(0.13, 0.28, 0.36, 0.95) if primary else Color(0.1, 0.16, 0.22, 0.9)
	var edge: Color = ACCENT if primary else BORDER_SOFT
	button.add_theme_stylebox_override("normal", button_style(base, edge))
	button.add_theme_stylebox_override(
		"hover", button_style(base.lightened(0.12), ACCENT)
	)
	button.add_theme_stylebox_override(
		"pressed", button_style(base.darkened(0.15), ACCENT)
	)
	button.add_theme_stylebox_override(
		"disabled", button_style(Color(0.06, 0.08, 0.11, 0.75), Color(0.2, 0.26, 0.31, 0.45))
	)
	button.add_theme_color_override("font_color", TEXT if primary else TEXT_DIM)
	button.add_theme_color_override("font_hover_color", ACCENT)
	button.add_theme_color_override("font_pressed_color", ACCENT)
	button.add_theme_color_override("font_disabled_color", Color(0.33, 0.4, 0.46))
	button.focus_mode = Control.FOCUS_NONE


## Marks a mode/tab button as the active one.
static func style_toggle(button: Button, active: bool, enabled: bool) -> void:
	if button == null:
		return
	style_button(button, active)
	button.disabled = not enabled
	if active:
		button.add_theme_color_override("font_color", Color(0.98, 1.0, 1.0))


static func style_progress(bar: ProgressBar, fill: Color = XP_FILL) -> void:
	if bar == null:
		return
	var track := StyleBoxFlat.new()
	track.bg_color = XP_TRACK
	track.border_color = BORDER_SOFT
	track.set_border_width_all(1)
	track.set_corner_radius_all(4)
	var progress := StyleBoxFlat.new()
	progress.bg_color = fill
	progress.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", progress)


static func style_separator(separator: HSeparator) -> void:
	if separator == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = BORDER_SOFT
	box.content_margin_top = 1.0
	box.content_margin_bottom = 1.0
	separator.add_theme_stylebox_override("separator", box)
