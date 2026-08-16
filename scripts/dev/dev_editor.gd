## Full Dev Level Editor (F1). Debug/editor builds only.
## Owns tools, EditorMapData session, playtest/ESC, and history.
class_name DevEditor
extends Node

signal active_changed(active: bool)

const PATH_COLORS: Array[Color] = [
	Color(0.95, 0.35, 0.7),
	Color(0.35, 0.85, 0.95),
	Color(0.95, 0.75, 0.3),
	Color(0.55, 0.95, 0.45),
	Color(0.75, 0.45, 0.95),
	Color(0.95, 0.5, 0.35),
]

@export var grid: GridManager
@export var wave_manager: WaveManager
@export var path_visual: PathVisual
@export var planting_visual: PlantingAreaVisual
@export var core: Core
@export var overlay: EditorOverlay
@export var ui: EditorUI

var is_active: bool = false
var is_playtesting: bool = false

var _map: EditorMapData
var _history: EditorHistory = EditorHistory.new()
var _tool: int = EditorUI.ToolId.PATH
var _active_path: int = 0
var _active_wave: int = 0
var _status: String = "F1 Dev Level Editor"
var _validation_ok: bool = false
var _validation_errors: PackedStringArray = PackedStringArray()
var _grid_was_debug: bool = false
var _drag_path_idx: int = -1
var _drag_cell_idx: int = -1
var _drag_slot_idx: int = -1
var _object_cycle: int = 0
var _plant_cycle: int = 0
var _pre_playtest_snapshot: EditorMapData = null
var _blocked_by_wave_designer: bool = false


func get_or_bootstrap_map() -> EditorMapData:
	if _map == null:
		_map = EditorMapData.new()
		_ensure_one_path()
	if _map.paths.is_empty() or _map.paths[0].cells.is_empty():
		_bootstrap_from_level()
	return _map


func replace_map(map: EditorMapData) -> void:
	if map == null:
		return
	_map = map
	_ensure_one_path()
	if is_active and not _blocked_by_wave_designer:
		_revalidate_and_refresh()


func set_blocked_by_wave_designer(blocked: bool) -> void:
	_blocked_by_wave_designer = blocked
	if blocked:
		if ui != null:
			ui.set_active(false)
		if overlay != null:
			overlay.visible = false
	elif is_active:
		if ui != null:
			ui.set_active(true)
		if overlay != null:
			overlay.visible = true
			overlay.set_map(_map)


func _ready() -> void:
	add_to_group("path_dev_mode")
	add_to_group("dev_editor")
	set_process_unhandled_input(true)
	if not _is_editor_allowed():
		set_process_unhandled_input(false)
		set_process(false)
		return
	if overlay != null:
		overlay.visible = false
		overlay.grid = grid
	if ui != null:
		ui.set_active(false)
		_connect_ui()
	_map = EditorMapData.new()
	_ensure_one_path()


func _is_editor_allowed() -> bool:
	return OS.is_debug_build() or OS.has_feature("editor")


func _close_research_designer() -> void:
	if get_tree() == null:
		return
	for n: Node in get_tree().get_nodes_in_group("research_designer"):
		if n.has_method("set_active"):
			n.call("set_active", false)


