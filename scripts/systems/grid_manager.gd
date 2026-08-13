## Map-local grid for coordinate conversion and cell occupancy.
##
## Attach this to a Node2D in a level scene (e.g. Main/Grid). It has no plant
## or insect knowledge — callers decide what occupancy means.
class_name GridManager
extends Node2D

signal occupancy_changed(cell: Vector2i, occupied: bool)

@export_group("Grid")
## Width and height of one cell in pixels.
@export var cell_size: Vector2 = Vector2(64, 64):
	set(value):
		cell_size = value.max(Vector2(1, 1))
		queue_redraw()

## Number of cells horizontally.
@export var columns: int = 18:
	set(value):
		columns = maxi(value, 1)
		queue_redraw()

## Number of cells vertically.
@export var rows: int = 10:
	set(value):
		rows = maxi(value, 1)
		queue_redraw()

## World-space top-left corner of cell (0, 0).
@export var grid_origin: Vector2 = Vector2.ZERO:
	set(value):
		grid_origin = value
		queue_redraw()

@export_group("Debug")
@export var show_debug_grid: bool = true:
	set(value):
		show_debug_grid = value
		queue_redraw()

## Subtle line color for the debug overlay (no external assets).
@export var debug_line_color: Color = Color(1, 1, 1, 0.12):
	set(value):
		debug_line_color = value
		queue_redraw()

@export var debug_line_width: float = 1.0:
	set(value):
		debug_line_width = maxf(value, 0.5)
		queue_redraw()

## Sparse occupancy map: keys are Vector2i cells that are currently occupied.
var _occupied_cells: Dictionary = {}
## Infection path cells — units cannot be placed here.
var _path_cells: Dictionary = {}


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if not show_debug_grid:
		return

	var size := get_grid_size_pixels()
	var origin := grid_origin

	for x: int in range(columns + 1):
		var from := origin + Vector2(float(x) * cell_size.x, 0.0)
		var to := from + Vector2(0.0, size.y)
		draw_line(from, to, debug_line_color, debug_line_width)

	for y: int in range(rows + 1):
		var from := origin + Vector2(0.0, float(y) * cell_size.y)
		var to := from + Vector2(size.x, 0.0)
		draw_line(from, to, debug_line_color, debug_line_width)


## Pixel size of the full playable grid area.
func get_grid_size_pixels() -> Vector2:
	return Vector2(float(columns) * cell_size.x, float(rows) * cell_size.y)


## True when the cell lies inside the configured columns/rows.
func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


## Converts a world position into a grid cell (floor division).
func world_to_grid(world_position: Vector2) -> Vector2i:
	var local := to_local(world_position) - grid_origin
	return Vector2i(
		floori(local.x / cell_size.x),
		floori(local.y / cell_size.y)
	)


## World-space top-left corner of the given cell.
func grid_to_world(cell: Vector2i) -> Vector2:
	var local := grid_origin + Vector2(float(cell.x) * cell_size.x, float(cell.y) * cell_size.y)
	return to_global(local)


## World-space center of the given cell (useful for snapping placed units).
func grid_to_world_center(cell: Vector2i) -> Vector2:
	var local := grid_origin + Vector2(float(cell.x) * cell_size.x, float(cell.y) * cell_size.y) + cell_size * 0.5
	return to_global(local)


## Whether the cell is part of an active infection path.
func is_path_cell(cell: Vector2i) -> bool:
	return _path_cells.has(cell)


## True when a Nanobot / Organelle may be installed on this cell.
func is_placeable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and not is_occupied(cell) and not is_path_cell(cell)


## Marks every cell on the given paths as non-placeable (union of all paths).
func apply_grid_paths(paths: Array[GridPathData]) -> void:
	_path_cells.clear()
	for path_data: GridPathData in paths:
		if path_data == null:
			continue
		for cell: Vector2i in path_data.cells:
			_path_cells[cell] = true


func clear_path_cells() -> void:
	_path_cells.clear()


## Whether the cell is currently marked occupied.
func is_occupied(cell: Vector2i) -> bool:
	return _occupied_cells.has(cell)


## Marks a cell occupied or free. Out-of-bounds cells are ignored.
func set_occupied(cell: Vector2i, occupied: bool) -> void:
	if not is_in_bounds(cell):
		return

	var was_occupied := is_occupied(cell)
	if occupied == was_occupied:
		return

	if occupied:
		_occupied_cells[cell] = true
	else:
		_occupied_cells.erase(cell)

	occupancy_changed.emit(cell, occupied)


## Convenience wrapper for set_occupied(cell, true).
func mark_occupied(cell: Vector2i) -> void:
	set_occupied(cell, true)


## Convenience wrapper for set_occupied(cell, false).
func mark_free(cell: Vector2i) -> void:
	set_occupied(cell, false)


## Clears all occupancy without emitting per-cell signals.
func clear_all_occupancy() -> void:
	_occupied_cells.clear()


## Snapshot of currently occupied cells (copy — safe to mutate).
func get_occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for key: Variant in _occupied_cells.keys():
		cells.append(key as Vector2i)
	return cells
