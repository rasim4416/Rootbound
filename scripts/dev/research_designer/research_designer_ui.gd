## F4 Research Designer chrome: list + graph + inspector.
class_name ResearchDesignerUI
extends CanvasLayer

signal undo_pressed
signal redo_pressed
signal save_pressed
signal save_as_path_chosen(path: String)
signal node_selected(research_id: StringName)
signal catalog_changed()
signal history_commit()
signal add_node_requested(graph_position: Vector2)
signal duplicate_requested(research_id: StringName)
signal delete_requested(research_id: StringName)

const _COL_BG := Color(0.06, 0.08, 0.12, 0.97)
const _COL_HEADER := Color(0.09, 0.12, 0.18, 1.0)
const _COL_BORDER := Color(0.32, 0.62, 0.82, 0.9)
const _COL_ACCENT := Color(0.5, 0.85, 1.0, 1.0)
const _COL_OK := Color(0.55, 0.92, 0.7, 1.0)
const _COL_ERR := Color(1.0, 0.55, 0.48, 1.0)

var graph: ResearchGraph
var _panel: PanelContainer
var _list: ItemList
var _search: LineEdit
var _inspector: VBoxContainer
var _status: Label
var _header: PanelContainer
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _catalog: Array[ResearchData] = []
var _selected_id: StringName = &""
var _issues: Dictionary = {}
var _committing: bool = false
var _building: bool = false
var _id_list: Array[StringName] = []
var _icon_dialog: FileDialog
var _save_as_dialog: FileDialog
var _syncing_list: bool = false


func _ready() -> void:
	layer = 93
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


func refresh(catalog: Array[ResearchData], selected_id: StringName, status: String, ok: bool) -> void:
	_catalog = catalog
	_selected_id = selected_id
	_issues = ResearchValidation.issues_for_catalog(_catalog)
	_set_status(status, ok)
	_refresh_list()
	if graph != null:
		graph.set_catalog(_catalog, _selected_id, _issues)
	_rebuild_inspector()


func refresh_light(catalog: Array[ResearchData], selected_id: StringName, status: String, ok: bool) -> void:
	_catalog = catalog
	_selected_id = selected_id
	_issues = ResearchValidation.issues_for_catalog(_catalog)
	_set_status(status, ok)
	_refresh_list()
	if graph != null:
		graph.set_catalog(_catalog, _selected_id, _issues)


func get_selected_id() -> StringName:
	return _selected_id


func fit_tree() -> void:
	if graph != null:
		graph.fit_tree()


func focus_selected() -> void:
	if graph != null:
		graph.focus_node(_selected_id)


func try_delete_edge() -> bool:
	return graph != null and graph.remove_selected_edge()


func popup_save_as() -> void:
	if _save_as_dialog != null:
		_save_as_dialog.popup_centered_ratio(0.5)


func _set_status(text: String, ok: bool) -> void:
	if _status == null:
		return
	_status.text = text
	_status.modulate = _COL_OK if ok else _COL_ERR


func _layout() -> void:
	if _panel == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(mini(vp.x - 16.0, 1280.0), mini(vp.y - 24.0, 720.0))
	_panel.custom_minimum_size = _panel.size
	if _panel.position == Vector2.ZERO:
		_panel.position = Vector2(8, 16)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.position = Vector2(8, 16)
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
	var title := Label.new()
	title.text = "RESEARCH DESIGNER"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_row.add_child(title)
	var hint := Label.new()
	hint.text = "F4 / Esc"
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
	_status = Label.new()
	_status.text = "Research Designer"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)

	_icon_dialog = FileDialog.new()
	_icon_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_icon_dialog.access = FileDialog.ACCESS_RESOURCES
	_icon_dialog.filters = PackedStringArray(["*.png,*.webp,*.svg ; Images"])
	_icon_dialog.file_selected.connect(_on_icon_picked)
	add_child(_icon_dialog)
	_save_as_dialog = FileDialog.new()
	_save_as_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_as_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_as_dialog.filters = PackedStringArray(["*.tres ; ResearchData"])
	_save_as_dialog.current_dir = "res://data/research"
	_save_as_dialog.file_selected.connect(func(path: String) -> void: save_as_path_chosen.emit(path))
	add_child(_save_as_dialog)
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
	_btn("Undo", row, func() -> void: undo_pressed.emit(), false)
	_btn("Redo", row, func() -> void: redo_pressed.emit(), false)
	_btn("Save", row, func() -> void: save_pressed.emit(), false)
	_btn("Save As", row, func() -> void: popup_save_as(), false)
	_btn("Fit Tree", row, func() -> void: fit_tree(), false)
	_btn("Add Node", row, func() -> void: add_node_requested.emit(Vector2(80, 80)), false)
	_btn("Duplicate", row, func() -> void: duplicate_requested.emit(_selected_id), false)
	_btn("Delete", row, func() -> void: delete_requested.emit(_selected_id), false)
	return scroll


