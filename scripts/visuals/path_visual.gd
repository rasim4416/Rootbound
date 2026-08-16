## Continuous corridor renderer for grid path data.
##
## Path Data  = GridPathData Vector2i cells (gameplay, unchanged)
## Path Render = merged horizontal/vertical corridor segments (visual only)
##
## Never draws one bordered square per cell — that creates a Lego look.
class_name PathVisual
extends Node2D

@export var grid: GridManager
@export var grid_path: GridPathData

@export_group("Lane")
## Corridor thickness as a fraction of cell size (~1 cell wide).
@export_range(0.5, 0.98, 0.01) var width_fraction: float = 0.88

@export_group("Colors")
@export var fill_color: Color = Color(0.82, 0.30, 0.52, 0.88)
@export var rim_color: Color = Color(0.55, 0.12, 0.32, 0.55)
@export var lane_color: Color = Color(1.0, 0.82, 0.90, 0.75)
@export var junction_color: Color = Color(1.0, 0.55, 0.72, 0.90)
@export var entry_color: Color = Color(0.95, 0.42, 0.58, 0.85)
@export var exit_color: Color = Color(0.85, 0.28, 0.45, 0.85)
@export var flow_color: Color = Color(1.0, 0.92, 0.96, 0.90)

@export_group("Flow")
@export var animate_flow: bool = true
@export var flow_speed: float = 48.0
@export var flow_particle_count: int = 3
@export var flow_particle_radius: float = 2.4

## LEGACY: unused. Kept so old scenes that reference Path2D still load.
@export var path: Path2D

var _paths: Array[GridPathData] = []
var _flow_root: Node2D
var _flow_tracks: Array[Dictionary] = []
var _flow_time: float = 0.0

var _adjacency: Dictionary = {} # Vector2i -> Array[Vector2i]
var _entries: Array[Vector2i] = []
var _exits: Array[Vector2i] = []
## Each entry: { "from": Vector2i, "to": Vector2i, "horizontal": bool }
var _corridor_runs: Array[Dictionary] = []
var _lane_width: float = 56.0
var _has_geometry: bool = false


func _ready() -> void:
	if grid_path != null and _paths.is_empty():
		_paths = [grid_path]
	_rebuild()
	set_process(animate_flow)


func apply_grid_path(path_data: GridPathData) -> void:
	grid_path = path_data
	_paths.clear()
	if path_data != null:
		_paths.append(path_data)
	_rebuild()


func apply_grid_paths(paths: Array[GridPathData]) -> void:
	_paths.clear()
	for path_data: GridPathData in paths:
		if path_data != null:
			_paths.append(path_data)
	if not _paths.is_empty():
		grid_path = _paths[0]
	_rebuild()


func _process(delta: float) -> void:
	if not animate_flow or _flow_tracks.is_empty():
		return
	_flow_time += delta
	_update_flow_particles()


func _rebuild() -> void:
	_clear_flow()
	_adjacency.clear()
	_entries.clear()
	_exits.clear()
	_corridor_runs.clear()
	_has_geometry = false

	if grid == null:
		queue_redraw()
		return

	var cell_min: float = minf(grid.cell_size.x, grid.cell_size.y)
	_lane_width = maxf(cell_min * width_fraction, 8.0)

	var valid_paths: Array[GridPathData] = []
	for path_data: GridPathData in _paths:
		if path_data == null or not path_data.validate(grid):
			continue
		if path_data.cells.size() < 2:
			continue
		valid_paths.append(path_data)

		var start_cell: Vector2i = path_data.cells[0]
		var end_cell: Vector2i = path_data.cells[path_data.cells.size() - 1]
		if not _entries.has(start_cell):
			_entries.append(start_cell)
		if not _exits.has(end_cell):
			_exits.append(end_cell)

		for i: int in range(1, path_data.cells.size()):
			_add_undirected(path_data.cells[i - 1], path_data.cells[i])

	_corridor_runs = _build_corridor_runs()
	_has_geometry = not _corridor_runs.is_empty()
	_build_flow_tracks(valid_paths)
	_flow_time = 0.0
	_update_flow_particles()
	set_process(animate_flow and not _flow_tracks.is_empty())
	queue_redraw()


