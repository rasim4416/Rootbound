## F2 Wave Designer chrome: toolbar + wave list + timeline + inspector.
class_name WaveDesignerUI
extends CanvasLayer

signal new_wave_pressed
signal duplicate_wave_pressed
signal delete_wave_pressed
signal add_ten_pressed
signal move_wave_up_pressed
signal move_wave_down_pressed
signal add_group_pressed
signal duplicate_group_pressed
signal delete_group_pressed
signal move_group_up_pressed
signal move_group_down_pressed
signal undo_pressed
signal redo_pressed
signal test_pressed
signal test_from_here_pressed
signal stop_pressed
signal save_pressed
signal wave_index_selected(index: int)
signal group_index_selected(index: int)
signal inspector_changed()
signal inspector_live_changed()
signal timeline_changed()
signal rename_wave_requested(index: int)
signal context_test_requested(index: int)
signal scale_selected_requested(percent: float)
signal scale_waves_requested(index_a: int, index_b: int, start_mult: float, end_mult: float)
signal add_event_pressed
signal delete_event_pressed

const _COL_BG := Color(0.06, 0.08, 0.12, 0.97)
const _COL_HEADER := Color(0.09, 0.12, 0.18, 1.0)
const _COL_BORDER := Color(0.32, 0.62, 0.82, 0.9)
const _COL_ACCENT := Color(0.5, 0.85, 1.0, 1.0)
const _COL_OK := Color(0.55, 0.92, 0.7, 1.0)
const _COL_ERR := Color(1.0, 0.55, 0.48, 1.0)

var _panel: PanelContainer
var _wave_list: ItemList
var _group_list: ItemList
var _timeline: WaveTimeline
var _curve: WaveSpawnCurve
var _inspector: VBoxContainer
var _preview: Label
var _hud: Label
var _status: Label
var _header: PanelContainer
var _title: Label
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _map: EditorMapData
var _active_wave: int = 0
var _active_group: int = 0
var _active_event: int = -1
var _committing: bool = false
var _skip_inspector: bool = false
var _building_inspector: bool = false
var _enemy_ids: Array[StringName] = []
var _path_ids: Array[StringName] = []
var _context_menu: PopupMenu
var _context_wave: int = -1
var _rename_dialog: AcceptDialog
var _rename_edit: LineEdit
var _scale_sel_dialog: AcceptDialog
var _scale_pct: SpinBox
var _scale_range_dialog: AcceptDialog
var _scale_a: SpinBox
var _scale_b: SpinBox
var _scale_start: SpinBox
var _scale_end: SpinBox
var _syncing_list: bool = false


func _ready() -> void:
	layer = 92
	_build()
	visible = false
	set_process(true)


func _process(_delta: float) -> void:
	if _dragging and _panel != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var target: Vector2 = get_viewport().get_mouse_position() - _drag_offset
		var vp: Vector2 = get_viewport().get_visible_rect().size
		target.x = clampf(target.x, 0.0, maxf(vp.x - _panel.size.x, 0.0))
		target.y = clampf(target.y, 0.0, maxf(vp.y - 40.0, 0.0))
		_panel.global_position = target
	elif _dragging:
		_dragging = false


func set_active(active: bool) -> void:
	visible = active
	if active:
		_layout()


func refresh(map: EditorMapData, active_wave: int, active_group: int, status: String, ok: bool) -> void:
	if active_wave != _active_wave:
		_active_event = -1
	_map = map
	_active_wave = active_wave
	_active_group = active_group
	_collect_ids()
	_set_status(status, ok)
	_refresh_wave_list()
	_refresh_group_list()
	_refresh_timeline()
	_update_preview()
	if _skip_inspector:
		_skip_inspector = false
		return
	_rebuild_inspector()


func refresh_light(map: EditorMapData, active_wave: int, active_group: int, status: String, ok: bool) -> void:
	if active_wave != _active_wave:
		_active_event = -1
	_map = map
	_active_wave = active_wave
	_active_group = active_group
	_set_status(status, ok)
	_refresh_wave_list()
	_refresh_group_list()
	_refresh_timeline()
	_update_preview()
	_skip_inspector = false


