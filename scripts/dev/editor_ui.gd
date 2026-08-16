## Single floating Dev Level Editor panel (tools + library + inspector).
class_name EditorUI
extends CanvasLayer

signal tool_selected(tool_id: StringName)
signal playtest_pressed
signal save_pressed
signal load_pressed
signal new_pressed
signal undo_pressed
signal redo_pressed
signal path_add_pressed
signal path_delete_pressed
signal path_reverse_pressed
signal path_duplicate_pressed
signal wave_add_pressed
signal wave_duplicate_pressed
signal wave_delete_pressed
signal wave_test_pressed
signal path_index_selected(index: int)
signal wave_index_selected(index: int)
signal inspector_changed()
signal debug_toggled(flag: StringName, enabled: bool)

enum ToolId {
	SELECT,
	PATH,
	SPAWN,
	TURRET,
	OBSTACLE,
	OBJECT,
	WAVE,
	ERASER,
}

const _PANEL_POS := Vector2(16, 56)
const _PANEL_SIZE := Vector2(360, 560)

const _COL_BG := Color(0.06, 0.08, 0.12, 0.97)
const _COL_HEADER := Color(0.09, 0.12, 0.18, 1.0)
const _COL_BORDER := Color(0.32, 0.62, 0.82, 0.9)
const _COL_ACCENT := Color(0.5, 0.85, 1.0, 1.0)
const _COL_OK := Color(0.55, 0.92, 0.7, 1.0)
const _COL_ERR := Color(1.0, 0.55, 0.48, 1.0)

## Maps OptionButton index → ToolId / signal name
const _TOOL_ENTRIES: Array[Dictionary] = [
	{"id": ToolId.SELECT, "name": "select", "label": "Select"},
	{"id": ToolId.PATH, "name": "path", "label": "Path paint"},
	{"id": ToolId.SPAWN, "name": "spawn", "label": "Set spawn"},
	{"id": ToolId.TURRET, "name": "turret", "label": "Turret slot"},
	{"id": ToolId.OBSTACLE, "name": "obstacle", "label": "Obstacle"},
	{"id": ToolId.OBJECT, "name": "object", "label": "Object"},
	{"id": ToolId.WAVE, "name": "wave", "label": "Wave pick"},
	{"id": ToolId.ERASER, "name": "eraser", "label": "Eraser"},
]

var _root: Control
var _panel: PanelContainer
var _header: PanelContainer
var _title: Label
var _valid_badge: Label
var _body: VBoxContainer
var _status: Label
var _tool_option: OptionButton
var _path_list: ItemList
var _wave_list: ItemList
var _inspector_box: VBoxContainer
var _btn_collapse: Button
var _collapsed: bool = false
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _map: EditorMapData
var _active_path: int = 0
var _active_wave: int = 0
var _selected_kind: String = ""
var _selected_slot: EditorTurretSlot = null
var _inspector_fields: Dictionary = {}
var _committing: bool = false
var _rebuild_pending: bool = false
var _skip_inspector_rebuild: bool = false
var _current_tool: int = ToolId.PATH


func _ready() -> void:
	layer = 90
	_build()
	visible = false
	set_process(true)


func _process(_delta: float) -> void:
	if _dragging and _panel != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var target: Vector2 = get_viewport().get_mouse_position() - _drag_offset
		var vp: Vector2 = get_viewport().get_visible_rect().size
		target.x = clampf(target.x, 0.0, maxf(vp.x - _panel.size.x, 0.0))
		target.y = clampf(target.y, 0.0, maxf(vp.y - 48.0, 0.0))
		_panel.global_position = target
	elif _dragging:
		_dragging = false


func set_active(active: bool) -> void:
	visible = active


func refresh(map: EditorMapData, active_path: int, active_wave: int, status: String, valid: bool) -> void:
	_map = map
	_active_path = active_path
	_active_wave = active_wave
	_set_status(status, valid)
	_refresh_path_list()
	_refresh_wave_list()
	_update_title()
	if _skip_inspector_rebuild:
		_skip_inspector_rebuild = false
		return
	_rebuild_inspector()


func refresh_light(map: EditorMapData, active_path: int, active_wave: int, status: String, valid: bool) -> void:
	_map = map
	_active_path = active_path
	_active_wave = active_wave
	_set_status(status, valid)
	_refresh_path_list()
	_refresh_wave_list()
	_update_title()


