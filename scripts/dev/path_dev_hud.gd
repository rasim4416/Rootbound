## Draggable, sectioned HUD for Path Dev Mode (F1).
## Built for growth: use get_section() / add_to_section() when adding tools later.
class_name PathDevHud
extends CanvasLayer

signal tool_paint_pressed
signal tool_spawn_pressed
signal tool_core_pressed
signal test_wave_pressed
signal save_pressed
signal load_pressed
signal clear_pressed

const PANEL_MIN := Vector2(340, 280)
const PANEL_DEFAULT_POS := Vector2(16, 68)
const PANEL_DEFAULT_SIZE := Vector2(380, 420)

var _root: Control
var _panel: PanelContainer
var _header: PanelContainer
var _title: Label
var _valid_badge: Label
var _status: Label
var _errors: RichTextLabel
var _meta_cells: Label
var _meta_spawn: Label
var _meta_core: Label
var _btn_paint: Button
var _btn_spawn: Button
var _btn_core: Button
var _btn_test: Button
var _shortcuts: Label
var _sections: Dictionary = {} # StringName -> VBoxContainer
var _flash_timer: float = 0.0
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _collapsed: bool = false
var _body: VBoxContainer
var _btn_collapse: Button


func _ready() -> void:
	layer = 80
	_build()
	set_process(true)
	visible = false


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer = maxf(_flash_timer - delta, 0.0)
	if _dragging and _panel != null:
		_follow_drag()


func refresh(
	active: bool,
	tool_mode: int,
	cell_count: int,
	spawn: Vector2i,
	core: Vector2i,
	valid: bool,
	errors: PackedStringArray
) -> void:
	if not active:
		return

	var tool_name: String = "PAINT"
	match tool_mode:
		PathDevMode.ToolMode.SPAWN:
			tool_name = "SPAWN"
		PathDevMode.ToolMode.CORE:
			tool_name = "CORE"
	_title.text = "PATH DEV  ·  %s" % tool_name

	_meta_cells.text = "Cells   %d" % cell_count
	_meta_spawn.text = "Spawn  %s" % str(spawn)
	_meta_core.text = "Core    %s" % str(core)

	if valid:
		_valid_badge.text = "VALID"
		_valid_badge.modulate = Color(0.45, 1.0, 0.7, 1.0)
		_status.text = "Spawn reaches Core along the path."
		_status.modulate = Color(0.7, 0.95, 0.8, 1.0)
		_errors.text = ""
		_errors.visible = false
	else:
		_valid_badge.text = "INVALID"
		_valid_badge.modulate = Color(1.0, 0.45, 0.4, 1.0)
		_status.text = "Fix issues before Save / Test Wave."
		_status.modulate = Color(1.0, 0.7, 0.65, 1.0)
		var lines: String = ""
		for i: int in range(mini(errors.size(), 8)):
			lines += "• %s\n" % errors[i]
		if errors.size() > 8:
			lines += "• … +%d more" % (errors.size() - 8)
		_errors.text = lines.strip_edges()
		_errors.visible = not lines.is_empty()

	_highlight_tool(tool_mode)
	if _btn_test != null:
		_btn_test.disabled = not valid
		_btn_test.modulate = Color(1, 1, 1, 1) if valid else Color(1, 1, 1, 0.45)


func set_flash_status(text: String, is_error: bool) -> void:
	_status.text = text
	_status.modulate = Color(1.0, 0.45, 0.4, 1.0) if is_error else Color(0.65, 0.9, 1.0, 1.0)
	_flash_timer = 2.8


## Returns a named section body for future controls (tools, file, test, …).
func get_section(section_id: StringName) -> VBoxContainer:
	return _sections.get(section_id, null) as VBoxContainer


## Append a control under an existing section (creates section if missing).
func add_to_section(section_id: StringName, control: Control) -> void:
	var box: VBoxContainer = get_section(section_id)
	if box == null and _body != null:
		box = _ensure_section(section_id, String(section_id).capitalize(), _body)
	if box != null and control != null:
		box.add_child(control)