func set_live_hud(text: String, testing: bool) -> void:
	if _hud == null:
		return
	_hud.visible = testing
	_hud.text = text


func get_selected_wave_indices() -> PackedInt32Array:
	if _wave_list == null:
		return PackedInt32Array()
	var items: PackedInt32Array = _wave_list.get_selected_items()
	if items.is_empty() and _active_wave >= 0:
		return PackedInt32Array([_active_wave])
	return items


func get_active_event() -> int:
	return _active_event


func set_active_event(index: int) -> void:
	_active_event = index


func _set_status(text: String, ok: bool) -> void:
	if _status == null:
		return
	_status.text = text
	_status.modulate = _COL_OK if ok else _COL_ERR


func _layout() -> void:
	if _panel == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(mini(vp.x - 24.0, 1240.0), mini(vp.y - 48.0, 680.0))
	_panel.custom_minimum_size = _panel.size
	if _panel.position == Vector2.ZERO:
		_panel.position = Vector2(12, 36)


func _collect_ids() -> void:
	_path_ids.clear()
	_enemy_ids.clear()
	if _map == null:
		return
	for p: EditorPathData in _map.paths:
		if p != null and p.path_id != &"":
			_path_ids.append(p.path_id)
	_enemy_ids = _map.available_enemy_ids.duplicate()
	if _enemy_ids.is_empty():
		_enemy_ids = [&"ant", &"virus"]


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 36)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _style(_COL_BG, _COL_BORDER, 8))
	root.add_child(_panel)

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
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 10)
	hm.add_theme_constant_override("margin_right", 10)
	hm.add_theme_constant_override("margin_top", 6)
	hm.add_theme_constant_override("margin_bottom", 6)
	hm.add_child(head_row)
	_header.add_child(hm)
	var grip := Label.new()
	grip.text = "⠿"
	grip.modulate = _COL_ACCENT
	grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_row.add_child(grip)
	_title = Label.new()
	_title.text = "WAVE DESIGNER"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 14)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_row.add_child(_title)
	var hint := Label.new()
	hint.text = "F2 / Esc"
	hint.modulate = Color(0.65, 0.75, 0.85, 0.85)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_row.add_child(hint)

	var body_m := MarginContainer.new()
	body_m.add_theme_constant_override("margin_left", 8)
	body_m.add_theme_constant_override("margin_right", 8)
	body_m.add_theme_constant_override("margin_top", 8)
	body_m.add_theme_constant_override("margin_bottom", 8)
	body_m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body_m)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_m.add_child(body)

	body.add_child(_build_toolbar())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 8)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)

	cols.add_child(_build_left())
	cols.add_child(_build_middle())
	cols.add_child(_build_right())

	_hud = Label.new()
	_hud.visible = false
	_hud.modulate = _COL_OK
	_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_hud)

	_status = Label.new()
	_status.text = "Wave Designer"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)

	_context_menu = PopupMenu.new()
	_context_menu.add_item("Rename", 0)
	_context_menu.add_item("Duplicate", 1)
	_context_menu.add_item("Delete", 2)
	_context_menu.add_item("Test", 3)
	_context_menu.id_pressed.connect(_on_context)
	add_child(_context_menu)

	_rename_dialog = AcceptDialog.new()
	_rename_dialog.title = "Rename Wave"
	_rename_edit = LineEdit.new()
	_rename_dialog.add_child(_rename_edit)
	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	add_child(_rename_dialog)

	_build_scale_dialogs()
	_layout()