func set_tool(tool_id: int) -> void:
	_current_tool = tool_id
	if _tool_option == null:
		return
	for i: int in range(_TOOL_ENTRIES.size()):
		if int(_TOOL_ENTRIES[i]["id"]) == tool_id:
			_tool_option.set_block_signals(true)
			_tool_option.select(i)
			_tool_option.set_block_signals(false)
			break
	_update_title()


func show_selection(kind: String) -> void:
	_selected_kind = kind
	_selected_slot = null
	_queue_rebuild_inspector()


func set_selected_slot(slot: EditorTurretSlot) -> void:
	_selected_slot = slot
	_selected_kind = "Turret Slot" if slot != null else ""
	_queue_rebuild_inspector()


func _set_status(text: String, valid: bool) -> void:
	if _status != null:
		_status.text = text
		_status.modulate = _COL_OK if valid else _COL_ERR
	if _valid_badge != null:
		_valid_badge.text = "OK" if valid else "FIX"
		_valid_badge.modulate = _COL_OK if valid else _COL_ERR


func _update_title() -> void:
	if _title == null:
		return
	var tool_label: String = "Path"
	for e: Dictionary in _TOOL_ENTRIES:
		if int(e["id"]) == _current_tool:
			tool_label = String(e["label"])
			break
	_title.text = "DEV EDITOR  ·  %s" % tool_label


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.position = _PANEL_POS
	_panel.custom_minimum_size = Vector2(320, 280)
	_panel.size = _PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _style(_COL_BG, _COL_BORDER, 8))
	_root.add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	_panel.add_child(outer)

	_header = PanelContainer.new()
	_header.custom_minimum_size = Vector2(0, 36)
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_header.add_theme_stylebox_override("panel", _style(_COL_HEADER, _COL_BORDER, 0))
	_header.gui_input.connect(_on_header_input)
	outer.add_child(_header)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	var head_margin := MarginContainer.new()
	head_margin.add_theme_constant_override("margin_left", 10)
	head_margin.add_theme_constant_override("margin_right", 8)
	head_margin.add_theme_constant_override("margin_top", 6)
	head_margin.add_theme_constant_override("margin_bottom", 6)
	head_margin.add_child(head_row)
	_header.add_child(head_margin)

	var grip := Label.new()
	grip.text = "⠿"
	grip.modulate = _COL_ACCENT
	grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_row.add_child(grip)

	_title = Label.new()
	_title.text = "DEV EDITOR"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 14)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_row.add_child(_title)

	_valid_badge = Label.new()
	_valid_badge.text = "—"
	_valid_badge.add_theme_font_size_override("font_size", 12)
	_valid_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_row.add_child(_valid_badge)

	_btn_collapse = Button.new()
	_btn_collapse.text = "▾"
	_btn_collapse.focus_mode = Control.FOCUS_NONE
	_btn_collapse.custom_minimum_size = Vector2(28, 24)
	_btn_collapse.pressed.connect(_toggle_collapsed)
	head_row.add_child(_btn_collapse)

	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 10)
	body_margin.add_theme_constant_override("margin_right", 10)
	body_margin.add_theme_constant_override("margin_top", 8)
	body_margin.add_theme_constant_override("margin_bottom", 10)
	outer.add_child(body_margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_margin.add_child(scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)

	_build_tool_section()
	_build_actions_section()
	_build_paths_section()
	_build_waves_hint()
	_build_inspector_section()
	_build_debug_section()
	_build_status_section()

	set_tool(ToolId.PATH)


func _build_tool_section() -> void:
	var box := _section("Tool")
	_tool_option = OptionButton.new()
	_tool_option.focus_mode = Control.FOCUS_NONE
	_tool_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e: Dictionary in _TOOL_ENTRIES:
		_tool_option.add_item(String(e["label"]))
	_tool_option.item_selected.connect(_on_tool_option)
	box.add_child(_tool_option)
	var hint := Label.new()
	hint.text = "LMB use tool  ·  RMB erase / cancel"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(0.7, 0.8, 0.9, 0.75)
	box.add_child(hint)


func _build_actions_section() -> void:
	var box := _section("Actions")
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 4)
	box.add_child(row1)
	_btn("New", row1, func() -> void: new_pressed.emit())
	_btn("Save", row1, func() -> void: save_pressed.emit())
	_btn("Load", row1, func() -> void: load_pressed.emit())
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	box.add_child(row2)
	_btn("Undo", row2, func() -> void: undo_pressed.emit())
	_btn("Redo", row2, func() -> void: redo_pressed.emit())
	var play := _btn("Playtest", row2, func() -> void: playtest_pressed.emit())
	play.add_theme_color_override("font_color", Color(0.25, 0.95, 0.55))