func _clear_flow() -> void:
	_flow_tracks.clear()
	if _flow_root != null and is_instance_valid(_flow_root):
		_flow_root.queue_free()
	_flow_root = null


func _add_undirected(a: Vector2i, b: Vector2i) -> void:
	if not _adjacency.has(a):
		_adjacency[a] = [] as Array[Vector2i]
	if not _adjacency.has(b):
		_adjacency[b] = [] as Array[Vector2i]
	var na: Array = _adjacency[a] as Array
	var nb: Array = _adjacency[b] as Array
	if not na.has(b):
		na.append(b)
	if not nb.has(a):
		nb.append(a)


## Merge adjacent same-axis edges into maximal H/V corridor runs.
## One run = one continuous rectangle (no per-cell squares).
func _build_corridor_runs() -> Array[Dictionary]:
	var runs: Array[Dictionary] = []

	for cell_v: Variant in _adjacency.keys():
		var cell: Vector2i = cell_v as Vector2i

		# Horizontal run: begin only at the leftmost cell of a contiguous strip.
		if _has_neighbor(cell, Vector2i(1, 0)) and not _has_neighbor(cell, Vector2i(-1, 0)):
			var end: Vector2i = cell
			while _has_neighbor(end, Vector2i(1, 0)):
				end += Vector2i(1, 0)
			runs.append({"from": cell, "to": end, "horizontal": true})

		# Vertical run: begin only at the topmost cell of a contiguous strip.
		if _has_neighbor(cell, Vector2i(0, 1)) and not _has_neighbor(cell, Vector2i(0, -1)):
			var end_v: Vector2i = cell
			while _has_neighbor(end_v, Vector2i(0, 1)):
				end_v += Vector2i(0, 1)
			runs.append({"from": cell, "to": end_v, "horizontal": false})

	return runs


func _has_neighbor(cell: Vector2i, delta: Vector2i) -> bool:
	if not _adjacency.has(cell):
		return false
	return (_adjacency[cell] as Array).has(cell + delta)


func _draw() -> void:
	if grid == null or not _has_geometry:
		return

	# Soft rim slightly larger — continuous silhouette, not per-cell borders.
	var rim_grow: float = 2.5
	for run: Dictionary in _corridor_runs:
		draw_rect(_run_rect(run, _lane_width + rim_grow * 2.0), rim_color, true)

	# Main continuous corridor fills (overlapping at corners = clean L / T).
	for run: Dictionary in _corridor_runs:
		draw_rect(_run_rect(run, _lane_width), fill_color, true)

	# Bright center lane along each run (still one stroke per merged segment).
	var center_w: float = maxf(_lane_width * 0.22, 3.0)
	for run: Dictionary in _corridor_runs:
		var a: Vector2 = _local_center(run["from"] as Vector2i)
		var b: Vector2 = _local_center(run["to"] as Vector2i)
		draw_line(a, b, lane_color, center_w, true)

	# Junction markers only at true merges (3+ ways).
	for cell_v: Variant in _adjacency.keys():
		var cell: Vector2i = cell_v as Vector2i
		var deg: int = (_adjacency[cell] as Array).size()
		if deg < 3:
			continue
		var center: Vector2 = _local_center(cell)
		draw_circle(center, _lane_width * 0.18, junction_color)
		draw_circle(center, _lane_width * 0.08, lane_color)

	for cell: Vector2i in _entries:
		var center: Vector2 = _local_center(cell)
		draw_circle(center, _lane_width * 0.14, entry_color)
		draw_circle(center, _lane_width * 0.06, lane_color)

	for cell: Vector2i in _exits:
		var center: Vector2 = _local_center(cell)
		draw_circle(center, _lane_width * 0.14, exit_color)
		draw_circle(center, _lane_width * 0.06, lane_color)


