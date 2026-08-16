## Soft nanobot deployment-sector presentation over GridManager.
## Path cells are skipped (PathVisual draws the continuous corridor).
## Legacy name: PlantingAreaVisual.
class_name PlantingAreaVisual
extends Node2D

@export var show_cells: bool = true
@export var grid_path: GridPathData
@export var fill_a: Color = Color(0.22, 0.58, 0.68, 0.07)
@export var fill_b: Color = Color(0.16, 0.46, 0.56, 0.05)
@export var border_color: Color = Color(0.40, 0.82, 0.88, 0.18)
## Path cells are left empty here — PathVisual owns the continuous corridor.
@export var border_width: float = 1.0
@export var cell_inset: float = 3.0


var _grid: GridManager
var _path_cell_set: Dictionary = {}
var _paths: Array[GridPathData] = []


func _ready() -> void:
	_grid = get_parent() as GridManager
	if grid_path != null and _paths.is_empty():
		_paths = [grid_path]
	_rebuild_path_set()
	queue_redraw()


## Rebinds path-cell highlights from a single path.
func apply_grid_path(path_data: GridPathData) -> void:
	grid_path = path_data
	_paths.clear()
	if path_data != null:
		_paths.append(path_data)
	_rebuild_path_set()
	queue_redraw()


## Union of all infection-channel cells for the shared Cell Interior map.
func apply_grid_paths(paths: Array[GridPathData]) -> void:
	_paths.clear()
	for path_data: GridPathData in paths:
		if path_data != null:
			_paths.append(path_data)
	if not _paths.is_empty():
		grid_path = _paths[0]
	_rebuild_path_set()
	queue_redraw()


func _rebuild_path_set() -> void:
	_path_cell_set.clear()
	for path_data: GridPathData in _paths:
		if path_data == null:
			continue
		for cell: Vector2i in path_data.cells:
			_path_cell_set[cell] = true


func _draw() -> void:
	if not show_cells or _grid == null:
		return

	var origin: Vector2 = _grid.grid_origin
	var cell_size: Vector2 = _grid.cell_size

	for y: int in range(_grid.rows):
		for x: int in range(_grid.columns):
			var cell := Vector2i(x, y)
			var top_left: Vector2 = origin + Vector2(float(x) * cell_size.x, float(y) * cell_size.y)
			var rect := Rect2(top_left, cell_size)
			# Skip path cells so per-cell borders never chop the corridor above.
			if _path_cell_set.has(cell):
				continue
			var inset: Rect2 = rect.grow(-cell_inset)
			var fill: Color = fill_a if ((x + y) % 2 == 0) else fill_b
			draw_rect(inset, fill, true)
			draw_rect(inset, border_color, false, border_width)