func _build_paths_section() -> void:
	var box := _section("Paths")
	_path_list = ItemList.new()
	_path_list.custom_minimum_size = Vector2(0, 88)
	_path_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_list.item_selected.connect(func(i: int) -> void: path_index_selected.emit(i))
	box.add_child(_path_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	_btn("+", row, func() -> void: path_add_pressed.emit())
	_btn("Dup", row, func() -> void: path_duplicate_pressed.emit())
	_btn("Rev", row, func() -> void: path_reverse_pressed.emit())
	_btn("Del", row, func() -> void: path_delete_pressed.emit())


func _build_waves_hint() -> void:
	var box := _section("Waves")
	var hint := Label.new()
	hint.text = "F2  Wave Designer"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.7, 0.82, 0.95, 0.9)
	box.add_child(hint)


func _build_inspector_section() -> void:
	var box := _section("Inspector")
	_inspector_box = VBoxContainer.new()
	_inspector_box.add_theme_constant_override("separation", 6)
	_inspector_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_inspector_box)


func _build_debug_section() -> void:
	var box := _section("Overlays")
	_debug_check(box, &"grid", "Grid", true)
	_debug_check(box, &"path_dir", "Path direction", true)
	_debug_check(box, &"path_id", "Path ID", true)
	_debug_check(box, &"slots", "Turret slots", true)
	_debug_check(box, &"blocked", "Blocked cells", true)
	_debug_check(box, &"ranges", "Turret ranges", true)


func _build_status_section() -> void:
	var box := _section("Status")
	_status = Label.new()
	_status.text = "F1 Dev Level Editor"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	box.add_child(_status)
	var keys := Label.new()
	keys.text = "Esc close  ·  Ctrl+Z/Y  ·  Ctrl+S"
	keys.add_theme_font_size_override("font_size", 11)
	keys.modulate = Color(0.65, 0.75, 0.85, 0.8)
	box.add_child(keys)


func _section(title: String) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = title.to_upper()
	label.modulate = _COL_ACCENT
	label.add_theme_font_size_override("font_size", 11)
	wrap.add_child(label)
	_body.add_child(wrap)
	return wrap


func _btn(text: String, parent: Node, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 28)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _on_tool_option(index: int) -> void:
	if index < 0 or index >= _TOOL_ENTRIES.size():
		return
	var e: Dictionary = _TOOL_ENTRIES[index]
	_current_tool = int(e["id"])
	_update_title()
	tool_selected.emit(StringName(e["name"]))


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_dragging = true
			_drag_offset = get_viewport().get_mouse_position() - _panel.global_position
			get_viewport().set_input_as_handled()


func _toggle_collapsed() -> void:
	_collapsed = not _collapsed
	_body.visible = not _collapsed
	_btn_collapse.text = "▸" if _collapsed else "▾"
	if _collapsed:
		_panel.size.y = 44
	else:
		_panel.size = _PANEL_SIZE


func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.shadow_size = 6
	s.shadow_color = Color(0, 0, 0, 0.4)
	return s


func _refresh_path_list() -> void:
	if _path_list == null or _map == null:
		return
	var selected: int = _active_path
	_path_list.clear()
	for i: int in range(_map.paths.size()):
		var p: EditorPathData = _map.paths[i]
		var label: String = "%s (%d)" % [String(p.path_id), p.cells.size()] if p != null else "null"
		_path_list.add_item(label)
	if selected >= 0 and selected < _path_list.item_count:
		_path_list.select(selected)


func _refresh_wave_list() -> void:
	if _wave_list == null or _map == null:
		return
	var selected: int = _active_wave
	_wave_list.clear()
	for i: int in range(_map.waves.size()):
		var w: WaveData = _map.waves[i]
		var n: int = w.build_spawn_queue().size() if w != null else 0
		var label: String = "W%d  x%d  %s" % [
			w.wave_number if w != null else i + 1,
			n,
			w.path_id if w != null else &""
		]
		_wave_list.add_item(label)
	if selected >= 0 and selected < _wave_list.item_count:
		_wave_list.select(selected)