func _build_toolbar() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 36)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	scroll.add_child(row)
	_btn("New Wave", row, func() -> void: new_wave_pressed.emit(), false)
	_btn("Duplicate", row, func() -> void: duplicate_wave_pressed.emit(), false)
	_btn("Delete", row, func() -> void: delete_wave_pressed.emit(), false)
	_btn("Add Group", row, func() -> void: add_group_pressed.emit(), false)
	_btn("Undo", row, func() -> void: undo_pressed.emit(), false)
	_btn("Redo", row, func() -> void: redo_pressed.emit(), false)
	var test := _btn("Test Wave", row, func() -> void: test_pressed.emit(), false)
	test.add_theme_color_override("font_color", Color(0.25, 0.95, 0.55))
	var from_here := _btn("Test From Here", row, func() -> void: test_from_here_pressed.emit(), false)
	from_here.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	_btn("Stop", row, func() -> void: stop_pressed.emit(), false)
	_btn("Scale selected…", row, func() -> void: _open_scale_selected(), false)
	_btn("Scale Waves", row, func() -> void: _open_scale_waves(), false)
	_btn("Save", row, func() -> void: save_pressed.emit(), false)
	return scroll


func _build_left() -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(280, 0)
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(_section_label("Waves"))
	_wave_list = ItemList.new()
	_wave_list.select_mode = ItemList.SELECT_MULTI
	_wave_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wave_list.custom_minimum_size = Vector2(0, 280)
	_wave_list.item_selected.connect(func(i: int) -> void:
		if _syncing_list:
			return
		wave_index_selected.emit(i)
	)
	_wave_list.item_clicked.connect(_on_wave_clicked)
	wrap.add_child(_wave_list)
	var r1 := HBoxContainer.new()
	wrap.add_child(r1)
	_btn("+", r1, func() -> void: new_wave_pressed.emit())
	_btn("Dup", r1, func() -> void: duplicate_wave_pressed.emit())
	_btn("Del", r1, func() -> void: delete_wave_pressed.emit())
	var r2 := HBoxContainer.new()
	wrap.add_child(r2)
	_btn("Up", r2, func() -> void: move_wave_up_pressed.emit())
	_btn("Down", r2, func() -> void: move_wave_down_pressed.emit())
	_btn("Add 10", r2, func() -> void: add_ten_pressed.emit())
	return wrap


func _build_middle() -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(_section_label("Timeline"))
	var time_scroll := ScrollContainer.new()
	time_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	time_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_scroll.custom_minimum_size = Vector2(0, 140)
	time_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	time_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	wrap.add_child(time_scroll)
	_timeline = WaveTimeline.new()
	_timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline.group_selected.connect(func(i: int) -> void: group_index_selected.emit(i))
	_timeline.group_start_changed.connect(func(_i: int, _t: float) -> void:
		timeline_changed.emit()
	)
	_timeline.group_drag_ended.connect(func() -> void:
		inspector_changed.emit()
	)
	_timeline.event_selected.connect(func(i: int) -> void:
		_active_event = i
		_skip_inspector = false
		inspector_live_changed.emit()
		_rebuild_inspector()
	)
	time_scroll.add_child(_timeline)
	wrap.add_child(_section_label("Spawn density"))
	_curve = WaveSpawnCurve.new()
	_curve.custom_minimum_size = Vector2(0, 72)
	wrap.add_child(_curve)
	wrap.add_child(_section_label("Groups"))
	_group_list = ItemList.new()
	_group_list.custom_minimum_size = Vector2(0, 110)
	_group_list.item_selected.connect(func(i: int) -> void:
		if _syncing_list:
			return
		group_index_selected.emit(i)
	)
	wrap.add_child(_group_list)
	var r := HBoxContainer.new()
	wrap.add_child(r)
	_btn("+ Group", r, func() -> void: add_group_pressed.emit())
	_btn("Dup", r, func() -> void: duplicate_group_pressed.emit())
	_btn("Del", r, func() -> void: delete_group_pressed.emit())
	_btn("Up", r, func() -> void: move_group_up_pressed.emit())
	_btn("Down", r, func() -> void: move_group_down_pressed.emit())
	return wrap