func _connect_ui() -> void:
	ui.tool_selected.connect(_on_tool_selected)
	ui.playtest_pressed.connect(enter_playtest)
	ui.save_pressed.connect(save_map)
	ui.load_pressed.connect(load_map)
	ui.new_pressed.connect(new_map)
	ui.undo_pressed.connect(undo)
	ui.redo_pressed.connect(redo)
	ui.path_add_pressed.connect(add_path)
	ui.path_delete_pressed.connect(delete_path)
	ui.path_reverse_pressed.connect(reverse_path)
	ui.path_duplicate_pressed.connect(duplicate_path)
	ui.wave_add_pressed.connect(add_wave)
	ui.wave_duplicate_pressed.connect(duplicate_wave)
	ui.wave_delete_pressed.connect(delete_wave)
	ui.wave_test_pressed.connect(test_selected_wave)
	ui.path_index_selected.connect(func(i: int) -> void:
		_active_path = i
		_refresh_all()
	)
	ui.wave_index_selected.connect(func(i: int) -> void:
		_active_wave = i
		_refresh_all()
	)
	ui.inspector_changed.connect(func() -> void:
		_push_history("inspector")
		_revalidate()
		_apply_preview_paths()
		_refresh_light()
	)
	ui.debug_toggled.connect(_on_debug_toggled)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_editor_allowed():
		return
	if _blocked_by_wave_designer:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_F1:
			if is_playtesting:
				exit_playtest()
			else:
				set_active(not is_active)
			get_viewport().set_input_as_handled()
			return
		if is_playtesting and key.keycode == KEY_ESCAPE:
			exit_playtest()
			get_viewport().set_input_as_handled()
			return
		if not is_active or is_playtesting:
			return
		match key.keycode:
			KEY_Z:
				if key.ctrl_pressed:
					undo()
					get_viewport().set_input_as_handled()
			KEY_Y:
				if key.ctrl_pressed:
					redo()
					get_viewport().set_input_as_handled()
			KEY_S:
				if key.ctrl_pressed:
					save_map()
					get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				set_active(false)
				get_viewport().set_input_as_handled()
		return

	if not is_active or is_playtesting or grid == null:
		return

	if event is InputEventMouseMotion:
		var cell: Vector2i = grid.world_to_grid(grid.get_global_mouse_position())
		var in_b: bool = grid.is_in_bounds(cell)
		if overlay != null:
			overlay.set_hover(cell if in_b else Vector2i(-1, -1))
		if _drag_path_idx >= 0:
			_continue_path_drag(cell if in_b else Vector2i(-1, -1))
		elif _drag_slot_idx >= 0 and in_b:
			_continue_slot_drag(cell)
		return

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		var cell2: Vector2i = grid.world_to_grid(grid.get_global_mouse_position())
		if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
			_end_drags()
			return
		if not mouse.pressed or not grid.is_in_bounds(cell2):
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_handle_left(cell2, mouse.shift_pressed)
			get_viewport().set_input_as_handled()
		elif mouse.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right(cell2)
			get_viewport().set_input_as_handled()


func set_active(active: bool) -> void:
	if not _is_editor_allowed():
		return
	if is_playtesting and active:
		return
	if is_active == active:
		return
	is_active = active
	if is_active:
		_close_research_designer()
		_enter()
	else:
		_exit()
	active_changed.emit(is_active)


func _enter() -> void:
	if grid != null:
		_grid_was_debug = grid.show_debug_grid
		grid.show_debug_grid = true
		grid.debug_line_color = Color(0.55, 0.85, 1.0, 0.35)
	_bootstrap_from_level()
	_history.clear()
	_push_history("enter")
	if overlay != null:
		overlay.visible = true
		overlay.grid = grid
		overlay.set_map(_map)
	if ui != null:
		ui.set_active(true)
		ui.set_tool(_tool)
	_revalidate_and_refresh()


func _exit() -> void:
	_end_drags()
	if grid != null:
		grid.show_debug_grid = _grid_was_debug
		grid.debug_line_color = Color(1, 1, 1, 0.16)
	if overlay != null:
		overlay.visible = false
		overlay.set_hover(Vector2i(-1, -1))
	if ui != null:
		ui.set_active(false)


func _bootstrap_from_level() -> void:
	if _map != null and not _map.paths.is_empty() and not _map.paths[0].cells.is_empty():
		return
	_map = EditorMapData.new()
	_map.map_id = &"dev_level"
	_map.map_name = "Dev Level"
	_map.restrict_build_to_slots = true
	_map.placement_mode = EditorMapData.PlacementMode.SLOTS_ONLY
	if grid != null:
		_map.grid_columns = grid.columns
		_map.grid_rows = grid.rows
		_map.cell_size = grid.cell_size
	if wave_manager != null:
		var level: LevelData = wave_manager.get_level_data()
		if level != null:
			_map.starting_bio_energy = level.starting_bio_energy
			_map.nucleus_max_health = level.nucleus_max_health
			_map.level_hp_multiplier = level.level_hp_multiplier
			_map.level_speed_multiplier = level.level_speed_multiplier
			_map.level_core_damage_multiplier = level.level_core_damage_multiplier
			_map.grid_columns = level.grid_columns
			_map.grid_rows = level.grid_rows
			var all_paths: Array[GridPathData] = level.get_all_paths()
			var pi: int = 0
			for gp: GridPathData in all_paths:
				if gp == null or gp.cells.is_empty():
					continue
				var ep := EditorPathData.new()
				ep.path_id = gp.path_id if gp.path_id != &"" else StringName("path_%d" % (pi + 1))
				ep.display_name = String(ep.path_id)
				ep.cells = gp.cells.duplicate()
				ep.color = PATH_COLORS[pi % PATH_COLORS.size()]
				_map.paths.append(ep)
				pi += 1
			if _map.waves.is_empty() and level.uses_authored_waves():
				for aw: WaveData in level.authored_waves:
					if aw != null:
						_map.waves.append(aw.duplicate(true) as WaveData)
			if _map.available_enemy_ids.is_empty():
				for insect: InsectData in level.get_enemy_pool():
					if insect != null and insect.insect_id != &"":
						_map.available_enemy_ids.append(insect.insect_id)
	_ensure_one_path()
	_active_path = 0
	_active_wave = 0