func _queue_rebuild_inspector() -> void:
	if _rebuild_pending:
		return
	_rebuild_pending = true
	call_deferred("_rebuild_inspector")


func _rebuild_inspector() -> void:
	_rebuild_pending = false
	if _inspector_box == null or _committing:
		return
	var to_free: Array[Node] = []
	for c: Node in _inspector_box.get_children():
		to_free.append(c)
	for c2: Node in to_free:
		_inspector_box.remove_child(c2)
		c2.queue_free()
	_inspector_fields.clear()
	if _map == null:
		return

	_add_insp_label("Map")
	_add_insp_string("map_name", "Name", _map.map_name)
	_add_insp_int("grid_columns", "Columns", _map.grid_columns)
	_add_insp_int("grid_rows", "Rows", _map.grid_rows)
	_add_insp_float("starting_bio_energy", "Bio-Energy", _map.starting_bio_energy)
	_add_insp_float("nucleus_max_health", "Nucleus HP", _map.nucleus_max_health)
	_add_insp_bool("restrict_build_to_slots", "Slots only", _map.restrict_build_to_slots)
	_add_insp_float("level_hp_multiplier", "HP Mult", _map.level_hp_multiplier)
	_add_insp_float("level_speed_multiplier", "Speed Mult", _map.level_speed_multiplier)

	if _active_path >= 0 and _active_path < _map.paths.size():
		var p: EditorPathData = _map.paths[_active_path]
		if p != null:
			_add_insp_label("Path")
			_add_insp_string("path_id", "ID", String(p.path_id))
			_add_insp_string("path_display", "Name", p.display_name)
			_add_insp_int("path_unlock", "Unlock wave", p.unlock_from_wave)
			_add_insp_label("Spawn %s · Core %s · %d cells" % [
				str(p.get_spawn()), str(p.get_core()), p.cells.size()
			])

	if _selected_slot != null:
		_add_insp_label("Slot")
		_add_insp_string("slot_plant", "Plant ID", String(_selected_slot.plant_id))
		_add_insp_bool("slot_starts_active", "Pre-placed", _selected_slot.starts_active)
		_add_insp_bool("slot_enabled", "Enabled", _selected_slot.enabled)
		_add_insp_label("Cell %s" % str(_selected_slot.cell))
	elif _selected_kind != "":
		_add_insp_label(_selected_kind)


func _add_insp_label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = _COL_ACCENT
	l.add_theme_font_size_override("font_size", 11)
	_inspector_box.add_child(l)