func _build_right() -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(300, 0)
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(_section_label("Inspector"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	wrap.add_child(scroll)
	_inspector = VBoxContainer.new()
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_inspector.add_theme_constant_override("separation", 6)
	scroll.add_child(_inspector)
	wrap.add_child(_section_label("Preview"))
	_preview = Label.new()
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.modulate = Color(0.75, 0.85, 0.95, 1.0)
	_preview.text = "No wave"
	wrap.add_child(_preview)
	return wrap


func _build_scale_dialogs() -> void:
	_scale_sel_dialog = AcceptDialog.new()
	_scale_sel_dialog.title = "Scale selected waves"
	_scale_sel_dialog.ok_button_text = "Apply"
	var sel_box := VBoxContainer.new()
	sel_box.add_theme_constant_override("separation", 8)
	var sel_hint := Label.new()
	sel_hint.text = "Multiply HP / Speed / Damage / reward bonus by (1 + %)."
	sel_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel_box.add_child(sel_hint)
	_scale_pct = SpinBox.new()
	_scale_pct.min_value = -90.0
	_scale_pct.max_value = 400.0
	_scale_pct.step = 1.0
	_scale_pct.value = 10.0
	_scale_pct.suffix = "%"
	sel_box.add_child(_scale_pct)
	_scale_sel_dialog.add_child(sel_box)
	_scale_sel_dialog.confirmed.connect(func() -> void:
		scale_selected_requested.emit(_scale_pct.value)
	)
	add_child(_scale_sel_dialog)

	_scale_range_dialog = AcceptDialog.new()
	_scale_range_dialog.title = "Scale Waves"
	_scale_range_dialog.ok_button_text = "Apply"
	var range_box := VBoxContainer.new()
	range_box.add_theme_constant_override("separation", 6)
	var range_hint := Label.new()
	range_hint.text = "Interpolate HP / Speed / Damage from start→end between wave indices. Reward bonus lerps between the two waves."
	range_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	range_box.add_child(range_hint)
	_scale_a = _labeled_spin(range_box, "Wave A (1-based)", 1.0, 1.0, 999.0, 1.0)
	_scale_b = _labeled_spin(range_box, "Wave B (1-based)", 2.0, 1.0, 999.0, 1.0)
	_scale_start = _labeled_spin(range_box, "Start ×", 1.0, 0.01, 10.0, 0.05)
	_scale_end = _labeled_spin(range_box, "End ×", 2.0, 0.01, 10.0, 0.05)
	_scale_range_dialog.add_child(range_box)
	_scale_range_dialog.confirmed.connect(func() -> void:
		scale_waves_requested.emit(int(_scale_a.value) - 1, int(_scale_b.value) - 1, _scale_start.value, _scale_end.value)
	)
	add_child(_scale_range_dialog)


func _labeled_spin(parent: Node, caption: String, value: float, mn: float, mx: float, step: float) -> SpinBox:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = caption
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(90, 0)
	row.add_child(s)
	parent.add_child(row)
	return s


func _open_scale_selected() -> void:
	_scale_sel_dialog.popup_centered(Vector2i(360, 140))


func _open_scale_waves() -> void:
	if _map != null:
		_scale_a.max_value = maxf(float(_map.waves.size()), 1.0)
		_scale_b.max_value = maxf(float(_map.waves.size()), 1.0)
		_scale_a.value = float(_active_wave + 1)
		_scale_b.value = float(_map.waves.size())
	_scale_range_dialog.popup_centered(Vector2i(400, 220))


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_dragging = true
			_drag_offset = get_viewport().get_mouse_position() - _panel.global_position
			get_viewport().set_input_as_handled()


func _on_wave_clicked(index: int, _at: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		_context_wave = index
		_context_menu.position = Vector2i(get_viewport().get_mouse_position())
		_context_menu.popup()


func _on_context(id: int) -> void:
	match id:
		0:
			rename_wave_requested.emit(_context_wave)
		1:
			wave_index_selected.emit(_context_wave)
			duplicate_wave_pressed.emit()
		2:
			wave_index_selected.emit(_context_wave)
			delete_wave_pressed.emit()
		3:
			context_test_requested.emit(_context_wave)


func prompt_rename(current: String) -> void:
	_rename_edit.text = current
	_rename_dialog.popup_centered(Vector2i(320, 80))
	_rename_edit.grab_focus()


func _on_rename_confirmed() -> void:
	if _map == null or _active_wave < 0 or _active_wave >= _map.waves.size():
		return
	_map.waves[_active_wave].display_name = _rename_edit.text.strip_edges()
	_skip_inspector = true
	inspector_changed.emit()


func _refresh_wave_list() -> void:
	if _wave_list == null or _map == null:
		return
	var keep: PackedInt32Array = _wave_list.get_selected_items()
	var sel: int = _active_wave
	_syncing_list = true
	_wave_list.clear()
	for i: int in range(_map.waves.size()):
		_wave_list.add_item(WaveDesignerStats.list_label(_map.waves[i], i))
	var restored: bool = false
	for i: int in keep:
		if i >= 0 and i < _wave_list.item_count:
			_wave_list.select(i, false)
			restored = true
	if sel >= 0 and sel < _wave_list.item_count:
		_wave_list.select(sel, not restored)
	elif _wave_list.item_count > 0 and not restored:
		_wave_list.select(0)
	_syncing_list = false


func _refresh_group_list() -> void:
	if _group_list == null:
		return
	_syncing_list = true
	_group_list.clear()
	var wave: WaveData = _current_wave()
	if wave == null:
		_syncing_list = false
		return
	for i: int in range(wave.spawn_entries.size()):
		var e: WaveSpawnEntry = wave.spawn_entries[i]
		var name: String = e.insect_data.display_name if e != null and e.insect_data != null else "?"
		var pid: StringName = e.path_id if e != null and e.path_id != &"" else (wave.path_id if wave.path_id != &"" else &"any")
		_group_list.add_item("G%d  %s  x%d  t=%.1f  %s" % [i + 1, name, e.count if e != null else 0, e.start_time if e != null else 0.0, String(pid)])
	if _active_group >= 0 and _active_group < _group_list.item_count:
		_group_list.select(_active_group)
	_syncing_list = false


func _refresh_timeline() -> void:
	if _timeline != null:
		_timeline.set_wave(_current_wave(), _active_group, _active_event)


func _update_preview() -> void:
	if _preview != null:
		_preview.text = WaveDesignerStats.preview_text(_current_wave(), _map)
	if _curve != null:
		_curve.set_wave(_current_wave())


func _current_wave() -> WaveData:
	if _map == null or _active_wave < 0 or _active_wave >= _map.waves.size():
		return null
	return _map.waves[_active_wave]


func _rebuild_inspector() -> void:
	if _inspector == null or _committing:
		return
	_building_inspector = true
	for c: Node in _inspector.get_children():
		_inspector.remove_child(c)
		c.queue_free()
	var wave: WaveData = _current_wave()
	if wave == null:
		_add_label("No wave selected")
		_building_inspector = false
		return

	var warns: PackedStringArray = WaveDesignerStats.warnings(wave, _path_ids)
	if not warns.is_empty():
		_add_label("⚠  " + ", ".join(warns), _COL_ERR)

	_add_label("Wave")
	_add_int("wave_number", "Number", wave.wave_number)
	_add_string("display_name", "Name", wave.display_name)
	_add_float("delay", "Start delay (s)", wave.delay_before_wave)
	_add_float("interval", "Default interval", wave.spawn_interval)
	_add_path("wave_path", "Default path", wave.path_id)
	_add_mult_slider("hp", "HP ×", wave.hp_multiplier)
	_add_mult_slider("speed", "Speed ×", wave.speed_multiplier)
	_add_mult_slider("dmg", "Damage ×", wave.core_damage_multiplier)
	_add_int("reward", "Reward bonus", wave.reward_bonus)

	if _active_group >= 0 and _active_group < wave.spawn_entries.size():
		var e: WaveSpawnEntry = wave.spawn_entries[_active_group]
		if e != null:
			_add_label("Group %d" % (_active_group + 1))
			_add_enemy("enemy", e.insect_data)
			_add_int("count", "Amount", e.count)
			_add_float("start", "Start (s)", e.start_time)
			var shown_iv: float = e.spawn_interval
			if shown_iv < 0.0:
				shown_iv = wave.spawn_interval
			_add_float("g_interval", "Interval (s)", shown_iv)
			_add_path("g_path", "Path", e.path_id if e.path_id != &"" else wave.path_id)

	_add_label("Special events (editor only)")
	for i: int in range(wave.special_events.size()):
		var ev: WaveSpecialEvent = wave.special_events[i]
		if ev == null:
			continue
		var mark: String = "▸ " if i == _active_event else "  "
		_add_label("%s%d  %s  t=%.1f  %s" % [mark, i + 1, ev.kind_name(), ev.time, ev.label], Color(1.0, 0.82, 0.4, 1.0) if i == _active_event else _COL_ACCENT)
	var ev_row := HBoxContainer.new()
	_inspector.add_child(ev_row)
	_btn("Add event", ev_row, func() -> void: add_event_pressed.emit())
	_btn("Delete event", ev_row, func() -> void: delete_event_pressed.emit())
	if _active_event >= 0 and _active_event < wave.special_events.size() and wave.special_events[_active_event] != null:
		var sev: WaveSpecialEvent = wave.special_events[_active_event]
		_add_event_kind(sev)
		_add_float("ev_time", "Event time (s)", sev.time)
		_add_string("ev_label", "Event label", sev.label)

	_building_inspector = false


func _add_label(text: String, col: Color = _COL_ACCENT) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector.add_child(l)


func _add_string(key: String, label: String, value: String) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
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
	_inspector.add_child(row)


func _add_int(key: String, label: String, value: int) -> void:
	_add_string(key, label, str(value))


func _add_float(key: String, label: String, value: float) -> void:
	_add_string(key, label, str(value))


func _add_mult_slider(key: String, label: String, value: float) -> void:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var edit := LineEdit.new()
	edit.text = "%.2f" % value
	edit.custom_minimum_size = Vector2(56, 0)
	row.add_child(edit)
	wrap.add_child(row)
	var slider := HSlider.new()
	slider.min_value = 0.01
	slider.max_value = maxf(5.0, value)
	slider.step = 0.05
	slider.value = clampf(value, 0.01, slider.max_value)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.scrollable = false
	wrap.add_child(slider)
	slider.value_changed.connect(func(v: float) -> void:
		if _building_inspector or _committing:
			return
		edit.text = "%.2f" % v
		_on_mult_live(key, v)
	)
	slider.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			inspector_changed.emit()
	)
	edit.text_submitted.connect(func(t: String) -> void:
		var v: float = maxf(_parse_float(t, value), 0.01)
		_building_inspector = true
		slider.max_value = maxf(5.0, v)
		slider.value = v
		_building_inspector = false
		_on_field(key, str(v))
	)
	edit.focus_exited.connect(func() -> void:
		if is_instance_valid(edit):
			var v: float = maxf(_parse_float(edit.text, value), 0.01)
			_building_inspector = true
			slider.max_value = maxf(5.0, v)
			slider.value = v
			_building_inspector = false
			_on_field(key, str(v))
	)
	_inspector.add_child(wrap)


func _add_event_kind(ev: WaveSpecialEvent) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "Kind"
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var names: PackedStringArray = PackedStringArray(["Boss Spawn", "Elite Burst", "Enemy Rush", "Healing Wave", "Mutation"])
	for i: int in range(names.size()):
		opt.add_item(names[i], i)
	opt.select(int(ev.kind))
	opt.item_selected.connect(func(i: int) -> void:
		_on_field("ev_kind", str(i))
	)
	row.add_child(opt)
	_inspector.add_child(row)


func _add_path(key: String, label: String, current: StringName) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_item("(primary)")
	opt.set_item_metadata(0, &"")
	var sel: int = 0
	for i: int in range(_path_ids.size()):
		opt.add_item(String(_path_ids[i]))
		opt.set_item_metadata(i + 1, _path_ids[i])
		if _path_ids[i] == current:
			sel = i + 1
	opt.select(sel)
	opt.item_selected.connect(func(i: int) -> void:
		_on_field(key, String(opt.get_item_metadata(i)))
	)
	row.add_child(opt)
	_inspector.add_child(row)


func _add_enemy(key: String, current: InsectData) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "Enemy"
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sel: int = 0
	var cur_id: StringName = current.insect_id if current != null else &""
	for i: int in range(_enemy_ids.size()):
		opt.add_item(String(_enemy_ids[i]))
		opt.set_item_metadata(i, _enemy_ids[i])
		if _enemy_ids[i] == cur_id:
			sel = i
	if not _enemy_ids.is_empty():
		opt.select(sel)
	opt.item_selected.connect(func(i: int) -> void:
		_on_field(key, String(opt.get_item_metadata(i)))
	)
	row.add_child(opt)
	_inspector.add_child(row)


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


func _on_mult_live(key: String, value: float) -> void:
	var wave: WaveData = _current_wave()
	if wave == null or _committing or _building_inspector:
		return
	match key:
		"hp":
			wave.hp_multiplier = maxf(value, 0.01)
		"speed":
			wave.speed_multiplier = maxf(value, 0.01)
		"dmg":
			wave.core_damage_multiplier = maxf(value, 0.01)
	_skip_inspector = true
	inspector_live_changed.emit()


func _on_field(key: String, text: String) -> void:
	var wave: WaveData = _current_wave()
	if wave == null or _committing:
		return
	_committing = true
	var e: WaveSpawnEntry = null
	if _active_group >= 0 and _active_group < wave.spawn_entries.size():
		e = wave.spawn_entries[_active_group]
	var sev: WaveSpecialEvent = null
	if _active_event >= 0 and wave.special_events != null and _active_event < wave.special_events.size():
		sev = wave.special_events[_active_event]
	match key:
		"wave_number":
			wave.wave_number = maxi(_parse_int(text, wave.wave_number), 1)
		"display_name":
			wave.display_name = text
		"delay":
			wave.delay_before_wave = maxf(_parse_float(text, wave.delay_before_wave), 0.0)
		"interval":
			wave.spawn_interval = maxf(_parse_float(text, wave.spawn_interval), 0.0)
		"wave_path":
			wave.path_id = StringName(text)
		"hp":
			wave.hp_multiplier = maxf(_parse_float(text, wave.hp_multiplier), 0.01)
		"speed":
			wave.speed_multiplier = maxf(_parse_float(text, wave.speed_multiplier), 0.01)
		"dmg":
			wave.core_damage_multiplier = maxf(_parse_float(text, wave.core_damage_multiplier), 0.01)
		"reward":
			wave.reward_bonus = maxi(_parse_int(text, wave.reward_bonus), 0)
		"enemy":
			if e != null:
				e.insect_data = WaveDesignerUI.load_insect(StringName(text))
		"count":
			if e != null:
				e.count = maxi(_parse_int(text, e.count), 0)
		"start":
			if e != null:
				e.start_time = maxf(_parse_float(text, e.start_time), 0.0)
		"g_interval":
			if e != null:
				e.spawn_interval = maxf(_parse_float(text, e.resolve_interval(wave.spawn_interval)), 0.0)
		"g_path":
			if e != null:
				e.path_id = StringName(text)
		"ev_kind":
			if sev != null:
				sev.kind = clampi(_parse_int(text, int(sev.kind)), 0, int(WaveSpecialEvent.Kind.MUTATION)) as WaveSpecialEvent.Kind
		"ev_time":
			if sev != null:
				sev.time = maxf(_parse_float(text, sev.time), 0.0)
		"ev_label":
			if sev != null:
				sev.label = text
	_committing = false
	_skip_inspector = true
	inspector_changed.emit()


static func load_insect(insect_id: StringName) -> InsectData:
	if insect_id == &"":
		return null
	var path: String = "res://data/insects/%s.tres" % String(insect_id)
	if ResourceLoader.exists(path):
		return load(path) as InsectData
	return null


func _btn(text: String, parent: Node, cb: Callable, expand: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 28)
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _section_label(t: String) -> Label:
	var l := Label.new()
	l.text = t.to_upper()
	l.modulate = _COL_ACCENT
	l.add_theme_font_size_override("font_size", 11)
	return l


func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.shadow_size = 6
	s.shadow_color = Color(0, 0, 0, 0.4)
	return s
