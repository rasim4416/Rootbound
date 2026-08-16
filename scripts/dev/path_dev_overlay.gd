## Editor overlay for Path Dev Mode — path order, spawn, core markers.
## Presentation only; PathDevMode owns the data.
class_name PathDevOverlay
extends Node2D

var grid: GridManager
var cells: Array[Vector2i] = []
var spawn_cell: Vector2i = Vector2i(-1, -1)
var core_cell: Vector2i = Vector2i(-1, -1)
var is_valid: bool = false
var hover_cell: Vector2i = Vector2i(-1, -1)


func set_state(
	path_cells: Array[Vector2i],
	spawn: Vector2i,
	core: Vector2i,
	valid: bool
) -> void:
	cells = path_cells.duplicate()
	spawn_cell = spawn
	core_cell = core
	is_valid = valid
	queue_redraw()


func set_hover(cell: Vector2i) -> void:
	if hover_cell == cell:
		return
	hover_cell = cell
	queue_redraw()


func _draw() -> void:
	if grid == null or not visible:
		return

	# Light cell wash so the grid is obvious in Dev Mode.
	for y: int in range(grid.rows):
		for x: int in range(grid.columns):
			var cell := Vector2i(x, y)
			var rect: Rect2 = _cell_rect(cell).grow(-1.0)
			draw_rect(rect, Color(0.15, 0.35, 0.55, 0.08), true)

	if hover_cell.x >= 0 and grid.is_in_bounds(hover_cell):
		draw_rect(_cell_rect(hover_cell).grow(-2.0), Color(1.0, 1.0, 0.4, 0.22), false, 2.0)

	var path_fill := Color(0.85, 0.25, 0.55, 0.35) if is_valid else Color(0.95, 0.2, 0.15, 0.40)
	var path_edge := Color(1.0, 0.7, 0.85, 0.85) if is_valid else Color(1.0, 0.45, 0.35, 0.95)

	for i: int in range(cells.size()):
		var cell: Vector2i = cells[i]
		var rect: Rect2 = _cell_rect(cell).grow(-4.0)
		draw_rect(rect, path_fill, true)
		draw_rect(rect, path_edge, false, 2.0)
		# Order index
		var center: Vector2 = to_local(grid.grid_to_world_center(cell))
		_draw_index(center, i)

	# Corridor lines between consecutive cells (order cue).
	for i: int in range(cells.size() - 1):
		var a: Vector2 = to_local(grid.grid_to_world_center(cells[i]))
		var b: Vector2 = to_local(grid.grid_to_world_center(cells[i + 1]))
		draw_line(a, b, path_edge, 3.0, true)

	if spawn_cell.x >= 0 and grid.is_in_bounds(spawn_cell):
		var sc: Vector2 = to_local(grid.grid_to_world_center(spawn_cell))
		draw_circle(sc, 10.0, Color(0.3, 0.95, 0.55, 0.9))
		draw_circle(sc, 4.0, Color(0.9, 1.0, 0.95, 1.0))
		_draw_tag(sc + Vector2(0, -22), "SPAWN", Color(0.35, 1.0, 0.6, 1.0))

	if core_cell.x >= 0 and grid.is_in_bounds(core_cell):
		var cc: Vector2 = to_local(grid.grid_to_world_center(core_cell))
		draw_rect(Rect2(cc - Vector2(9, 9), Vector2(18, 18)), Color(0.95, 0.35, 0.85, 0.9), true)
		draw_rect(Rect2(cc - Vector2(9, 9), Vector2(18, 18)), Color(1.0, 0.85, 0.95, 1.0), false, 2.0)
		_draw_tag(cc + Vector2(0, -22), "CORE", Color(1.0, 0.55, 0.9, 1.0))


func _cell_rect(cell: Vector2i) -> Rect2:
	var top_left: Vector2 = to_local(grid.grid_to_world(cell))
	return Rect2(top_left, grid.cell_size)


func _draw_index(center: Vector2, index: int) -> void:
	# Compact digit without DynamicFont dependency — small filled chip + lines.
	var chip := Rect2(center - Vector2(10, 8), Vector2(20, 16))
	draw_rect(chip, Color(0.05, 0.05, 0.1, 0.75), true)
	# Approximate label via Godot draw_string if default font available.
	var font: Font = ThemeDB.fallback_font
	if font != null:
		draw_string(
			font,
			center + Vector2(-8, 5),
			str(index),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color(1, 1, 1, 0.95)
		)


func _draw_tag(at: Vector2, text: String, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, at + Vector2(-18, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
