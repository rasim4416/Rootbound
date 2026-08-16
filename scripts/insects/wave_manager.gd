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

signal auto_start_enabled_changed(enabled: bool)

var state: WaveState = WaveState.IDLE
var auto_start_enabled: bool = false

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
var _inter_wave_delay: float = 0.0
var _auto_start_token: int = 0
var _dev_spawned: int = 0
var _dev_finished: int = 0
var _dev_job_total: int = 0


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
	if level.wave_scaling != null:
		_inter_wave_delay = level.wave_scaling.delay_before_wave
	else:
		_inter_wave_delay = 0.0
	grid_path = level.get_primary_path()
	wave_data.clear()
	_reset_for_new_run()

	if grid_path == null:
		push_error("WaveManager.apply_level: LevelData missing primary path.")
		return false
	if not grid_path.validate(grid):
		push_error("WaveManager.apply_level: primary path failed validation.")
		return false
	for rule: PathActivationRule in level.path_rules:
		if rule == null or rule.path == null:
			continue
		if not rule.path.validate(grid):
			push_warning(
				"WaveManager.apply_level: path '%s' failed validation — skipped."
				% String(rule.path.path_id)
			)
			continue
	if level.get_enemy_pool().is_empty():
		push_error("WaveManager.apply_level: LevelData has empty enemy_pool.")
		return false

	state_changed.emit(state)
	if auto_start_enabled:
		call_deferred("_try_auto_start")
	return true


func set_auto_start_enabled(enabled: bool) -> void:
	if auto_start_enabled == enabled:
		return
	auto_start_enabled = enabled
	auto_start_enabled_changed.emit(enabled)
	if enabled:
		_try_auto_start()


func is_auto_start_enabled() -> bool:
	return auto_start_enabled


func _reset_for_new_run() -> void:
	_stopped_for_game_over = false
	_generation_token += 1
	_current_wave_number = 0
	_displayed_wave_number = 0
	_spawn_queue.clear()
	_spawns_remaining = 0
	_dev_spawned = 0
	_dev_finished = 0
	_dev_job_total = 0
	_active_insects.clear()
	_set_state(WaveState.IDLE)


func stop_all_waves() -> void:
	_stopped_for_game_over = true
	_generation_token += 1
	_auto_start_token += 1
	_spawns_remaining = 0
	_spawn_queue.clear()
	if state != WaveState.COMPLETED and state != WaveState.IDLE:
		_set_state(WaveState.COMPLETED)


## Dev Mode: hot-swap primary path without resetting wave counter / run state.
func apply_dev_path(path: GridPathData) -> bool:
	if path == null:
		push_error("WaveManager.apply_dev_path: path is null.")
		return false
	if grid == null:
		push_error("WaveManager.apply_dev_path: grid is not assigned.")
		return false
	if not path.validate(grid):
		push_error("WaveManager.apply_dev_path: path failed validation.")
		return false
	grid_path = path
	if _level != null:
		_level.grid_path = path
		var rule := PathActivationRule.new()
		rule.path = path
		rule.unlock_from_wave = 1
		var rules: Array[PathActivationRule] = []
		rules.append(rule)
		_level.path_rules = rules
		_generator.configure(_level)
	return true


## Dev Mode: cancel in-flight spawn and return to IDLE so Test Wave can run.
func force_idle_for_dev() -> void:
	_stopped_for_game_over = false
	_generation_token += 1
	_auto_start_token += 1
	_spawn_queue.clear()
	_spawns_remaining = 0
	_dev_spawned = 0
	_dev_finished = 0
	_dev_job_total = 0
	_active_insects.clear()
	_set_state(WaveState.IDLE)


## Wave Designer STOP: idle + despawn live pathogens.
func stop_test_for_dev() -> void:
	force_idle_for_dev()
	if insect_layer == null:
		return
	for child: Node in insect_layer.get_children():
		if is_instance_valid(child):
			child.queue_free()


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
	if _level.uses_authored_waves():
		if _level.maximum_wave > 0 and next_wave > _level.maximum_wave:
			push_warning("WaveManager: reached maximum authored wave.")
			return
		# If authored list is finite and we've passed it, stop.
		if next_wave > _level.authored_waves.size() and _level.get_authored_wave(next_wave) == null:
			push_warning("WaveManager: no authored wave %d." % next_wave)
			return
		await _start_authored_wave(next_wave)
		return

	var generated: Dictionary = _generator.generate(next_wave)
	await _begin_wave_from_jobs(
		next_wave,
		generated.get("jobs", []) as Array,
		float(generated.get("spawn_interval", 1.0)),
		float(generated.get("delay_before_wave", 0.0))
	)