func _ensure_one_path() -> void:
	if _map.paths.is_empty():
		var p := EditorPathData.new()
		p.path_id = &"path_1"
		p.display_name = "Path 1"
		p.color = PATH_COLORS[0]
		_map.paths.append(p)


func _on_tool_selected(tool_id: StringName) -> void:
	match String(tool_id):
		"select":
			_tool = EditorUI.ToolId.SELECT
		"path":
			_tool = EditorUI.ToolId.PATH
		"spawn":
			_tool = EditorUI.ToolId.SPAWN
		"turret":
			_tool = EditorUI.ToolId.TURRET
		"obstacle":
			_tool = EditorUI.ToolId.OBSTACLE
		"object":
			_tool = EditorUI.ToolId.OBJECT
		"wave":
			_tool = EditorUI.ToolId.WAVE
		"eraser":
			_tool = EditorUI.ToolId.ERASER
	if ui != null:
		ui.set_tool(_tool)


func _on_debug_toggled(flag: StringName, enabled: bool) -> void:
	if overlay == null:
		return
	match String(flag):
		"grid":
			overlay.show_grid = enabled
		"path_dir":
			overlay.show_path_dir = enabled
		"path_id":
			overlay.show_path_id = enabled
		"slots":
			overlay.show_slots = enabled
		"blocked":
			overlay.show_blocked = enabled
		"ranges":
			overlay.show_ranges = enabled
	overlay.queue_redraw()


func _handle_left(cell: Vector2i, shift: bool) -> void:
	match _tool:
		EditorUI.ToolId.SELECT:
			_select_at(cell)
		EditorUI.ToolId.PATH:
			_path_left(cell)
		EditorUI.ToolId.SPAWN:
			_set_spawn(cell)
		EditorUI.ToolId.TURRET:
			_turret_left(cell)
		EditorUI.ToolId.OBSTACLE:
			_obstacle_left(cell, shift)
		EditorUI.ToolId.OBJECT:
			_object_left(cell)
		EditorUI.ToolId.WAVE:
			_select_at(cell)
		EditorUI.ToolId.ERASER:
			_erase_at(cell)


func _handle_right(cell: Vector2i) -> void:
	match _tool:
		EditorUI.ToolId.PATH, EditorUI.ToolId.SPAWN:
			_path_remove(cell)
		EditorUI.ToolId.TURRET:
			_turret_erase(cell)
		EditorUI.ToolId.OBSTACLE:
			_obstacle_erase(cell)
		EditorUI.ToolId.OBJECT:
			_object_erase(cell)
		EditorUI.ToolId.ERASER:
			_erase_at(cell)
		_:
			_erase_at(cell)


func _active_editor_path() -> EditorPathData:
	if _active_path < 0 or _active_path >= _map.paths.size():
		return null
	return _map.paths[_active_path]


