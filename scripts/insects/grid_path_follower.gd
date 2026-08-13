## Moves a pathogen host Node2D from grid cell center to grid cell center.
##
## Destination is always a GridPathData cell. Smooth lerp between centers;
## snaps exactly on arrival to avoid drift. Emits path_completed once at the end.
class_name GridPathFollower
extends Node

signal path_completed

var current_cell_index: int = 0
var current_cell: Vector2i = Vector2i.ZERO
var target_cell: Vector2i = Vector2i.ZERO
## 0..1 progress along the current cell → next cell segment.
var progress: float = 0.0
var is_moving: bool = false

var _path_data: GridPathData
var _grid: GridManager
var _host: Node2D
var _speed: float = 0.0
var _completed: bool = false
var _paused: bool = false
var _from_world: Vector2 = Vector2.ZERO
var _to_world: Vector2 = Vector2.ZERO
var _segment_length: float = 0.0


## Begins following path_data using grid cell centers at the given pixel speed.
func start(path_data: GridPathData, grid: GridManager, speed: float) -> void:
	_host = get_parent() as Node2D
	if _host == null:
		push_error("GridPathFollower: parent must be a Node2D (e.g. Insect).")
		return
	if grid == null:
		push_error("GridPathFollower: GridManager is null.")
		return
	if path_data == null:
		push_error("GridPathFollower: GridPathData is null.")
		return
	if not path_data.validate(grid):
		return

	stop()

	_path_data = path_data
	_grid = grid
	_speed = maxf(speed, 0.0)
	_completed = false
	_paused = false
	current_cell_index = 0
	current_cell = _path_data.get_cell(0)
	progress = 0.0

	_host.global_position = _grid.grid_to_world_center(current_cell)
	_host.global_rotation = 0.0

	if _path_data.get_cell_count() <= 1:
		_finish_path()
		return

	_begin_segment(0)
	is_moving = true
	set_process(true)


## Halts movement without emitting path_completed.
func stop() -> void:
	is_moving = false
	_paused = false
	set_process(false)
	_path_data = null
	_grid = null
	_segment_length = 0.0


## Freezes movement in place (Game Over). Does not emit path_completed.
func pause() -> void:
	if not is_moving:
		return
	_paused = true
	set_process(false)


## Continues after pause() if the path was not completed/stopped.
func resume() -> void:
	if _completed or _path_data == null or _grid == null:
		return
	if current_cell_index >= _path_data.get_cell_count() - 1 and progress >= 1.0:
		return
	_paused = false
	is_moving = true
	set_process(true)


func _process(delta: float) -> void:
	if not is_moving or _paused or _completed:
		return
	if _host == null or _grid == null or _path_data == null:
		return

	if GameManager != null and GameManager.is_game_over():
		pause()
		return
	if GameManager != null and GameManager.is_upgrade_paused():
		return

	var host_insect := _host as Insect
	if host_insect != null and not host_insect.is_alive:
		stop()
		return

	if _segment_length <= 0.0:
		_advance_or_finish()
		return

	progress = minf(progress + (_speed * delta) / _segment_length, 1.0)
	_host.global_position = _from_world.lerp(_to_world, progress)

	if progress >= 1.0:
		_host.global_position = _to_world
		_advance_or_finish()


func _begin_segment(from_index: int) -> void:
	current_cell_index = from_index
	current_cell = _path_data.get_cell(from_index)
	target_cell = _path_data.get_cell(from_index + 1)
	_from_world = _grid.grid_to_world_center(current_cell)
	_to_world = _grid.grid_to_world_center(target_cell)
	_segment_length = _from_world.distance_to(_to_world)
	progress = 0.0
	_host.global_position = _from_world

	var dir: Vector2 = _to_world - _from_world
	if dir.length_squared() > 0.0001:
		_host.global_rotation = dir.angle()


func _advance_or_finish() -> void:
	# Snap to the cell we just arrived at.
	current_cell_index += 1
	current_cell = _path_data.get_cell(current_cell_index)
	_host.global_position = _grid.grid_to_world_center(current_cell)
	progress = 0.0

	if current_cell_index >= _path_data.get_cell_count() - 1:
		_finish_path()
		return

	_begin_segment(current_cell_index)


func _finish_path() -> void:
	is_moving = false
	_paused = false
	set_process(false)
	if _completed:
		return
	_completed = true
	path_completed.emit()