func _build_left() -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(260, 0)
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(_section("Research Nodes"))
	_search = LineEdit.new()
	_search.placeholder_text = "Search research..."
	_search.text_changed.connect(func(_t: String) -> void: _refresh_list())
	wrap.add_child(_search)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(0, 280)
	_list.item_selected.connect(_on_list_selected)
	wrap.add_child(_list)
	return wrap


func _build_middle() -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(_section("Tree"))
	graph = ResearchGraph.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size = Vector2(0, 360)
	graph.node_selected.connect(func(id: StringName) -> void: node_selected.emit(id))
	graph.catalog_mutated.connect(func() -> void: catalog_changed.emit())
	graph.history_commit.connect(func() -> void: history_commit.emit())
	graph.status_message.connect(func(t: String, ok: bool) -> void: _set_status(t, ok))
	graph.add_node_at.connect(func(p: Vector2) -> void: add_node_requested.emit(p))
	graph.duplicate_requested.connect(func(id: StringName) -> void: duplicate_requested.emit(id))
	graph.delete_requested.connect(func(id: StringName) -> void: delete_requested.emit(id))
	wrap.add_child(graph)
	return wrap


func _build_right() -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(320, 0)
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(_section("Inspector"))
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
	return wrap


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_dragging = true
			_drag_offset = get_viewport().get_mouse_position() - _panel.global_position
			get_viewport().set_input_as_handled()


func _on_list_selected(index: int) -> void:
	if _syncing_list:
		return
	if index < 0 or index >= _id_list.size():
		return
	node_selected.emit(_id_list[index])


func _refresh_list() -> void:
	if _list == null:
		return
	var query: String = _search.text.strip_edges().to_lower() if _search != null else ""
	_syncing_list = true
	_list.clear()
	_id_list.clear()
	var select_idx: int = -1
	for data: ResearchData in _catalog:
		if data == null or data.research_id == &"":
			continue
		if not query.is_empty():
			var blob: String = "%s %s %s" % [data.display_name, String(data.research_id), data.description]
			if blob.to_lower().find(query) < 0:
				continue
		var label: String = "%s  T%d  %s" % [
			data.display_name if not data.display_name.is_empty() else String(data.research_id),
			data.tier,
			data.cost_label()
		]
		var idx: int = _list.add_item(label)
		var tex: Texture2D = data.resolve_icon()
		if tex != null:
			_list.set_item_icon(idx, tex)
		if _issues.has(data.research_id):
			_list.set_item_custom_fg_color(idx, _COL_ERR)
		_id_list.append(data.research_id)
		if data.research_id == _selected_id:
			select_idx = idx
	if select_idx >= 0:
		_list.select(select_idx)
	_syncing_list = false


func _current() -> ResearchData:
	for data: ResearchData in _catalog:
		if data != null and data.research_id == _selected_id:
			return data
	return null