func _path_left(cell: Vector2i) -> void:
	if _map.is_blocked(cell):
		_flash("Blocked cell — cannot paint path.", true)
		return
	var path: EditorPathData = _active_editor_path()
	if path == null:
		return
	# Start drag if clicking existing node.
	var idx: int = path.cells.find(cell)
	if idx >= 0:
		_drag_path_idx = _active_path
		_drag_cell_idx = idx
		return
	if path.cells.is_empty():
		path.cells.append(cell)
		_push_history("path_paint")
		_flash("Path started at %s." % str(cell), false)
		_revalidate_and_refresh()
		return
	var last: Vector2i = path.cells[path.cells.size() - 1]
	if absi(last.x - cell.x) + absi(last.y - cell.y) != 1:
		_flash("Must be orthogonal neighbor of path end %s." % str(last), true)
		return
	if path.cells.has(cell):
		_flash("Cell already on path.", true)
		return
	path.cells.append(cell)
	_push_history("path_paint")
	_flash("Added %s (len %d)." % [str(cell), path.cells.size()], false)
	_revalidate_and_refresh()


func _path_remove(cell: Vector2i) -> void:
	var path: EditorPathData = _active_editor_path()
	if path == null:
		return
	var idx: int = path.cells.find(cell)
	if idx < 0:
		_flash("Cell not on active path.", true)
		return
	path.cells.remove_at(idx)
	_push_history("path_erase")
	_flash("Removed %s." % str(cell), false)
	_revalidate_and_refresh()


func _set_spawn(cell: Vector2i) -> void:
	var path: EditorPathData = _active_editor_path()
	if path == null:
		return
	if path.cells.is_empty():
		path.cells.append(cell)
	elif path.cells[0] != cell:
		var idx: int = path.cells.find(cell)
		if idx >= 0:
			var rebuilt: Array[Vector2i] = []
			for i: int in range(idx, path.cells.size()):
				rebuilt.append(path.cells[i])
			path.cells = rebuilt
		elif absi(path.cells[0].x - cell.x) + absi(path.cells[0].y - cell.y) == 1:
			path.cells.insert(0, cell)
		else:
			_flash("Spawn must be on path or adjacent to start.", true)
			return
	_push_history("set_spawn")
	_flash("Spawn → %s" % str(cell), false)
	_revalidate_and_refresh()


func _continue_path_drag(cell: Vector2i) -> void:
	if cell.x < 0 or _drag_path_idx < 0 or _drag_path_idx >= _map.paths.size():
		return
	if _map.is_blocked(cell):
		return
	var path: EditorPathData = _map.paths[_drag_path_idx]
	if path == null or _drag_cell_idx < 0 or _drag_cell_idx >= path.cells.size():
		return
	if path.cells[_drag_cell_idx] == cell:
		return
	if path.cells.has(cell):
		return
	# Neighbor constraint vs adjacent path nodes.
	var ok: bool = true
	if _drag_cell_idx > 0:
		var prev: Vector2i = path.cells[_drag_cell_idx - 1]
		if absi(prev.x - cell.x) + absi(prev.y - cell.y) != 1:
			ok = false
	if _drag_cell_idx < path.cells.size() - 1:
		var nxt: Vector2i = path.cells[_drag_cell_idx + 1]
		if absi(nxt.x - cell.x) + absi(nxt.y - cell.y) != 1:
			ok = false
	if not ok:
		return
	if _drag_cell_idx == 0 and path.cells.size() == 1:
		pass
	path.cells[_drag_cell_idx] = cell
	_revalidate_and_refresh()


func _turret_left(cell: Vector2i) -> void:
	if _is_on_any_path(cell):
		_flash("Cannot place slot on path.", true)
		return
	var existing: EditorTurretSlot = _map.find_slot_at(cell)
	if existing != null:
		_drag_slot_idx = _map.turret_slots.find(existing)
		if ui != null:
			ui.set_selected_slot(existing)
		return
	var slot := EditorTurretSlot.new()
	slot.cell = cell
	slot.enabled = true
	slot.starts_active = false
	var plants: Array[StringName] = _map.available_plant_ids
	if not plants.is_empty():
		slot.plant_id = plants[_plant_cycle % plants.size()]
		_plant_cycle += 1
	_map.turret_slots.append(slot)
	_push_history("turret_add")
	_flash("Slot at %s (%s)." % [str(cell), String(slot.plant_id)], false)
	_revalidate_and_refresh()


func _continue_slot_drag(cell: Vector2i) -> void:
	if _drag_slot_idx < 0 or _drag_slot_idx >= _map.turret_slots.size():
		return
	if _is_on_any_path(cell) or _map.is_blocked(cell):
		return
	if _map.find_slot_at(cell) != null and _map.turret_slots[_drag_slot_idx].cell != cell:
		return
	_map.turret_slots[_drag_slot_idx].cell = cell
	_revalidate_and_refresh()