## Axis-aligned corridor covering cell centers from→to at given thickness.
func _run_rect(run: Dictionary, thickness: float) -> Rect2:
	var from_cell: Vector2i = run["from"] as Vector2i
	var to_cell: Vector2i = run["to"] as Vector2i
	var a: Vector2 = _local_center(from_cell)
	var b: Vector2 = _local_center(to_cell)
	var half: float = thickness * 0.5
	if bool(run["horizontal"]):
		var left: float = minf(a.x, b.x) - half
		var top: float = a.y - half
		var width: float = absf(b.x - a.x) + thickness
		return Rect2(left, top, width, thickness)
	var left_v: float = a.x - half
	var top_v: float = minf(a.y, b.y) - half
	var height: float = absf(b.y - a.y) + thickness
	return Rect2(left_v, top_v, thickness, height)


func _local_center(cell: Vector2i) -> Vector2:
	return to_local(grid.grid_to_world_center(cell))


func _build_flow_tracks(valid_paths: Array[GridPathData]) -> void:
	if not animate_flow:
		return
	_flow_root = Node2D.new()
	_flow_root.name = "FlowParticles"
	add_child(_flow_root)

	for path_data: GridPathData in valid_paths:
		var points: PackedVector2Array = path_data.get_world_centers_local(self, grid)
		var cum: Array[float] = _build_cumulative_lengths(points)
		var total_len: float = cum[cum.size() - 1] if cum.size() > 0 else 0.0
		var particles: Array = []
		if total_len > 1.0:
			var count: int = maxi(flow_particle_count, 1)
			for p: int in range(count):
				var disc := Polygon2D.new()
				disc.name = "Flow_%s_%d" % [String(path_data.path_id), p]
				disc.color = flow_color
				disc.polygon = _circle_poly(flow_particle_radius, 8)
				_flow_root.add_child(disc)
				particles.append(disc)
		_flow_tracks.append({
			"points": points,
			"cum": cum,
			"length": total_len,
			"particles": particles,
		})


func _update_flow_particles() -> void:
	for track: Dictionary in _flow_tracks:
		var points: PackedVector2Array = track.get("points", PackedVector2Array()) as PackedVector2Array
		var cum: Array = track.get("cum", []) as Array
		var total_len: float = float(track.get("length", 0.0))
		var particles: Array = track.get("particles", []) as Array
		if points.size() < 2 or total_len <= 1.0 or particles.is_empty() or cum.is_empty():
			continue
		var count: int = particles.size()
		for i: int in range(count):
			var disc: Polygon2D = particles[i] as Polygon2D
			if disc == null or not is_instance_valid(disc):
				continue
			var phase: float = float(i) / float(count)
			var dist: float = fposmod(_flow_time * flow_speed + phase * total_len, total_len)
			disc.position = _sample_polyline(points, cum, dist)


func _circle_poly(radius: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(segments):
		var angle: float = float(i) / float(segments) * TAU
		out.append(Vector2(cos(angle), sin(angle)) * radius)
	return out


func _build_cumulative_lengths(points: PackedVector2Array) -> Array[float]:
	var cum: Array[float] = []
	cum.append(0.0)
	for i: int in range(1, points.size()):
		cum.append(cum[i - 1] + points[i - 1].distance_to(points[i]))
	return cum


func _sample_polyline(points: PackedVector2Array, cum: Array, distance: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]
	var last_cum: float = float(cum[cum.size() - 1])
	var d: float = clampf(distance, 0.0, last_cum)
	for i: int in range(1, points.size()):
		var cum_i: float = float(cum[i])
		if d <= cum_i:
			var seg_start: float = float(cum[i - 1])
			var seg_len: float = cum_i - seg_start
			if seg_len <= 0.0001:
				return points[i]
			var t: float = (d - seg_start) / seg_len
			return points[i - 1].lerp(points[i], t)
	return points[points.size() - 1]
