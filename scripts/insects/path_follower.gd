## LEGACY / DEPRECATED.
##
## Moves a host along a Path2D Curve2D. Normal gameplay now uses GridPathFollower
## + GridPathData. Keep this script for debugging / compatibility only.
class_name PathFollower
extends Node

signal path_completed

var _path: Path2D
var _path_follow: PathFollow2D
var _host: Node2D
var _speed: float = 0.0
var _moving: bool = false
var _completed: bool = false


## Binds this follower to path and starts at the beginning of the curve.
## speed is world units (pixels) per second, typically InsectData.move_speed.
func start(path: Path2D, speed: float) -> void:
	_host = get_parent() as Node2D
	if _host == null:
		push_error("PathFollower: parent must be a Node2D (e.g. Insect).")
		return

	if path == null:
		push_error("PathFollower: Path2D reference is null.")
		return
	if path.curve == null or path.curve.point_count < 2:
		push_error("PathFollower: Path2D '%s' has no usable Curve2D." % path.name)
		return

	_stop_internal(false)

	_path = path
	_speed = maxf(speed, 0.0)
	_completed = false

	_path_follow = PathFollow2D.new()
	_path_follow.name = "PathFollow2D"
	_path_follow.loop = false
	_path_follow.rotates = true
	_path_follow.progress = 0.0
	_path.add_child(_path_follow)

	_moving = true
	_apply_host_transform()
	set_process(true)


## Halts movement without emitting path_completed.
func stop() -> void:
	_stop_internal(false)


## Freezes movement in place without freeing the PathFollow2D (Game Over).
func pause() -> void:
	_moving = false
	set_process(false)


func is_moving() -> bool:
	return _moving


func _process(delta: float) -> void:
	if not _moving or _path_follow == null:
		return

	if GameManager != null and GameManager.is_game_over():
		pause()
		return

	# Host Insect may have died without an explicit stop() in edge cases.
	var host_insect := _host as Insect
	if host_insect != null and not host_insect.is_alive:
		stop()
		return

	_path_follow.progress += _speed * delta
	_apply_host_transform()

	if _path_follow.progress_ratio >= 1.0:
		_path_follow.progress_ratio = 1.0
		_apply_host_transform()
		_moving = false
		set_process(false)
		if not _completed:
			_completed = true
			path_completed.emit()


func _apply_host_transform() -> void:
	if _host == null or _path_follow == null:
		return
	_host.global_position = _path_follow.global_position
	_host.global_rotation = _path_follow.global_rotation


func _stop_internal(emit_completed: bool) -> void:
	_moving = false
	set_process(false)
	if _path_follow != null and is_instance_valid(_path_follow):
		_path_follow.queue_free()
	_path_follow = null
	if emit_completed and not _completed:
		_completed = true
		path_completed.emit()


func _exit_tree() -> void:
	if _path_follow != null and is_instance_valid(_path_follow):
		_path_follow.queue_free()
		_path_follow = null