func _highlight_tool(tool_mode: int) -> void:
	_style_tool_btn(_btn_paint, tool_mode == PathDevMode.ToolMode.PAINT, Color(0.95, 0.85, 0.35))
	_style_tool_btn(_btn_spawn, tool_mode == PathDevMode.ToolMode.SPAWN, Color(0.35, 0.95, 0.6))
	_style_tool_btn(_btn_core, tool_mode == PathDevMode.ToolMode.CORE, Color(0.95, 0.45, 0.85))


func _style_tool_btn(btn: Button, active: bool, accent: Color) -> void:
	if btn == null:
		return
	if active:
		btn.modulate = Color(1.15, 1.15, 1.15, 1.0)
		btn.add_theme_color_override("font_color", accent)
	else:
		btn.modulate = Color(1, 1, 1, 1)
		btn.remove_theme_color_override("font_color")


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.position = PANEL_DEFAULT_POS
	_panel.custom_minimum_size = PANEL_MIN
	_panel.size = PANEL_DEFAULT_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_root.add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	_panel.add_child(outer)

	_header = _build_header()
	outer.add_child(_header)

	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.add_theme_constant_override("separation", 10)
	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 10)
	body_margin.add_theme_constant_override("margin_right", 10)
	body_margin.add_theme_constant_override("margin_top", 8)
	body_margin.add_theme_constant_override("margin_bottom", 10)
	body_margin.add_child(_body)
	outer.add_child(body_margin)

	_build_path_section(_body)
	_build_tools_section(_body)
	_build_validation_section(_body)
	_build_file_section(_body)
	_build_test_section(_body)
	_build_shortcuts_footer(_body)


func _build_header() -> PanelContainer:
	var header := PanelContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.custom_minimum_size = Vector2(0, 36)
	header.add_theme_stylebox_override("panel", _make_header_style())
	header.gui_input.connect(_on_header_gui_input)
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	header.add_child(row)

	var grip := Label.new()
	grip.text = "⠿"
	grip.modulate = Color(0.55, 0.75, 0.95, 0.85)
	grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(grip)

	_title = Label.new()
	_title.text = "PATH DEV"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 15)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_title)

	_valid_badge = Label.new()
	_valid_badge.text = "—"
	_valid_badge.add_theme_font_size_override("font_size", 12)
	_valid_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_valid_badge)

	_btn_collapse = Button.new()
	_btn_collapse.text = "▾"
	_btn_collapse.custom_minimum_size = Vector2(28, 24)
	_btn_collapse.tooltip_text = "Collapse / expand panel body"
	_btn_collapse.pressed.connect(_toggle_collapsed)
	row.add_child(_btn_collapse)

	return header


func _build_path_section(parent: VBoxContainer) -> void:
	var box := _ensure_section(&"path", "PATH", parent)
	_meta_cells = _make_mono_label("Cells   0")
	_meta_spawn = _make_mono_label("Spawn  (-1, -1)")
	_meta_core = _make_mono_label("Core    (-1, -1)")
	box.add_child(_meta_cells)
	box.add_child(_meta_spawn)
	box.add_child(_meta_core)


func _build_tools_section(parent: VBoxContainer) -> void:
	var box := _ensure_section(&"tools", "TOOLS", parent)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	_btn_paint = _make_btn("Paint  1", row, func() -> void: tool_paint_pressed.emit())
	_btn_spawn = _make_btn("Spawn  2", row, func() -> void: tool_spawn_pressed.emit())
	_btn_core = _make_btn("Core  3", row, func() -> void: tool_core_pressed.emit())
	_btn_paint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_spawn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_core.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint := Label.new()
	hint.text = "LMB add / assign   ·   RMB erase cell"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(0.7, 0.8, 0.9, 0.75)
	box.add_child(hint)


func _build_validation_section(parent: VBoxContainer) -> void:
	var box := _ensure_section(&"validation", "VALIDATION", parent)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	box.add_child(_status)
	_errors = RichTextLabel.new()
	_errors.fit_content = true
	_errors.scroll_active = false
	_errors.bbcode_enabled = false
	_errors.custom_minimum_size = Vector2(0, 0)
	_errors.add_theme_font_size_override("normal_font_size", 11)
	_errors.modulate = Color(1.0, 0.7, 0.65, 1.0)
	box.add_child(_errors)


