## Draws infection channels through one or more GridPathData routes.
## Presentation only — GridPathData remains the authoritative gameplay path.
class_name PathVisual
extends Node2D

@export var grid: GridManager
@export var grid_path: GridPathData
@export var outer_width: float = 46.0
@export var inner_width: float = 22.0
@export var outer_color: Color = Color(0.45, 0.18, 0.40, 0.70)
@export var inner_color: Color = Color(0.75, 0.30, 0.55, 0.50)
@export var edge_color: Color = Color(0.90, 0.35, 0.55, 0.30)

## LEGACY: unused when grid_path is assigned.
@export var path: Path2D

var _paths: Array[GridPathData] = []
var _path_layers: Array[Node2D] = []


func _ready() -> void:
	if grid_path != null and _paths.is_empty():
		_paths = [grid_path]
	_rebuild()


## Rebinds a single infection channel.
func apply_grid_path(path_data: GridPathData) -> void:
	grid_path = path_data
	_paths.clear()
	if path_data != null:
		_paths.append(path_data)
	_rebuild()


## Draws every path used by the current level (same map, multiple channels).
func apply_grid_paths(paths: Array[GridPathData]) -> void:
	_paths.clear()
	for path_data: GridPathData in paths:
		if path_data != null:
			_paths.append(path_data)
	if not _paths.is_empty():
		grid_path = _paths[0]
	_rebuild()


func _clear_layers() -> void:
	for layer: Node2D in _path_layers:
		if is_instance_valid(layer):
			layer.queue_free()
	_path_layers.clear()


func _make_line(parent: Node2D, line_name: String, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.name = line_name
	line.default_color = color
	line.width = width
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	parent.add_child(line)
	return line


func _rebuild() -> void:
	_clear_layers()
	if grid == null:
		return

	for path_data: GridPathData in _paths:
		if path_data == null:
			continue
		if not path_data.validate(grid):
			continue

		var layer := Node2D.new()
		layer.name = "Path_%s" % String(path_data.path_id)
		add_child(layer)
		_path_layers.append(layer)

		var edge := _make_line(layer, "Edge", edge_color, outer_width + 12.0)
		var outer := _make_line(layer, "Outer", outer_color, outer_width)
		var inner := _make_line(layer, "Inner", inner_color, inner_width)

		var points := PackedVector2Array()
		for cell: Vector2i in path_data.cells:
			var world: Vector2 = grid.grid_to_world_center(cell)
			points.append(to_local(world))

		edge.points = points
		outer.points = points
		inner.points = points