func _add_insp_string(key: String, label: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(100, 0)
	row.add_child(l)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_submitted.connect(func(t: String) -> void: _on_field(key, t))
	edit.focus_exited.connect(func() -> void:
		if is_instance_valid(edit):
			_on_field(key, edit.text)
	)
	row.add_child(edit)
	_inspector_box.add_child(row)
	_inspector_fields[key] = edit


func _add_insp_int(key: String, label: String, value: int) -> void:
	_add_insp_string(key, label, str(value))


func _add_insp_float(key: String, label: String, value: float) -> void:
	_add_insp_string(key, label, str(value))


func _add_insp_bool(key: String, label: String, value: bool) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var box := CheckBox.new()
	box.button_pressed = value
	box.focus_mode = Control.FOCUS_NONE
	box.toggled.connect(func(on: bool) -> void: _on_field(key, "1" if on else "0"))
	row.add_child(box)
	_inspector_box.add_child(row)


func _parse_int(text: String, fallback: int) -> int:
	var t: String = text.strip_edges()
	if t.is_empty() or not t.is_valid_int():
		return fallback
	return int(t)


func _parse_float(text: String, fallback: float) -> float:
	var t: String = text.strip_edges()
	if t.is_empty() or not t.is_valid_float():
		return fallback
	return float(t)


func _on_field(key: String, text: String) -> void:
	if _map == null or _committing:
		return
	_committing = true
	match key:
		"map_name":
			_map.map_name = text
		"grid_columns":
			_map.grid_columns = maxi(_parse_int(text, _map.grid_columns), 1)
		"grid_rows":
			_map.grid_rows = maxi(_parse_int(text, _map.grid_rows), 1)
		"starting_bio_energy":
			_map.starting_bio_energy = maxf(_parse_float(text, _map.starting_bio_energy), 0.0)
		"nucleus_max_health":
			_map.nucleus_max_health = maxf(_parse_float(text, _map.nucleus_max_health), 1.0)
		"restrict_build_to_slots":
			_map.restrict_build_to_slots = text != "0"
			_map.placement_mode = (
				EditorMapData.PlacementMode.SLOTS_ONLY
				if _map.restrict_build_to_slots
				else EditorMapData.PlacementMode.FREE
			)
		"level_hp_multiplier":
			_map.level_hp_multiplier = maxf(_parse_float(text, _map.level_hp_multiplier), 0.01)
		"level_speed_multiplier":
			_map.level_speed_multiplier = maxf(_parse_float(text, _map.level_speed_multiplier), 0.01)
		"path_id":
			if _active_path >= 0 and _active_path < _map.paths.size() and _map.paths[_active_path] != null:
				_map.paths[_active_path].path_id = StringName(text)
		"path_display":
			if _active_path >= 0 and _active_path < _map.paths.size() and _map.paths[_active_path] != null:
				_map.paths[_active_path].display_name = text
		"path_unlock":
			if _active_path >= 0 and _active_path < _map.paths.size() and _map.paths[_active_path] != null:
				_map.paths[_active_path].unlock_from_wave = maxi(
					_parse_int(text, _map.paths[_active_path].unlock_from_wave), 1
				)
		"wave_number":
			if _active_wave >= 0 and _active_wave < _map.waves.size() and _map.waves[_active_wave] != null:
				_map.waves[_active_wave].wave_number = maxi(
					_parse_int(text, _map.waves[_active_wave].wave_number), 1
				)
		"wave_interval":
			if _active_wave >= 0 and _active_wave < _map.waves.size() and _map.waves[_active_wave] != null:
				_map.waves[_active_wave].spawn_interval = maxf(
					_parse_float(text, _map.waves[_active_wave].spawn_interval), 0.0
				)
		"wave_delay":
			if _active_wave >= 0 and _active_wave < _map.waves.size() and _map.waves[_active_wave] != null:
				_map.waves[_active_wave].delay_before_wave = maxf(
					_parse_float(text, _map.waves[_active_wave].delay_before_wave), 0.0
				)
		"wave_hp":
			if _active_wave >= 0 and _active_wave < _map.waves.size() and _map.waves[_active_wave] != null:
				_map.waves[_active_wave].hp_multiplier = maxf(
					_parse_float(text, _map.waves[_active_wave].hp_multiplier), 0.01
				)
		"wave_speed":
			if _active_wave >= 0 and _active_wave < _map.waves.size() and _map.waves[_active_wave] != null:
				_map.waves[_active_wave].speed_multiplier = maxf(
					_parse_float(text, _map.waves[_active_wave].speed_multiplier), 0.01
				)
		"wave_path":
			if _active_wave >= 0 and _active_wave < _map.waves.size() and _map.waves[_active_wave] != null:
				_map.waves[_active_wave].path_id = StringName(text)
		"wave_count":
			if _active_wave >= 0 and _active_wave < _map.waves.size() and _map.waves[_active_wave] != null:
				_map.waves[_active_wave].insect_count = maxi(
					_parse_int(text, _map.waves[_active_wave].insect_count), 0
				)
		"wave_reward":
			if _active_wave >= 0 and _active_wave < _map.waves.size() and _map.waves[_active_wave] != null:
				_map.waves[_active_wave].reward_bonus = maxi(
					_parse_int(text, _map.waves[_active_wave].reward_bonus), 0
				)
		"slot_plant":
			if _selected_slot != null:
				_selected_slot.plant_id = StringName(text)
		"slot_starts_active":
			if _selected_slot != null:
				_selected_slot.starts_active = text != "0"
		"slot_enabled":
			if _selected_slot != null:
				_selected_slot.enabled = text != "0"
	_committing = false
	_skip_inspector_rebuild = true
	inspector_changed.emit()


func _debug_check(parent: Node, flag: StringName, label: String, default_on: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var cb := CheckBox.new()
	cb.button_pressed = default_on
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(func(on: bool) -> void: debug_toggled.emit(flag, on))
	row.add_child(cb)
	var l := Label.new()
	l.text = label
	row.add_child(l)
	parent.add_child(row)