func _turret_erase(cell: Vector2i) -> void:
	var slot: EditorTurretSlot = _map.find_slot_at(cell)
	if slot == null:
		return
	_map.turret_slots.erase(slot)
	_push_history("turret_erase")
	_flash("Removed slot %s." % str(cell), false)
	_revalidate_and_refresh()


func _obstacle_left(cell: Vector2i, as_non_buildable: bool) -> void:
	if _is_on_any_path(cell):
		_flash("Clear path cells before blocking.", true)
		return
	if as_non_buildable:
		_map.set_non_buildable(cell, true)
		_map.set_blocked(cell, false)
		_flash("Non-buildable %s." % str(cell), false)
	else:
		_map.set_blocked(cell, true)
		_flash("Blocked %s." % str(cell), false)
	_push_history("obstacle")
	_revalidate_and_refresh()


func _obstacle_erase(cell: Vector2i) -> void:
	_map.set_blocked(cell, false)
	_map.set_non_buildable(cell, false)
	_push_history("obstacle_erase")
	_flash("Cleared flags %s." % str(cell), false)
	_revalidate_and_refresh()


func _object_left(cell: Vector2i) -> void:
	if _is_on_any_path(cell):
		_flash("Cannot place object on path.", true)
		return
	for o: EditorPlacedObject in _map.placed_objects:
		if o != null and o.cell == cell:
			_flash("Object already here.", true)
			return
	var obj := EditorPlacedObject.new()
	obj.cell = cell
	obj.object_id = StringName("obj_%d_%d" % [cell.x, cell.y])
	match _object_cycle % 4:
		0:
			obj.kind = EditorPlacedObject.ObjectKind.ORGANELLE
			obj.data_id = &"mitochondrion"
		1:
			obj.kind = EditorPlacedObject.ObjectKind.ORGANELLE
			obj.data_id = &"ribosome"
		2:
			obj.kind = EditorPlacedObject.ObjectKind.GENERATOR
			obj.data_id = &"clover"
		_:
			obj.kind = EditorPlacedObject.ObjectKind.RESEARCH_POINT
			obj.data_id = &"research_stub"
	_object_cycle += 1
	_map.placed_objects.append(obj)
	_push_history("object_add")
	_flash("Placed %s at %s." % [String(obj.data_id), str(cell)], false)
	_revalidate_and_refresh()


func _object_erase(cell: Vector2i) -> void:
	for i: int in range(_map.placed_objects.size() - 1, -1, -1):
		var o: EditorPlacedObject = _map.placed_objects[i]
		if o != null and o.cell == cell:
			_map.placed_objects.remove_at(i)
			_push_history("object_erase")
			_flash("Removed object %s." % str(cell), false)
			_revalidate_and_refresh()
			return


func _erase_at(cell: Vector2i) -> void:
	_turret_erase(cell)
	_object_erase(cell)
	_obstacle_erase(cell)
	_path_remove(cell)


func _select_at(cell: Vector2i) -> void:
	if overlay != null:
		overlay.set_selected_cell(cell)
	var slot: EditorTurretSlot = _map.find_slot_at(cell)
	if slot != null:
		if ui != null:
			ui.set_selected_slot(slot)
		return
	for i: int in range(_map.paths.size()):
		var p: EditorPathData = _map.paths[i]
		if p != null and p.cells.has(cell):
			_active_path = i
			if ui != null:
				ui.show_selection("Path %s" % String(p.path_id))
			_refresh_all()
			return
	for o: EditorPlacedObject in _map.placed_objects:
		if o != null and o.cell == cell:
			if ui != null:
				ui.show_selection("Object %s" % String(o.data_id))
			return
	if ui != null:
		ui.show_selection("Cell %s" % str(cell))


func _is_on_any_path(cell: Vector2i) -> bool:
	for p: EditorPathData in _map.paths:
		if p != null and p.cells.has(cell):
			return true
	return false


func _end_drags() -> void:
	if _drag_path_idx >= 0 or _drag_slot_idx >= 0:
		_push_history("drag")
	_drag_path_idx = -1
	_drag_cell_idx = -1
	_drag_slot_idx = -1


