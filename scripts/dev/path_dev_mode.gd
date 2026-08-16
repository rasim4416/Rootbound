## In-game path editor for development (F1). Does not rewrite gameplay systems —
## mutates a working GridPathData and feeds it into existing PathVisual / WaveManager.
class_name PathDevMode
extends Node

signal active_changed(active: bool)
signal state_changed()

enum ToolMode {
	PAINT,
	SPAWN,
	CORE,
}

const SAVE_USER_PATH: String = "user://dev_paths/path_dev.tres"
const SAVE_RES_PATH: String = "res://data/paths/path_dev.tres"
const PATH_SCRIPT: String = "res://scripts/insects/grid_path_data.gd"

@export var grid: GridManager
@export var wave_manager: WaveManager
@export var path_visual: PathVisual
@export var planting_visual: PlantingAreaVisual
@export var core: Core
@export var overlay: PathDevOverlay
@export var hud: PathDevHud

var is_active: bool = false
var tool_mode: ToolMode = ToolMode.PAINT

var _cells: Array[Vector2i] = []
var _spawn: Vector2i = Vector2i(-1, -1)
var _core: Vector2i = Vector2i(-1, -1)
var _validation_ok: bool = false
var _validation_errors: PackedStringArray = PackedStringArray()
var _grid_was_debug: bool = false
var _working_path: GridPathData = null


