## Scene-local wave coordinator for infinite Cell Interior levels.
##
## WaveGenerator builds each wave from LevelData. Path selection lives here /
## in WaveGenerator — insects never choose paths. Waves never "finish" the level.
class_name WaveManager
extends Node

enum WaveState {
	IDLE,
	PREPARING,
	SPAWNING,
	ACTIVE,
	COMPLETED, ## Used only after Game Over stop — not for clearing all waves.
}

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
## Kept for HUD compatibility; never emitted for normal infinite-wave play.
signal all_waves_completed()
signal insect_spawned(insect: Insect)
signal state_changed(new_state: WaveState)

## LEGACY: curved Path2D. Kept for scene compatibility; normal spawns ignore it.
@export var path: Path2D
@export var grid: GridManager
@export var grid_path: GridPathData
@export var insect_layer: Node2D
@export var insect_scene: PackedScene
## Legacy finite WaveData list — unused when LevelData + WaveGenerator are active.
@export var wave_data: Array[WaveData] = []

@export var auto_start_first_wave: bool = false

const _DEFAULT_INSECT_SCENE: PackedScene = preload("res://scenes/insects/insect.tscn")

var state: WaveState = WaveState.IDLE

var _level: LevelData = null
var _generator: WaveGenerator = WaveGenerator.new()
var _current_wave_number: int = 0
var _displayed_wave_number: int = 0
var _spawn_queue: Array = []
var _spawns_remaining: int = 0
var _spawn_interval: float = 1.0
var _wave_delay: float = 0.0
var _active_insects: Dictionary = {}
var _stopped_for_game_over: bool = false
var _generation_token: int = 0


func _ready() -> void:
	add_to_group("wave_manager")
	if insect_scene == null:
		insect_scene = _DEFAULT_INSECT_SCENE

	if grid == null:
		push_error("WaveManager: grid (GridManager) is not assigned.")
	if insect_layer == null:
		push_error("WaveManager: insect_layer is not assigned.")

	state_changed.emit(state)

	if auto_start_first_wave and _level != null:
		call_deferred("start_next_wave")


## Configures infinite-wave generation from LevelData and resets to IDLE.
func apply_level(level: LevelData) -> bool:
	if level == null:
		push_error("WaveManager.apply_level: LevelData is null.")
		return false
	if grid == null:
		push_error("WaveManager.apply_level: grid is not assigned.")
		return false

	_level = level
	_generator.configure(level)
	grid_path = level.get_primary_path()
	wave_data.clear()
	_reset_for_new_run()

	if grid_path == null:
		push_error("WaveManager.apply_level: LevelData missing primary path.")
		return false
	if not grid_path.validate(grid):
		return false
	for rule: PathActivationRule in level.path_rules:
		if rule == null or rule.path == null:
			continue
		if not rule.path.validate(grid):
			return false
	if level.get_enemy_pool().is_empty():
		push_error("WaveManager.apply_level: LevelData has empty enemy_pool.")
		return false

	state_changed.emit(state)
	return true


func _reset_for_new_run() -> void:
	_stopped_for_game_over = false
	_generation_token += 1
	_current_wave_number = 0
	_displayed_wave_number = 0
	_spawn_queue.clear()
	_spawns_remaining = 0
	_active_insects.clear()
	_set_state(WaveState.IDLE)


func stop_all_waves() -> void:
	_stopped_for_game_over = true
	_generation_token += 1
	_spawns_remaining = 0
	_spawn_queue.clear()
	if state != WaveState.COMPLETED and state != WaveState.IDLE:
		_set_state(WaveState.COMPLETED)


## Begins the next wave (1, 2, 3, … forever). Never ends the level.
func start_next_wave() -> void:
	if _stopped_for_game_over or (GameManager != null and GameManager.is_game_over()):
		return
	if state != WaveState.IDLE:
		push_warning("WaveManager: cannot start a wave while state is %s." % WaveState.keys()[state])
		return
	if _level == null:
		push_error("WaveManager: no LevelData applied.")
		return

	var next_wave: int = _current_wave_number + 1
	var generated: Dictionary = _generator.generate(next_wave)
	var jobs: Array = generated.get("jobs", [])
	if jobs.is_empty():
		push_error("WaveManager: WaveGenerator produced empty jobs for wave %d." % next_wave)
		return

	_current_wave_number = next_wave
	_displayed_wave_number = next_wave
	_spawn_queue = jobs.duplicate()
	_spawns_remaining = _spawn_queue.size()
	_spawn_interval = float(generated.get("spawn_interval", 1.0))
	_wave_delay = float(generated.get("delay_before_wave", 0.0))
	_active_insects.clear()

	var token: int = _generation_token
	_set_state(WaveState.PREPARING)
	wave_started.emit(next_wave)
	_record_best_wave(next_wave)

	if _wave_delay > 0.0:
		await get_tree().create_timer(_wave_delay).timeout
		if _stopped_for_game_over or token != _generation_token:
			return

	_begin_spawning(token, next_wave)