func _rebuild_inspector() -> void:
	if _inspector == null or _committing:
		return
	_building = true
	for c: Node in _inspector.get_children():
		_inspector.remove_child(c)
		c.queue_free()
	var data: ResearchData = _current()
	if data == null:
		_label("No node selected")
		_building = false
		return
	if _issues.has(data.research_id):
		var msgs: PackedStringArray = _issues[data.research_id] as PackedStringArray
		_label("⚠  " + ", ".join(msgs), _COL_ERR)
	_label("General")
	_string("display_name", "Name", data.display_name)
	_string("research_id", "ID", String(data.research_id))
	_multiline("description", "Description", data.description)
	_icon_row(data)
	_int("tier", "Tier", data.tier)
	_bool("unlockable", "Unlockable", data.unlockable)
	_bool("unlocked_by_default", "Unlocked by default", data.unlocked_by_default)

	_label("Research Cost")
	for i: int in range(data.costs.size()):
		_cost_row(data, i)
	_btn("Add Cost", _inspector, func() -> void: _add_cost())

	_label("Requirements")
	for i: int in range(data.prerequisite_ids.size()):
		_prereq_row(data, i)
	_btn("Add Requirement", _inspector, func() -> void: _add_prereq())

	_label("Unlocks")
	_protein_row(data)

	_label("Effects")
	_effect_preview(data)
	for i: int in range(data.permanent_modifiers.size()):
		_effect_row(data, i)
	var fx_row := HBoxContainer.new()
	_inspector.add_child(fx_row)
	_btn("Add Effect", fx_row, func() -> void: _add_effect())
	_building = false


func _icon_row(data: ResearchData) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "Icon"
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_item("(default portrait)")
	opt.set_item_metadata(0, "")
	var sel: int = 0
	var portraits: PackedStringArray = ResearchPortraits.list_portrait_ids()
	for i: int in range(portraits.size()):
		opt.add_item(portraits[i])
		opt.set_item_metadata(i + 1, portraits[i])
		if data.icon != null and data.icon.resource_path.ends_with("portrait_%s.png" % portraits[i]):
			sel = i + 1
	opt.select(sel)
	opt.item_selected.connect(func(i: int) -> void:
		var meta: String = String(opt.get_item_metadata(i))
		if meta.is_empty():
			data.icon = null
		else:
			data.icon = ResearchPortraits.get_portrait(StringName(meta))
		_commit()
	)
	row.add_child(opt)
	_btn("Browse…", row, func() -> void: _icon_dialog.popup_centered_ratio(0.6), false)
	_inspector.add_child(row)


func _on_icon_picked(path: String) -> void:
	var data: ResearchData = _current()
	if data == null:
		return
	data.icon = load(path) as Texture2D
	_commit()


func _cost_row(data: ResearchData, index: int) -> void:
	var cost: ResearchCost = data.costs[index]
	if cost == null:
		return
	var row := HBoxContainer.new()
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sel: int = 0
	for i: int in range(ElementIds.ALL.size()):
		var eid: StringName = ElementIds.ALL[i]
		opt.add_item(String(eid))
		opt.set_item_metadata(i, eid)
		if cost.get_element_id() == eid:
			sel = i
	opt.select(sel)
	opt.item_selected.connect(func(i: int) -> void:
		cost.element = ResearchDesignerIO.load_element(opt.get_item_metadata(i) as StringName)
		_commit()
	)
	row.add_child(opt)
	var amt := LineEdit.new()
	amt.text = str(cost.amount)
	amt.custom_minimum_size = Vector2(56, 0)
	amt.text_submitted.connect(func(t: String) -> void:
		cost.amount = maxi(_parse_int(t, cost.amount), 0)
		_commit()
	)
	amt.focus_exited.connect(func() -> void:
		if is_instance_valid(amt):
			cost.amount = maxi(_parse_int(amt.text, cost.amount), 0)
			_commit()
	)
	row.add_child(amt)
	_btn("Delete", row, func() -> void:
		data.costs.remove_at(index)
		_commit(true)
	, false)
	_inspector.add_child(row)


func _prereq_row(data: ResearchData, index: int) -> void:
	var row := HBoxContainer.new()
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current: StringName = data.prerequisite_ids[index]
	var sel: int = 0
	var options: Array[StringName] = []
	for other: ResearchData in _catalog:
		if other == null or other.research_id == &"" or other.research_id == data.research_id:
			continue
		options.append(other.research_id)
	for i: int in range(options.size()):
		opt.add_item(String(options[i]))
		opt.set_item_metadata(i, options[i])
		if options[i] == current:
			sel = i
	if not options.is_empty():
		opt.select(sel)
	opt.item_selected.connect(func(i: int) -> void:
		var next_id: StringName = opt.get_item_metadata(i) as StringName
		if ResearchValidation.would_cycle(_catalog, next_id, data.research_id):
			_set_status("Invalid circular dependency", false)
			return
		data.prerequisite_ids[index] = next_id
		_commit()
	)
	row.add_child(opt)
	_btn("Delete", row, func() -> void:
		data.prerequisite_ids.remove_at(index)
		_commit(true)
	, false)
	_inspector.add_child(row)


