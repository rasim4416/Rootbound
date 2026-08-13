## Level Select — horizontal carousel UI with mouse-wheel sliding.
extends Control

const _CARD_STYLE_UNLOCKED := preload("res://resources/ui/level_card_unlocked.tres")
const _CARD_STYLE_LOCKED := preload("res://resources/ui/level_card_locked.tres")

@onready var _carousel: LevelSelectCarousel = %Carousel
@onready var _dots_row: HBoxContainer = %DotsRow
@onready var _hint_label: Label = %HintLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	if _carousel != null:
		_carousel.focused_index_changed.connect(_on_focus_changed)
	_rebuild()


func _rebuild() -> void:
	if _carousel == null:
		return
	var cards: Array[Control] = []
	var levels: LevelManager = GameManager.get_level_manager() if GameManager != null else null
	if levels == null or levels.available_levels.is_empty():
		cards.append(_create_empty_card())
	else:
		for entry: Dictionary in levels.get_level_select_entries():
			cards.append(_create_level_card(entry))
	_carousel.set_cards(cards)
	_rebuild_dots(cards.size())
	_update_hint(0, cards.size())


func _create_empty_card() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _CARD_STYLE_LOCKED)
	var label := Label.new()
	label.text = "No levels available."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _create_level_card(entry: Dictionary) -> Control:
	var level: LevelData = entry.get("level") as LevelData
	var unlocked: bool = bool(entry.get("unlocked", false))
	var best_wave: int = int(entry.get("best_wave", 0))
	var difficulty: int = level.difficulty if level != null else 1

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _CARD_STYLE_UNLOCKED if unlocked else _CARD_STYLE_LOCKED)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var badge := Label.new()
	badge.text = "LV %d" % difficulty
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0, 0.95))
	header.add_child(badge)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var status_chip := Label.new()
	if unlocked:
		status_chip.text = "UNLOCKED"
		status_chip.add_theme_color_override("font_color", Color(0.45, 0.95, 0.82, 1.0))
	else:
		status_chip.text = "LOCKED"
		status_chip.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45, 1.0))
	status_chip.add_theme_font_size_override("font_size", 12)
	header.add_child(status_chip)

	var title := Label.new()
	var display: String = str(entry.get("display_name", ""))
	title.text = display.to_upper() if display != "" else String(level.level_id).to_upper()
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0, 1.0))
	root.add_child(title)

	var subtitle := Label.new()
	if level != null and level.description != "":
		subtitle.text = level.description
	else:
		subtitle.text = "Defend the Nucleus against endless pathogen waves."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.68, 0.80, 0.88, 1.0))
	root.add_child(subtitle)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 20)
	root.add_child(stats)

	var wave_stat := _make_stat_block("BEST WAVE", str(best_wave) if unlocked else "—")
	stats.add_child(wave_stat)

	if not unlocked:
		var req_level: String = String(entry.get("unlock_required_level_id", "")).replace("_", " ").to_upper()
		var req_wave: int = int(entry.get("unlock_required_best_wave", 0))
		stats.add_child(_make_stat_block("REQUIRES", "Wave %d · %s" % [req_wave, req_level]))
	elif level != null:
		stats.add_child(_make_stat_block("PATHS", str(level.get_all_paths().size())))
		stats.add_child(_make_stat_block("THREAT", "×%.2f HP" % level.level_hp_multiplier))

	var start := Button.new()
	start.custom_minimum_size = Vector2(0, 44)
	start.text = "START MISSION" if unlocked else "LOCKED"
	start.disabled = not unlocked
	if unlocked and level != null:
		start.pressed.connect(_on_start_pressed.bind(level))
	root.add_child(start)

	return panel


func _make_stat_block(caption: String, value: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", Color(0.48, 0.62, 0.72, 1.0))
	box.add_child(cap)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 1.0))
	box.add_child(val)
	return box


func _rebuild_dots(count: int) -> void:
	if _dots_row == null:
		return
	for child: Node in _dots_row.get_children():
		child.queue_free()
	for i: int in range(count):
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.set_meta("dot_index", i)
		dot.add_theme_stylebox_override("panel", _make_dot_style(i == 0))
		_dots_row.add_child(dot)


func _make_dot_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	if active:
		style.bg_color = Color(0.45, 0.92, 0.95, 1.0)
	else:
		style.bg_color = Color(0.25, 0.35, 0.42, 0.75)
	return style


func _on_focus_changed(index: int) -> void:
	if _dots_row == null:
		return
	for i: int in range(_dots_row.get_child_count()):
		var dot := _dots_row.get_child(i) as PanelContainer
		if dot != null:
			dot.add_theme_stylebox_override("panel", _make_dot_style(i == index))
	_update_hint(index, _dots_row.get_child_count())


func _update_hint(index: int, total: int) -> void:
	if _hint_label == null:
		return
	if total <= 1:
		_hint_label.text = ""
	else:
		_hint_label.text = "Scroll · Level %d / %d" % [index + 1, total]


func _on_start_pressed(level: LevelData) -> void:
	if GameManager == null:
		push_error("LevelSelect: GameManager unavailable.")
		return
	GameManager.begin_level_run(level)
	SceneRouter.to_gameplay(get_tree())


func _on_back_pressed() -> void:
	SceneRouter.to_main_menu(get_tree())