## Dev / Wave Editor: start a specific 1-based authored wave number.
func start_authored_wave_number(wave_number: int) -> void:
	if _level == null or not _level.uses_authored_waves():
		push_error("WaveManager.start_authored_wave_number: level has no authored waves.")
		return
	force_idle_for_dev()
	_current_wave_number = maxi(wave_number - 1, 0)
	await start_next_wave()


func _start_authored_wave(wave_number: int) -> void:
	var wave: WaveData = _level.get_authored_wave(wave_number)
	if wave == null:
		push_error("WaveManager: missing authored WaveData for wave %d." % wave_number)
		return
	var jobs: Array = _build_jobs_from_authored_wave(wave)
	await _begin_wave_from_jobs(wave_number, jobs, wave.spawn_interval, wave.delay_before_wave)


func _build_jobs_from_authored_wave(wave: WaveData) -> Array:
	var jobs: Array = []
	if wave == null:
		return jobs
	var level_hp: float = _level.level_hp_multiplier
	var level_speed: float = _level.level_speed_multiplier
	var level_core: float = _level.level_core_damage_multiplier

	if wave.spawn_entries.is_empty():
		var insects: Array[InsectData] = wave.build_spawn_queue()
		var path_ids: Array[StringName] = wave.build_path_id_queue()
		for i: int in range(insects.size()):
			var job := WaveSpawnJob.new()
			job.insect_data = insects[i]
			var pid: StringName = path_ids[i] if i < path_ids.size() else wave.path_id
			job.path = _resolve_path_by_id(pid)
			if job.path == null:
				job.path = _level.get_primary_path()
			job.hp_multiplier = level_hp * wave.hp_multiplier
			job.speed_multiplier = level_speed * wave.speed_multiplier
			job.core_damage_multiplier = level_core * wave.core_damage_multiplier
			job.spawn_at = 0.0
			jobs.append(job)
		return jobs

	for entry: WaveSpawnEntry in wave.spawn_entries:
		if entry == null or entry.insect_data == null:
			continue
		var interval: float = entry.resolve_interval(wave.spawn_interval)
		var pid: StringName = entry.path_id if entry.path_id != &"" else wave.path_id
		var path: GridPathData = _resolve_path_by_id(pid)
		if path == null:
			path = _level.get_primary_path()
		var n: int = maxi(entry.count, 0)
		for i: int in range(n):
			var job := WaveSpawnJob.new()
			job.insect_data = entry.insect_data
			job.path = path
			job.hp_multiplier = level_hp * wave.hp_multiplier
			job.speed_multiplier = level_speed * wave.speed_multiplier
			job.core_damage_multiplier = level_core * wave.core_damage_multiplier
			job.spawn_at = maxf(entry.start_time, 0.0) + float(i) * interval
			jobs.append(job)
	jobs.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ja: WaveSpawnJob = a as WaveSpawnJob
		var jb: WaveSpawnJob = b as WaveSpawnJob
		if ja == null or jb == null:
			return false
		return ja.spawn_at < jb.spawn_at
	)
	return jobs


func _resolve_path_by_id(path_id: StringName) -> GridPathData:
	if path_id == &"":
		return _level.get_primary_path() if _level != null else grid_path
	if _level == null:
		return grid_path
	for p: GridPathData in _level.get_all_paths():
		if p != null and p.path_id == path_id:
			return p
	if grid_path != null and grid_path.path_id == path_id:
		return grid_path
	return null


func _begin_wave_from_jobs(wave_number: int, jobs: Array, interval: float, delay: float) -> void:
	if jobs.is_empty():
		push_error("WaveManager: empty jobs for wave %d." % wave_number)
		return

	_current_wave_number = wave_number
	_displayed_wave_number = wave_number
	_spawn_queue = jobs.duplicate()
	_spawns_remaining = _spawn_queue.size()
	_dev_job_total = _spawns_remaining
	_dev_spawned = 0
	_dev_finished = 0
	_spawn_interval = interval
	_wave_delay = delay
	_active_insects.clear()

	var token: int = _generation_token
	_set_state(WaveState.PREPARING)
	wave_started.emit(wave_number)
	_record_best_wave(wave_number)

	if _wave_delay > 0.0:
		await get_tree().create_timer(_wave_delay).timeout
		if _stopped_for_game_over or token != _generation_token:
			return

	_begin_spawning(token, wave_number)


