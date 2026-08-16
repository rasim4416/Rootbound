## Debug / edit overlay for Dev Level Editor.
class_name EditorOverlay
extends Node2D

var grid: GridManager
var map: EditorMapData
var active_path_index: int = 0
var hover_cell: Vector2i = Vector2i(-1, -1)
var selected_cell: Vector2i = Vector2i(-1, -1)

var show_grid: bool = true
var show_path_dir: bool = true
var show_path_id: bool = true
var show_slots: bool = true
var show_blocked: bool = true
var show_buildable: bool = true
var show_ranges: bool = true


func set_map(m: EditorMapData) -> void:
	map = m
	queue_redraw()


func set_hover(cell: Vector2i) -> void:
	if hover_cell == cell:
		return
	hover_cell = cell
	queue_redraw()


func set_selected_cell(cell: Vector2i) -> void:
	selected_cell = cell
	queue_redraw()


func set_active_path(index: int) -> void:
	active_path_index = index
	queue_redraw()


func _draw() -> void:
	if grid == null or map == null or not visible:
		return

	if show_grid:
		for y: int in range(map.grid_rows):
			for x: int in range(map.grid_columns):
				var cell := Vector2i(x, y)
				var rect: Rect2 = _cell_rect(cell).grow(-1.0)
				draw_rect(rect, Color(0.2, 0.4, 0.6, 0.06), true)

	if show_blocked:
		for k: Variant in map.blocked_cells.keys():
			var cell: Vector2i = _parse_key(String(k))
			draw_rect(_cell_rect(cell).grow(-2.0), Color(0.5, 0.1, 0.1, 0.45), true)

	if show_buildable and map.restrict_build_to_slots:
		for y2: int in range(map.grid_rows):
			for x2: int in range(map.grid_columns):
				var c2 := Vector2i(x2, y2)
				if map.is_non_buildable(c2) or map.is_blocked(c2):
					continue
				if map.find_slot_at(c2) == null:
					draw_rect(_cell_rect(c2).grow(-3.0), Color(0.1, 0.1, 0.15, 0.15), true)

	if show_slots:
		for slot: EditorTurretSlot in map.turret_slots:
			if slot == null:
				continue
			var col := Color(0.3, 0.85, 1.0, 0.55) if slot.enabled else Color(0.4, 0.4, 0.45, 0.4)
			draw_rect(_cell_rect(slot.cell).grow(-5.0), col, false, 2.0)
			if show_ranges and slot.plant_id != &"":
				_draw_range_preview(slot.cell, 150.0)

	for i: int in range(map.paths.size()):
		var path: EditorPathData = map.paths[i]
		if path == null or path.cells.is_empty():
			continue
		var base: Color = path.color
		var active: bool = i == active_path_index
		var fill := Color(base.r, base.g, base.b, 0.45 if active else 0.22)
		var edge := Color(base.r, base.g, base.b, 0.95 if active else 0.55)
		for cell: Vector2i in path.cells:
			draw_rect(_cell_rect(cell).grow(-4.0), fill, true)
			draw_rect(_cell_rect(cell).grow(-4.0), edge, false, 2.0 if active else 1.0)
		if show_path_dir:
			for j: int in range(path.cells.size() - 1):
				var a: Vector2 = to_local(grid.grid_to_world_center(path.cells[j]))
				var b: Vector2 = to_local(grid.grid_to_world_center(path.cells[j + 1]))
				draw_line(a, b, edge, 3.0 if active else 1.5, true)
		var spawn: Vector2i = path.get_spawn()
		var core: Vector2i = path.get_core()
		if spawn.x >= 0:
			draw_circle(to_local(grid.grid_to_world_center(spawn)), 8.0, Color(0.3, 1.0, 0.55, 0.9))
		if core.x >= 0:
			var cc: Vector2 = to_local(grid.grid_to_world_center(core))
			draw_rect(Rect2(cc - Vector2(7, 7), Vector2(14, 14)), Color(1.0, 0.4, 0.85, 0.9), true)
		if show_path_id:
			var mid: Vector2 = to_local(grid.grid_to_world_center(path.cells[path.cells.size() / 2]))
			var font: Font = ThemeDB.fallback_font
			if font != null:
				draw_string(font, mid + Vector2(-20, -12), String(path.path_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, edge)

	for obj: EditorPlacedObject in map.placed_objects:
		if obj == null:
			continue
		draw_rect(_cell_rect(obj.cell).grow(-8.0), Color(0.95, 0.8, 0.3, 0.5), true)

	if hover_cell.x >= 0 and grid.is_in_bounds(hover_cell):
		draw_rect(_cell_rect(hover_cell).grow(-2.0), Color(1.0, 1.0, 0.4, 0.35), false, 2.0)
	if selected_cell.x >= 0 and grid.is_in_bounds(selected_cell):
		draw_rect(_cell_rect(selected_cell).grow(-1.0), Color(1.0, 0.9, 0.3, 0.8), false, 2.5)


func _draw_range_preview(cell: Vector2i, radius: float) -> void:
	var center: Vector2 = to_local(grid.grid_to_world_center(cell))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.4, 0.9, 1.0, 0.25), 1.5, true)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(to_local(grid.grid_to_world(cell)), grid.cell_size)


func _parse_key(k: String) -> Vector2i:
	var parts: PackedStringArray = k.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))