func _build_file_section(parent: VBoxContainer) -> void:
	var box := _ensure_section(&"file", "FILE", parent)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var b_save := _make_btn("Save  S", row, func() -> void: save_pressed.emit())
	var b_load := _make_btn("Load  L", row, func() -> void: load_pressed.emit())
	var b_clear := _make_btn("Clear", row, func() -> void: clear_pressed.emit())
	b_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var path_hint := Label.new()
	path_hint.text = "user://dev_paths/path_dev.tres"
	path_hint.add_theme_font_size_override("font_size", 10)
	path_hint.modulate = Color(0.55, 0.7, 0.85, 0.7)
	box.add_child(path_hint)


func _build_test_section(parent: VBoxContainer) -> void:
	var box := _ensure_section(&"test", "PLAYTEST", parent)
	_btn_test = _make_btn("TEST WAVE", box, func() -> void: test_wave_pressed.emit())
	_btn_test.custom_minimum_size = Vector2(0, 34)
	_btn_test.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _build_shortcuts_footer(parent: VBoxContainer) -> void:
	_shortcuts = Label.new()
	_shortcuts.text = "F1 toggle  ·  drag title bar to move"
	_shortcuts.add_theme_font_size_override("font_size", 10)
	_shortcuts.modulate = Color(0.55, 0.65, 0.8, 0.65)
	_shortcuts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(_shortcuts)


func _ensure_section(section_id: StringName, title: String, parent: VBoxContainer) -> VBoxContainer:
	if _sections.has(section_id):
		return _sections[section_id] as VBoxContainer

	var wrap := VBoxContainer.new()
	wrap.name = "Section_%s" % String(section_id)
	wrap.add_theme_constant_override("separation", 4)
	parent.add_child(wrap)

	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 11)
	head.modulate = Color(0.55, 0.8, 1.0, 0.9)
	wrap.add_child(head)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.35, 0.55, 0.75, 0.35)
	wrap.add_child(rule)

	var body := VBoxContainer.new()
	body.name = "Content"
	body.add_theme_constant_override("separation", 4)
	wrap.add_child(body)
	_sections[section_id] = body
	return body


func _make_mono_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(0.85, 0.9, 0.98, 0.95)
	return label


func _make_btn(text: String, parent: Node, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(cb)
	parent.add_child(btn)
	return btn


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.94)
	style.border_color = Color(0.35, 0.7, 0.95, 0.75)
	style.set_border_width_all(1)
	style.border_width_top = 0
	style.set_corner_radius_all(8)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style


func _make_header_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.16, 0.26, 0.98)
	style.border_color = Color(0.4, 0.75, 1.0, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_dragging = true
				_drag_offset = _panel.get_global_mouse_position() - _panel.global_position
				_panel.z_index = 10
			else:
				_dragging = false
				_panel.z_index = 0
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_follow_drag()
		get_viewport().set_input_as_handled()


func _follow_drag() -> void:
	if _panel == null or _root == null:
		return
	var target: Vector2 = _panel.get_global_mouse_position() - _drag_offset
	var viewport_size: Vector2 = _root.get_viewport_rect().size
	var panel_size: Vector2 = _panel.size
	if panel_size.x < 1.0 or panel_size.y < 1.0:
		panel_size = PANEL_DEFAULT_SIZE
	target.x = clampf(target.x, 0.0, maxf(viewport_size.x - panel_size.x, 0.0))
	target.y = clampf(target.y, 0.0, maxf(viewport_size.y - panel_size.y, 0.0))
	_panel.global_position = target


func _toggle_collapsed() -> void:
	_collapsed = not _collapsed
	if _body != null and _body.get_parent() != null:
		(_body.get_parent() as Control).visible = not _collapsed
	_btn_collapse.text = "▸" if _collapsed else "▾"
	if _collapsed:
		_panel.size = Vector2(_panel.size.x, 40)
	else:
		_panel.size = PANEL_DEFAULT_SIZE
		_clamp_panel_to_viewport()


func _clamp_panel_to_viewport() -> void:
	if _panel == null or _root == null:
		return
	var viewport_size: Vector2 = _root.get_viewport_rect().size
	var pos: Vector2 = _panel.position
	pos.x = clampf(pos.x, 0.0, maxf(viewport_size.x - _panel.size.x, 0.0))
	pos.y = clampf(pos.y, 0.0, maxf(viewport_size.y - _panel.size.y, 0.0))
	_panel.position = pos