## Applies full editor map paths + authored waves onto the current LevelData session.
func apply_editor_map_data(map: EditorMapData) -> bool:
	if map == null or _level == null or grid == null:
		return false
	_level.grid_columns = map.grid_columns
	_level.grid_rows = map.grid_rows
	_level.cell_size = map.cell_size
	_level.starting_bio_energy = map.starting_bio_energy
	_level.nucleus_max_health = map.nucleus_max_health
	_level.level_hp_multiplier = map.level_hp_multiplier
	_level.level_speed_multiplier = map.level_speed_multiplier
	_level.level_core_damage_multiplier = map.level_core_damage_multiplier
	_level.restrict_build_to_slots = map.restrict_build_to_slots
	_level.turret_slots = map.turret_slots.duplicate()
	_level.blocked_cells = map.blocked_cells.duplicate(true)
	_level.non_buildable_cells = map.non_buildable_cells.duplicate(true)
	_level.authored_waves = map.waves.duplicate()

	var grid_paths: Array[GridPathData] = map.get_all_grid_paths()
	if grid_paths.is_empty():
		push_error("WaveManager.apply_editor_map_data: no valid paths.")
		return false
	_level.grid_path = grid_paths[0]
	var rules: Array[PathActivationRule] = []
	for i: int in range(map.paths.size()):
		var ep: EditorPathData = map.paths[i]
		if ep == null or ep.cells.size() < 2:
			continue
		var rule := PathActivationRule.new()
		rule.path = ep.to_grid_path()
		rule.unlock_from_wave = maxi(ep.unlock_from_wave, 1)
		rules.append(rule)
	_level.path_rules = rules
	grid_path = _level.grid_path
	_generator.configure(_level)
	grid.apply_placement_rules(
		_level.turret_slots,
		_level.blocked_cells,
		_level.non_buildable_cells,
		_level.restrict_build_to_slots
	)
	return true


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
	if _queue_has_timed_jobs():
		await _spawn_timed_queue(token)
	else:
		await _spawn_interval_queue(token)

	if state == WaveState.SPAWNING and not _stopped_for_game_over and token == _generation_token:
		_set_state(WaveState.ACTIVE)
		_try_complete_wave(wave_number)


func _queue_has_timed_jobs() -> bool:
	for item: Variant in _spawn_queue:
		var job := item as WaveSpawnJob
		if job != null and job.spawn_at > 0.0001:
			return true
	return false


func _spawn_interval_queue(token: int) -> void:
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


func _spawn_timed_queue(token: int) -> void:
	var elapsed: float = 0.0
	while _spawns_remaining > 0 and not _spawn_queue.is_empty():
		if _stopped_for_game_over or token != _generation_token:
			return
		if GameManager != null and GameManager.is_game_over():
			return
		var next_job: WaveSpawnJob = _spawn_queue[0] as WaveSpawnJob
		if next_job == null:
			_spawn_queue.pop_front()
			_spawns_remaining -= 1
			continue
		var wait: float = next_job.spawn_at - elapsed
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
			if _stopped_for_game_over or token != _generation_token:
				return
			elapsed = next_job.spawn_at
		_spawn_next_insect()
		_spawns_remaining -= 1


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
	_dev_spawned += 1


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
	_dev_finished += 1
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
	if auto_start_enabled:
		_schedule_auto_start()
	# Infinite waves: stay IDLE so the player can start the next wave.
	# Never emit all_waves_completed.


func _try_auto_start() -> void:
	if not auto_start_enabled or _stopped_for_game_over:
		return
	if GameManager != null and GameManager.is_game_over():
		return
	if state != WaveState.IDLE or _level == null:
		return
	start_next_wave()


func _schedule_auto_start() -> void:
	if not auto_start_enabled or _stopped_for_game_over:
		return
	_auto_start_token += 1
	var token: int = _auto_start_token
	var delay: float = maxf(_inter_wave_delay, 0.0)
	if delay <= 0.0:
		call_deferred("_try_auto_start")
		return
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if token != _auto_start_token or not auto_start_enabled:
			return
		_try_auto_start()
	)


func _count_active() -> int:
	var count: int = 0
	for insect: Variant in _active_insects.keys():
		if _active_insects[insect] == true:
			count += 1
	return count


## Wave Designer live HUD (read-only).
func get_dev_spawn_stats() -> Dictionary:
	return {
		"spawned": _dev_spawned,
		"alive": _count_active(),
		"killed": _dev_finished,
		"remaining": _spawns_remaining,
		"total": _dev_job_total,
	}


func _record_best_wave(wave_number: int) -> void:
	if GameManager == null or _level == null:
		return
	var levels: LevelManager = GameManager.get_level_manager()
	if levels != null:
		levels.record_best_wave(_level.level_id, wave_number)