func _ready() -> void:
	add_to_group("path_dev_mode")
	set_process_unhandled_input(true)
	if overlay != null:
		overlay.visible = false
		overlay.grid = grid
	if hud != null:
		hud.visible = false
		if not hud.tool_paint_pressed.is_connected(_on_tool_paint):
			hud.tool_paint_pressed.connect(_on_tool_paint)
		if not hud.tool_spawn_pressed.is_connected(_on_tool_spawn):
			hud.tool_spawn_pressed.connect(_on_tool_spawn)
		if not hud.tool_core_pressed.is_connected(_on_tool_core):
			hud.tool_core_pressed.connect(_on_tool_core)
		if not hud.test_wave_pressed.is_connected(test_wave):
			hud.test_wave_pressed.connect(test_wave)
		if not hud.save_pressed.is_connected(save_path):
			hud.save_pressed.connect(save_path)
		if not hud.load_pressed.is_connected(load_path):
			hud.load_pressed.connect(load_path)
		if not hud.clear_pressed.is_connected(clear_path):
			hud.clear_pressed.connect(clear_path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_F1:
			set_active(not is_active)
			get_viewport().set_input_as_handled()
			return
		if not is_active:
			return
		match key.keycode:
			KEY_S:
				save_path()
				get_viewport().set_input_as_handled()
			KEY_L:
				load_path()
				get_viewport().set_input_as_handled()
			KEY_1:
				set_tool_mode(ToolMode.PAINT)
				get_viewport().set_input_as_handled()
			KEY_2:
				set_tool_mode(ToolMode.SPAWN)
				get_viewport().set_input_as_handled()
			KEY_3:
				set_tool_mode(ToolMode.CORE)
				get_viewport().set_input_as_handled()
			KEY_C:
				if key.ctrl_pressed:
					clear_path()
					get_viewport().set_input_as_handled()
		return

	if not is_active or grid == null:
		return

	if event is InputEventMouseMotion:
		var cell: Vector2i = grid.world_to_grid(grid.get_global_mouse_position())
		if overlay != null:
			overlay.set_hover(cell if grid.is_in_bounds(cell) else Vector2i(-1, -1))
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse := event as InputEventMouseButton
		var cell: Vector2i = grid.world_to_grid(grid.get_global_mouse_position())
		if not grid.is_in_bounds(cell):
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(cell)
			get_viewport().set_input_as_handled()
		elif mouse.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(cell)
			get_viewport().set_input_as_handled()


func set_active(active: bool) -> void:
	if is_active == active:
		return
	is_active = active
	if is_active:
		_enter()
	else:
		_exit()
	active_changed.emit(is_active)
	_refresh_ui()


func set_tool_mode(mode: ToolMode) -> void:
	tool_mode = mode
	_refresh_ui()


func get_validation_ok() -> bool:
	return _validation_ok


func get_validation_errors() -> PackedStringArray:
	return _validation_errors


func get_cell_count() -> int:
	return _cells.size()


func clear_path() -> void:
	_cells.clear()
	_spawn = Vector2i(-1, -1)
	_core = Vector2i(-1, -1)
	_revalidate_and_refresh()


func save_path() -> void:
	_revalidate()
	if not _validation_ok:
		_set_status("Save blocked — fix validation errors first.", true)
		return
	var path_data: GridPathData = _build_path_resource()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://dev_paths"))
	var err_user: Error = ResourceSaver.save(path_data, SAVE_USER_PATH)
	var err_res: Error = OK
	# Also write under res:// when possible (editor / writable project).
	err_res = ResourceSaver.save(path_data, SAVE_RES_PATH)
	if err_user != OK and err_res != OK:
		_set_status("Save failed (user=%s res=%s)." % [error_string(err_user), error_string(err_res)], true)
		return
	var where: String = SAVE_USER_PATH if err_user == OK else SAVE_RES_PATH
	if err_user == OK and err_res == OK:
		where = "%s + %s" % [SAVE_USER_PATH, SAVE_RES_PATH]
	elif err_user == OK:
		where = SAVE_USER_PATH
	_set_status("Saved %d cells → %s" % [_cells.size(), where], false)
	_refresh_ui()


func load_path() -> void:
	var loaded: GridPathData = null
	if ResourceLoader.exists(SAVE_USER_PATH):
		loaded = load(SAVE_USER_PATH) as GridPathData
	elif ResourceLoader.exists(SAVE_RES_PATH):
		loaded = load(SAVE_RES_PATH) as GridPathData
	if loaded == null or loaded.cells.is_empty():
		_set_status("No saved path found (S to save first).", true)
		return
	_cells.clear()
	for cell: Vector2i in loaded.cells:
		_cells.append(cell)
	_spawn = _cells[0]
	_core = _cells[_cells.size() - 1]
	_revalidate_and_refresh()
	_apply_live_path(false)
	_set_status("Loaded %d cells from disk." % _cells.size(), false)


func test_wave() -> void:
	_revalidate()
	if not _validation_ok:
		_set_status("Test Wave blocked — path invalid.", true)
		_refresh_ui()
		return
	if wave_manager == null:
		_set_status("WaveManager missing.", true)
		return
	if not _apply_live_path(true):
		_set_status("Failed to apply path to WaveManager.", true)
		return
	wave_manager.force_idle_for_dev()
	_clear_live_insects()
	wave_manager.start_next_wave()
	_set_status("Test wave started on edited path.", false)
	_refresh_ui()


func _clear_live_insects() -> void:
	if wave_manager == null or wave_manager.insect_layer == null:
		return
	for child: Node in wave_manager.insect_layer.get_children():
		if is_instance_valid(child):
			child.queue_free()


func _enter() -> void:
	if grid != null:
		_grid_was_debug = grid.show_debug_grid
		grid.show_debug_grid = true
		grid.debug_line_color = Color(0.55, 0.85, 1.0, 0.35)
	_bootstrap_from_level()
	if overlay != null:
		overlay.visible = true
		overlay.grid = grid
	if hud != null:
		hud.visible = true
	_revalidate_and_refresh()


func _exit() -> void:
	if grid != null:
		grid.show_debug_grid = _grid_was_debug
		grid.debug_line_color = Color(1, 1, 1, 0.16)
	if overlay != null:
		overlay.visible = false
		overlay.set_hover(Vector2i(-1, -1))
	if hud != null:
		hud.visible = false


func _bootstrap_from_level() -> void:
	if wave_manager == null:
		return
	var level: LevelData = wave_manager.get_level_data()
	if level == null:
		return
	var primary: GridPathData = level.get_primary_path()
	if primary == null or primary.cells.is_empty():
		return
	_cells.clear()
	for cell: Vector2i in primary.cells:
		_cells.append(cell)
	_spawn = _cells[0]
	_core = _cells[_cells.size() - 1]


func _handle_left_click(cell: Vector2i) -> void:
	match tool_mode:
		ToolMode.PAINT:
			_paint_add(cell)
		ToolMode.SPAWN:
			_set_spawn(cell)
		ToolMode.CORE:
			_set_core(cell)
	_revalidate_and_refresh()


func _handle_right_click(cell: Vector2i) -> void:
	_paint_remove(cell)
	_revalidate_and_refresh()


func _paint_add(cell: Vector2i) -> void:
	if _cells.has(cell):
		_set_status("Cell already on path.", true)
		return
	if _cells.is_empty():
		_cells.append(cell)
		_spawn = cell
		_core = cell
		_set_status("Path started at %s." % str(cell), false)
		return
	var last: Vector2i = _cells[_cells.size() - 1]
	if absi(last.x - cell.x) + absi(last.y - cell.y) != 1:
		_set_status("Must be orthogonal neighbor of path end %s." % str(last), true)
		return
	_cells.append(cell)
	_core = cell
	_set_status("Added %s (len %d)." % [str(cell), _cells.size()], false)


func _paint_remove(cell: Vector2i) -> void:
	var idx: int = _cells.find(cell)
	if idx < 0:
		_set_status("Cell not on path.", true)
		return
	_cells.remove_at(idx)
	if _cells.is_empty():
		_spawn = Vector2i(-1, -1)
		_core = Vector2i(-1, -1)
	else:
		if _spawn == cell:
			_spawn = _cells[0]
		if _core == cell:
			_core = _cells[_cells.size() - 1]
		# Keep markers consistent with ends when possible.
		if not _cells.has(_spawn):
			_spawn = _cells[0]
		if not _cells.has(_core):
			_core = _cells[_cells.size() - 1]
	_set_status("Removed %s." % str(cell), false)


func _set_spawn(cell: Vector2i) -> void:
	_spawn = cell
	if _cells.is_empty():
		_cells.append(cell)
		_core = cell
	elif _cells[0] != cell:
		# If already on path, rotate prefix so spawn is first.
		var idx: int = _cells.find(cell)
		if idx >= 0:
			var rebuilt: Array[Vector2i] = []
			for i: int in range(idx, _cells.size()):
				rebuilt.append(_cells[i])
			_cells = rebuilt
		else:
			# Insert at front only when adjacent to current start.
			if absi(_cells[0].x - cell.x) + absi(_cells[0].y - cell.y) == 1:
				_cells.insert(0, cell)
			else:
				_set_status("Spawn must be on path or adjacent to start.", true)
				return
	_set_status("Spawn → %s" % str(cell), false)


func _set_core(cell: Vector2i) -> void:
	_core = cell
	if _cells.is_empty():
		_cells.append(cell)
		_spawn = cell
	elif _cells[_cells.size() - 1] != cell:
		var idx: int = _cells.find(cell)
		if idx >= 0:
			# Truncate path to end at core.
			var rebuilt: Array[Vector2i] = []
			for i: int in range(idx + 1):
				rebuilt.append(_cells[i])
			_cells = rebuilt
		else:
			if absi(_cells[_cells.size() - 1].x - cell.x) + absi(_cells[_cells.size() - 1].y - cell.y) == 1:
				_cells.append(cell)
			else:
				_set_status("Core must be on path or adjacent to end.", true)
				return
	_set_status("Core → %s" % str(cell), false)


func _revalidate_and_refresh() -> void:
	_revalidate()
	_push_overlay()
	_apply_live_path(false)
	_refresh_ui()
	state_changed.emit()


func _revalidate() -> void:
	_validation_errors = PackedStringArray()
	if grid == null:
		_validation_errors.append("Grid missing.")
		_validation_ok = false
		return
	if _cells.size() < 2:
		_validation_errors.append("Need at least 2 path cells.")
	if _spawn.x < 0:
		_validation_errors.append("Spawn not set.")
	elif not grid.is_in_bounds(_spawn):
		_validation_errors.append("Spawn out of bounds.")
	if _core.x < 0:
		_validation_errors.append("Core not set.")
	elif not grid.is_in_bounds(_core):
		_validation_errors.append("Core out of bounds.")
	if not _cells.is_empty():
		if _spawn != _cells[0]:
			_validation_errors.append("Spawn must equal path[0] (%s)." % str(_cells[0]))
		if _core != _cells[_cells.size() - 1]:
			_validation_errors.append("Core must equal path end (%s)." % str(_cells[_cells.size() - 1]))
	for i: int in range(_cells.size()):
		var cell: Vector2i = _cells[i]
		if not grid.is_in_bounds(cell):
			_validation_errors.append("Cell %s out of bounds." % str(cell))
			continue
		if i == 0:
			continue
		var prev: Vector2i = _cells[i - 1]
		if prev == cell:
			_validation_errors.append("Duplicate consecutive cell %s." % str(cell))
		elif absi(prev.x - cell.x) + absi(prev.y - cell.y) != 1:
			_validation_errors.append("Gap at %s → %s (not orthogonal)." % [str(prev), str(cell)])
	# Reachability along the ordered path is implied by adjacency; also BFS on path set.
	if _validation_errors.is_empty() and _spawn.x >= 0 and _core.x >= 0:
		if not _bfs_reachable(_spawn, _core):
			_validation_errors.append("Spawn cannot reach Core along path cells.")
	_validation_ok = _validation_errors.is_empty()


func _bfs_reachable(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var set_cells: Dictionary = {}
	for cell: Vector2i in _cells:
		set_cells[cell] = true
	if not set_cells.has(from_cell) or not set_cells.has(to_cell):
		return false
	var q: Array[Vector2i] = [from_cell]
	var seen: Dictionary = {from_cell: true}
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
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


func _build_path_resource() -> GridPathData:
	var path := GridPathData.new()
	path.path_id = &"path_dev"
	path.cells = _cells.duplicate()
	return path


func _apply_live_path(for_wave: bool) -> bool:
	if grid == null:
		return false
	_working_path = _build_path_resource()
	var paths: Array[GridPathData] = [_working_path]
	grid.apply_grid_paths(paths)
	if path_visual != null:
		path_visual.apply_grid_paths(paths)
	if planting_visual != null:
		planting_visual.apply_grid_paths(paths)
	_reposition_core()
	if for_wave and wave_manager != null:
		return wave_manager.apply_dev_path(_working_path)
	elif wave_manager != null and wave_manager.grid_path != null:
		# Keep WaveManager pointer in sync even when not testing.
		wave_manager.grid_path = _working_path
	return true


func _reposition_core() -> void:
	if core == null or _core.x < 0 or grid == null:
		return
	var visual := core.get_node_or_null("Visual") as Node2D
	if visual != null:
		visual.global_position = grid.grid_to_world_center(_core) + Vector2(-10.0, 0.0)


func _push_overlay() -> void:
	if overlay == null:
		return
	overlay.grid = grid
	overlay.set_state(_cells, _spawn, _core, _validation_ok)


func _refresh_ui() -> void:
	if hud == null:
		return
	hud.refresh(
		is_active,
		tool_mode,
		_cells.size(),
		_spawn,
		_core,
		_validation_ok,
		_validation_errors
	)


func _set_status(text: String, is_error: bool) -> void:
	if hud != null:
		hud.set_flash_status(text, is_error)


func _on_tool_paint() -> void:
	set_tool_mode(ToolMode.PAINT)


func _on_tool_spawn() -> void:
	set_tool_mode(ToolMode.SPAWN)


func _on_tool_core() -> void:
	set_tool_mode(ToolMode.CORE)