# --- Path library ---

func add_path() -> void:
	var p := EditorPathData.new()
	var n: int = _map.paths.size() + 1
	p.path_id = StringName("path_%d" % n)
	p.display_name = "Path %d" % n
	p.color = PATH_COLORS[(_map.paths.size()) % PATH_COLORS.size()]
	_map.paths.append(p)
	_active_path = _map.paths.size() - 1
	_push_history("path_add")
	_flash("Added %s." % String(p.path_id), false)
	_revalidate_and_refresh()


func delete_path() -> void:
	if _map.paths.size() <= 1:
		_flash("Keep at least one path.", true)
		return
	_map.paths.remove_at(_active_path)
	_active_path = clampi(_active_path, 0, _map.paths.size() - 1)
	_push_history("path_delete")
	_flash("Path deleted.", false)
	_revalidate_and_refresh()


func reverse_path() -> void:
	var path: EditorPathData = _active_editor_path()
	if path == null or path.cells.size() < 2:
		return
	path.cells.reverse()
	_push_history("path_reverse")
	_flash("Path reversed.", false)
	_revalidate_and_refresh()


func duplicate_path() -> void:
	var path: EditorPathData = _active_editor_path()
	if path == null:
		return
	var copy: EditorPathData = path.clone_deep()
	copy.path_id = StringName(String(path.path_id) + "_copy")
	copy.display_name = path.display_name + " Copy"
	copy.color = PATH_COLORS[_map.paths.size() % PATH_COLORS.size()]
	_map.paths.append(copy)
	_active_path = _map.paths.size() - 1
	_push_history("path_dup")
	_flash("Duplicated path.", false)
	_revalidate_and_refresh()


# --- Waves ---

func add_wave() -> void:
	var w := WaveData.new()
	w.wave_number = _map.waves.size() + 1
	w.display_name = "Wave %d" % w.wave_number
	w.insect_count = 5
	w.spawn_interval = 1.0
	w.hp_multiplier = 1.0
	w.speed_multiplier = 1.0
	var path: EditorPathData = _active_editor_path()
	if path != null:
		w.path_id = path.path_id
	w.insect_data = _default_insect()
	_map.waves.append(w)
	_active_wave = _map.waves.size() - 1
	_push_history("wave_add")
	_flash("Added wave %d." % w.wave_number, false)
	_revalidate_and_refresh()


func duplicate_wave() -> void:
	if _active_wave < 0 or _active_wave >= _map.waves.size():
		return
	var src: WaveData = _map.waves[_active_wave]
	var copy: WaveData = src.duplicate(true) as WaveData
	copy.wave_number = _map.waves.size() + 1
	_map.waves.append(copy)
	_active_wave = _map.waves.size() - 1
	_push_history("wave_dup")
	_flash("Duplicated wave.", false)
	_revalidate_and_refresh()


func delete_wave() -> void:
	if _active_wave < 0 or _active_wave >= _map.waves.size():
		return
	_map.waves.remove_at(_active_wave)
	_active_wave = clampi(_active_wave, 0, maxi(_map.waves.size() - 1, 0))
	_push_history("wave_delete")
	_flash("Wave deleted.", false)
	_revalidate_and_refresh()


func _default_insect() -> InsectData:
	var path: String = "res://data/insects/ant.tres"
	if ResourceLoader.exists(path):
		return load(path) as InsectData
	return null


func test_selected_wave() -> void:
	if not _validation_ok:
		_flash("Fix path validation before testing wave.", true)
		return
	if _map.waves.is_empty() or _active_wave < 0 or _active_wave >= _map.waves.size():
		_flash("No wave selected.", true)
		return
	if wave_manager == null:
		_flash("WaveManager missing.", true)
		return
	if not EditorMapApplier.apply(_map, get_parent()):
		_flash("Failed to apply map.", true)
		return
	_clear_insects()
	var wave: WaveData = _map.waves[_active_wave]
	wave_manager.start_authored_wave_number(wave.wave_number)
	_flash("Testing wave %d." % wave.wave_number, false)


# --- Playtest ---