func _protein_row(data: ResearchData) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "Protein"
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_item("(none)")
	var sel: int = 0
	var proteins: Array[ProteinData] = ResearchDesignerIO.list_proteins()
	for i: int in range(proteins.size()):
		opt.add_item(proteins[i].display_name if not proteins[i].display_name.is_empty() else String(proteins[i].protein_id))
		if data.protein != null and data.protein.protein_id == proteins[i].protein_id:
			sel = i + 1
	opt.select(sel)
	opt.item_selected.connect(func(i: int) -> void:
		data.protein = proteins[i - 1] if i > 0 else null
		_commit()
	)
	row.add_child(opt)
	_inspector.add_child(row)


func _effect_preview(data: ResearchData) -> void:
	var mods: Array[StatModifier] = []
	for m: StatModifier in data.permanent_modifiers:
		if m != null:
			mods.append(m)
	var final_v: float = StatCalculator.calculate(100.0, mods, [])
	var lines: PackedStringArray = PackedStringArray(["Base: 100"])
	for m: StatModifier in mods:
		if m.modifier_type == StatModifier.ModifierType.ADDITIVE:
			lines.append("%+.0f" % m.value)
		else:
			lines.append("%+.0f%%" % (m.value * 100.0))
	lines.append("Final: %.1f" % final_v)
	_label("Preview\n" + "\n".join(lines), Color(0.75, 0.85, 0.95, 1.0))


func _effect_row(data: ResearchData, index: int) -> void:
	var mod: StatModifier = data.permanent_modifiers[index]
	if mod == null:
		return
	_label("Effect %d  ·  Stat Modifier" % (index + 1))
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)
	var trow := HBoxContainer.new()
	var tl := Label.new()
	tl.text = "Target"
	tl.custom_minimum_size = Vector2(110, 0)
	trow.add_child(tl)
	var topt := OptionButton.new()
	topt.focus_mode = Control.FOCUS_NONE
	topt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stats: Array[StringName] = StatIds.all_ids()
	var sel: int = 0
	for i: int in range(stats.size()):
		topt.add_item(String(stats[i]))
		topt.set_item_metadata(i, stats[i])
		if stats[i] == mod.stat_id:
			sel = i
	if not stats.is_empty():
		topt.select(sel)
	topt.item_selected.connect(func(i: int) -> void:
		mod.stat_id = topt.get_item_metadata(i) as StringName
		_commit()
	)
	trow.add_child(topt)
	wrap.add_child(trow)
	var orow := HBoxContainer.new()
	var ol := Label.new()
	ol.text = "Operation"
	ol.custom_minimum_size = Vector2(110, 0)
	orow.add_child(ol)
	var oopt := OptionButton.new()
	oopt.focus_mode = Control.FOCUS_NONE
	oopt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oopt.add_item("Add")
	oopt.add_item("Percentage")
	oopt.select(0 if mod.modifier_type == StatModifier.ModifierType.ADDITIVE else 1)
	oopt.item_selected.connect(func(i: int) -> void:
		mod.modifier_type = StatModifier.ModifierType.ADDITIVE if i == 0 else StatModifier.ModifierType.MULTIPLICATIVE
		_commit()
	)
	orow.add_child(oopt)
	wrap.add_child(orow)
	var vrow := HBoxContainer.new()
	var vl := Label.new()
	vl.text = "Value"
	vl.custom_minimum_size = Vector2(110, 0)
	vrow.add_child(vl)
	var ved := LineEdit.new()
	if mod.modifier_type == StatModifier.ModifierType.MULTIPLICATIVE:
		ved.text = str(mod.value * 100.0)
		ved.placeholder_text = "% (10 = +10%)"
	else:
		ved.text = str(mod.value)
	ved.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ved.text_submitted.connect(func(t: String) -> void:
		_apply_effect_value(mod, t)
	)
	ved.focus_exited.connect(func() -> void:
		if is_instance_valid(ved):
			_apply_effect_value(mod, ved.text)
	)
	vrow.add_child(ved)
	wrap.add_child(vrow)
	var brow := HBoxContainer.new()
	_btn("Duplicate", brow, func() -> void:
		data.permanent_modifiers.append(mod.duplicate(true) as StatModifier)
		_commit(true)
	)
	_btn("Delete", brow, func() -> void:
		data.permanent_modifiers.remove_at(index)
		_commit(true)
	)
	wrap.add_child(brow)
	_inspector.add_child(wrap)