func get_current_wave_number() -> int:
	return _displayed_wave_number


func get_total_wave_count() -> int:
	## Infinite waves — no fixed total.
	return 0


func has_waves_remaining() -> bool:
	## Always true while a level is loaded and not game-over stopped.
	return _level != null and not _stopped_for_game_over


## True while pathogens are spawning or still on the map (economy / combat active).
func is_wave_active() -> bool:
	return state == WaveState.SPAWNING or state == WaveState.ACTIVE


func get_level_data() -> LevelData:
	return _level


func get_state_display_name() -> String:
	match state:
		WaveState.IDLE:
			return "STABLE"
		WaveState.PREPARING:
			return "DETECTING"
		WaveState.SPAWNING:
			return "BREACH"
		WaveState.ACTIVE:
			return "INFECTED"
		WaveState.COMPLETED:
			return "CLEARED"
		_:
			return "UNKNOWN"


func _set_state(new_state: WaveState) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func _begin_spawning(token: int, wave_number: int) -> void:
	if _stopped_for_game_over or state != WaveState.PREPARING or token != _generation_token:
		return

	_set_state(WaveState.SPAWNING)
	var interval: float = maxf(_spawn_interval, 0.0)

	while _spawns_remaining > 0:
		if _stopped_for_game_over or token != _generation_token:
			return
		if GameManager != null and GameManager.is_game_over():
			return
		_spawn_next_insect()
		_spawns_remaining -= 1

		if _spawns_remaining > 0 and interval > 0.0:
			await get_tree().create_timer(interval).timeout
			if _stopped_for_game_over or token != _generation_token:
				return

	if state == WaveState.SPAWNING and not _stopped_for_game_over and token == _generation_token:
		_set_state(WaveState.ACTIVE)
		_try_complete_wave(wave_number)


func _spawn_next_insect() -> void:
	if _stopped_for_game_over or (GameManager != null and GameManager.is_game_over()):
		return
	if insect_scene == null or insect_layer == null or grid == null:
		push_error("WaveManager: missing spawn references.")
		return
	if _spawn_queue.is_empty():
		push_error("WaveManager: spawn queue is empty.")
		return

	var job: WaveSpawnJob = _spawn_queue.pop_front() as WaveSpawnJob
	if job == null or job.insect_data == null or job.path == null:
		push_error("WaveManager: invalid WaveSpawnJob.")
		return

	_spawn_insect(job.insect_data, job.path, job.hp_multiplier, job.speed_multiplier, job.core_damage_multiplier)


## Spawns one insect onto a specific path with combined level×wave multipliers.
func _spawn_insect(
	insect_data: InsectData,
	spawn_path: GridPathData,
	hp_mult: float,
	speed_mult: float,
	core_damage_mult: float
) -> void:
	var insect := insect_scene.instantiate() as Insect
	if insect == null:
		push_error("WaveManager: insect_scene root must use the Insect script.")
		return

	insect.initialize(insect_data)
	insect.apply_level_wave_multipliers(hp_mult, speed_mult, core_damage_mult)
	insect_layer.add_child(insect)

	var move_speed: float = insect.get_move_speed()
	var follower := GridPathFollower.new()
	follower.name = "GridPathFollower"
	insect.add_child(follower)
	follower.start(spawn_path, grid, move_speed)

	_active_insects[insect] = true
	follower.path_completed.connect(_on_insect_path_completed.bind(insect), CONNECT_ONE_SHOT)
	insect.died.connect(_on_insect_died.bind(insect), CONNECT_ONE_SHOT)
	insect_spawned.emit(insect)


func _on_insect_path_completed(insect: Insect) -> void:
	_deactivate_insect(insect)


func _on_insect_died(_killer: Plant, insect: Insect) -> void:
	_deactivate_insect(insect)


func _deactivate_insect(insect: Insect) -> void:
	if insect == null or not _active_insects.has(insect):
		return
	if _active_insects[insect] != true:
		return

	_active_insects[insect] = false
	_try_complete_wave(_displayed_wave_number)


func _try_complete_wave(wave_number: int) -> void:
	if _stopped_for_game_over:
		return
	if state != WaveState.ACTIVE and state != WaveState.SPAWNING:
		return
	if _spawns_remaining > 0:
		return
	if _count_active() > 0:
		return

	_active_insects.clear()
	_spawn_queue.clear()
	_set_state(WaveState.IDLE)
	wave_completed.emit(wave_number)
	# Infinite waves: stay IDLE so the player can start the next wave.
	# Never emit all_waves_completed.


func _count_active() -> int:
	var count: int = 0
	for insect: Variant in _active_insects.keys():
		if _active_insects[insect] == true:
			count += 1
	return count


func _record_best_wave(wave_number: int) -> void:
	if GameManager == null or _level == null:
		return
	var levels: LevelManager = GameManager.get_level_manager()
	if levels != null:
		levels.record_best_wave(_level.level_id, wave_number)