func enter_playtest() -> void:
	if not is_active or is_playtesting:
		return
	if not _validation_ok:
		_flash("Playtest blocked — fix validation.", true)
		_refresh_all()
		return
	if _map.waves.is_empty():
		_flash("Add at least one authored wave for playtest.", true)
		return
	_pre_playtest_snapshot = _map.clone_deep()
	if not EditorMapApplier.apply(_map, get_parent()):
		_flash("Apply failed.", true)
		return
	is_playtesting = true
	is_active = false
	if ui != null:
		ui.set_active(false)
	if overlay != null:
		overlay.visible = false
	if grid != null:
		grid.show_debug_grid = _grid_was_debug
	_clear_insects()
	wave_manager.force_idle_for_dev()
	wave_manager.start_authored_wave_number(_map.waves[0].wave_number)
	_flash("Playtest — ESC to return.", false)


func exit_playtest() -> void:
	if not is_playtesting:
		return
	is_playtesting = false
	_clear_insects()
	if wave_manager != null:
		wave_manager.force_idle_for_dev()
	if _pre_playtest_snapshot != null:
		_map = _pre_playtest_snapshot.clone_deep()
		_pre_playtest_snapshot = null
	is_active = true
	_enter()
	_flash("Returned to editor.", false)


# --- Save / Load / New ---

func new_map() -> void:
	_map = EditorMapData.new()
	_map.map_id = &"dev_level"
	_map.map_name = "Dev Level"
	_map.restrict_build_to_slots = true
	if grid != null:
		_map.grid_columns = grid.columns
		_map.grid_rows = grid.rows
		_map.cell_size = grid.cell_size
	_ensure_one_path()
	_active_path = 0
	_active_wave = 0
	_push_history("new")
	_flash("New blank map.", false)
	_revalidate_and_refresh()


func save_map() -> void:
	_revalidate()
	if not _validation_ok:
		_flash("Save blocked — fix validation.", true)
		_refresh_all()
		return
	var err: Error = MapSerializer.save(_map, true)
	if err != OK:
		_flash("Save failed: %s" % error_string(err), true)
		return
	_flash("Saved %s" % MapSerializer.user_path(_map.map_id), false)
	_refresh_all()


func load_map() -> void:
	var loaded: EditorMapData = MapSerializer.load_map(_map.map_id if _map != null else &"dev_level")
	if loaded == null:
		var ids: PackedStringArray = MapSerializer.list_user_maps()
		if not ids.is_empty():
			loaded = MapSerializer.load_map(StringName(ids[0]))
	if loaded == null:
		_flash("No saved map in user://dev_levels/.", true)
		return
	_map = loaded
	_active_path = 0
	_active_wave = 0
	_ensure_one_path()
	_push_history("load")
	_flash("Loaded %s." % String(_map.map_id), false)
	_revalidate_and_refresh()


# --- History ---

func _push_history(label: String) -> void:
	_history.push_snapshot(label, _map)


func undo() -> void:
	if not _history.can_undo():
		_flash("Nothing to undo.", true)
		return
	_map = _history.undo(_map)
	_ensure_one_path()
	_active_path = clampi(_active_path, 0, _map.paths.size() - 1)
	_revalidate_and_refresh()
	_flash("Undo.", false)


func redo() -> void:
	if not _history.can_redo():
		_flash("Nothing to redo.", true)
		return
	_map = _history.redo(_map)
	_ensure_one_path()
	_revalidate_and_refresh()
	_flash("Redo.", false)


# --- Validation / refresh ---

func _revalidate_and_refresh() -> void:
	_revalidate()
	_apply_preview_paths()
	_refresh_all()


func _revalidate() -> void:
	_validation_errors = PackedStringArray()
	if _map == null or grid == null:
		_validation_errors.append("Map/grid missing.")
		_validation_ok = false
		return
	if _map.paths.is_empty():
		_validation_errors.append("Need at least one path.")
	var any_valid_path: bool = false
	for pi: int in range(_map.paths.size()):
		var path: EditorPathData = _map.paths[pi]
		if path == null:
			_validation_errors.append("Null path at %d." % pi)
			continue
		var errs: PackedStringArray = _validate_path(path)
		for e: String in errs:
			_validation_errors.append("%s: %s" % [String(path.path_id), e])
		if errs.is_empty() and path.cells.size() >= 2:
			any_valid_path = true
	if not any_valid_path:
		_validation_errors.append("Need ≥1 valid path (≥2 orthogonal cells).")
	_validation_ok = _validation_errors.is_empty()