func _apply_effect_value(mod: StatModifier, text: String) -> void:
	var v: float = _parse_float(text, mod.value)
	if mod.modifier_type == StatModifier.ModifierType.MULTIPLICATIVE:
		mod.value = v / 100.0
	else:
		mod.value = v
	_commit()


func _add_cost() -> void:
	var data: ResearchData = _current()
	if data == null:
		return
	var cost := ResearchCost.new()
	cost.element = ResearchDesignerIO.load_element(ElementIds.CARBON)
	cost.amount = 1
	data.costs.append(cost)
	_commit(true)


func _add_prereq() -> void:
	var data: ResearchData = _current()
	if data == null:
		return
	for other: ResearchData in _catalog:
		if other == null or other.research_id == data.research_id:
			continue
		if data.prerequisite_ids.has(other.research_id):
			continue
		if ResearchValidation.would_cycle(_catalog, other.research_id, data.research_id):
			continue
		data.prerequisite_ids.append(other.research_id)
		_commit(true)
		return
	_set_status("Invalid connection", false)


func _add_effect() -> void:
	var data: ResearchData = _current()
	if data == null:
		return
	var mod := StatModifier.new()
	mod.stat_id = StatIds.DAMAGE
	mod.modifier_type = StatModifier.ModifierType.MULTIPLICATIVE
	mod.value = 0.10
	data.permanent_modifiers.append(mod)
	_commit(true)


func _string(key: String, caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = caption
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


func _multiline(key: String, caption: String, value: String) -> void:
	_label(caption)
	var edit := TextEdit.new()
	edit.text = value
	edit.custom_minimum_size = Vector2(0, 72)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.focus_exited.connect(func() -> void:
		if is_instance_valid(edit):
			_on_field(key, edit.text)
	)
	_inspector.add_child(edit)


func _int(key: String, caption: String, value: int) -> void:
	_string(key, caption, str(value))


func _bool(key: String, caption: String, value: bool) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = caption
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var box := CheckBox.new()
	box.button_pressed = value
	box.focus_mode = Control.FOCUS_NONE
	box.toggled.connect(func(on: bool) -> void: _on_field(key, "1" if on else "0"))
	row.add_child(box)
	_inspector.add_child(row)


func _on_field(key: String, text: String) -> void:
	var data: ResearchData = _current()
	if data == null or _committing or _building:
		return
	match key:
		"display_name":
			data.display_name = text
		"research_id":
			_rename_id(data, StringName(text.strip_edges()))
		"description":
			data.description = text
		"tier":
			data.tier = maxi(_parse_int(text, data.tier), 1)
		"unlockable":
			data.unlockable = text == "1"
		"unlocked_by_default":
			data.unlocked_by_default = text == "1"
	_commit()


func _rename_id(data: ResearchData, new_id: StringName) -> void:
	var old: StringName = data.research_id
	if new_id == &"" or new_id == old:
		return
	for other: ResearchData in _catalog:
		if other != null and other != data and other.research_id == new_id:
			_set_status("Duplicate ID", false)
			return
	data.research_id = new_id
	for other: ResearchData in _catalog:
		if other == null:
			continue
		for i: int in range(other.prerequisite_ids.size()):
			if other.prerequisite_ids[i] == old:
				other.prerequisite_ids[i] = new_id
	_selected_id = new_id


func _commit(rebuild: bool = false) -> void:
	if _building:
		return
	catalog_changed.emit()
	history_commit.emit()
	if rebuild:
		_rebuild_inspector()


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


func _label(text: String, col: Color = _COL_ACCENT) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector.add_child(l)


func _btn(text: String, parent: Node, cb: Callable, expand: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 28)
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _section(t: String) -> Label:
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