func _validate_path(path: EditorPathData) -> PackedStringArray:
	var errs := PackedStringArray()
	if path.cells.size() < 2:
		errs.append("Need at least 2 cells.")
		return errs
	for i: int in range(path.cells.size()):
		var cell: Vector2i = path.cells[i]
		if not grid.is_in_bounds(cell):
			errs.append("Out of bounds %s." % str(cell))
			continue
		if _map.is_blocked(cell):
			errs.append("Blocked cell on path %s." % str(cell))
		if i == 0:
			continue
		var prev: Vector2i = path.cells[i - 1]
		if prev == cell:
			errs.append("Duplicate consecutive %s." % str(cell))
		elif absi(prev.x - cell.x) + absi(prev.y - cell.y) != 1:
			errs.append("Gap %s → %s." % [str(prev), str(cell)])
	if errs.is_empty():
		if not _bfs_reachable(path, path.get_spawn(), path.get_core()):
			errs.append("Spawn cannot reach core.")
	return errs


func _bfs_reachable(path: EditorPathData, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var set_cells: Dictionary = {}
	for cell: Vector2i in path.cells:
		set_cells[cell] = true
	if not set_cells.has(from_cell) or not set_cells.has(to_cell):
		return false
	var q: Array[Vector2i] = [from_cell]
	var seen: Dictionary = {from_cell: true}
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur == to_cell:
			return true
		for d: Vector2i in dirs:
			var nxt: Vector2i = cur + d
			if set_cells.has(nxt) and not seen.has(nxt):
				seen[nxt] = true
				q.append(nxt)
	return false


func _apply_preview_paths() -> void:
	if grid == null or _map == null:
		return
	var paths: Array[GridPathData] = _map.get_all_grid_paths()
	if paths.is_empty():
		# Still show partial paint: use incomplete paths for preview.
		for p: EditorPathData in _map.paths:
			if p != null and not p.cells.is_empty():
				paths.append(p.to_grid_path())
	if paths.is_empty():
		return
	grid.apply_grid_paths(paths)
	if path_visual != null:
		path_visual.apply_grid_paths(paths)
	if planting_visual != null:
		planting_visual.apply_grid_paths(paths)
	_reposition_core(paths[0])


func _reposition_core(primary: GridPathData) -> void:
	if core == null or primary == null or primary.cells.is_empty() or grid == null:
		return
	var visual := core.get_node_or_null("Visual") as Node2D
	if visual != null:
		var end_cell: Vector2i = primary.cells[primary.cells.size() - 1]
		visual.global_position = grid.grid_to_world_center(end_cell) + Vector2(-10.0, 0.0)


func _refresh_all() -> void:
	if overlay != null:
		overlay.grid = grid
		overlay.set_map(_map)
		overlay.set_active_path(_active_path)
	var status: String = _compose_status()
	if ui != null:
		ui.refresh(_map, _active_path, _active_wave, status, _validation_ok)


func _refresh_light() -> void:
	if overlay != null:
		overlay.grid = grid
		overlay.set_map(_map)
		overlay.set_active_path(_active_path)
		overlay.queue_redraw()
	var status: String = _compose_status()
	if ui != null:
		ui.refresh_light(_map, _active_path, _active_wave, status, _validation_ok)


func _compose_status() -> String:
	if not _validation_errors.is_empty():
		var status: String = _validation_errors[0]
		if _validation_errors.size() > 1:
			status += " (+%d)" % (_validation_errors.size() - 1)
		return status
	if _validation_ok and _map != null:
		return "OK — %d path(s), %d wave(s), %d slot(s)" % [
			_map.paths.size(), _map.waves.size(), _map.turret_slots.size()
		]
	return _status


func _flash(text: String, is_error: bool) -> void:
	_status = text
	if ui != null and is_active:
		ui.refresh_light(_map, _active_path, _active_wave, text, not is_error and _validation_ok)


func _clear_insects() -> void:
	if wave_manager == null or wave_manager.insect_layer == null:
		return
	for child: Node in wave_manager.insect_layer.get_children():
		if is_instance_valid(child):
			child.queue_free()
