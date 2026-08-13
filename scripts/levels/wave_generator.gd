## Procedural wave builder for infinite Cell Interior levels.
##
## Separates LEVEL scaling (baseline) from WAVE scaling (continuous growth).
## Final combat scale = level_mult × wave_mult (then permanent/run via StatCalculator).
## Path selection: PathActivationRule + early round-robin so multi-path waves are simultaneous.
class_name WaveGenerator
extends RefCounted

var level: LevelData = null
var scaling: WaveScalingConfig = null


func configure(level_data: LevelData) -> void:
	level = level_data
	if level_data != null and level_data.wave_scaling != null:
		scaling = level_data.wave_scaling
	else:
		scaling = WaveScalingConfig.new()


## Builds spawn jobs for the given 1-based wave number.
func generate(wave_number: int) -> Dictionary:
	var result: Dictionary = {
		"wave_number": maxi(wave_number, 1),
		"spawn_interval": 1.0,
		"delay_before_wave": 0.0,
		"jobs": [],
		"level_hp": 1.0,
		"level_speed": 1.0,
		"level_core_damage": 1.0,
		"wave_hp": 1.0,
		"wave_speed": 1.0,
		"wave_core_damage": 1.0,
	}
	if level == null or scaling == null:
		return result

	var wave: int = maxi(wave_number, 1)
	var level_hp: float = level.level_hp_multiplier
	var level_speed: float = level.level_speed_multiplier
	var level_core: float = level.level_core_damage_multiplier
	var wave_hp: float = scaling.get_wave_hp_multiplier(wave)
	var wave_speed: float = scaling.get_wave_speed_multiplier(wave)
	var wave_core: float = scaling.get_wave_core_damage_multiplier(wave)

	result["level_hp"] = level_hp
	result["level_speed"] = level_speed
	result["level_core_damage"] = level_core
	result["wave_hp"] = wave_hp
	result["wave_speed"] = wave_speed
	result["wave_core_damage"] = wave_core
	result["spawn_interval"] = scaling.get_spawn_interval(wave)
	result["delay_before_wave"] = scaling.delay_before_wave

	var paths: Array[GridPathData] = get_active_paths(wave)
	if paths.is_empty():
		push_warning("WaveGenerator: no active paths for wave %d." % wave)
		return result

	var pool: Array[InsectData] = level.get_enemy_pool()
	if pool.is_empty():
		push_warning("WaveGenerator: empty enemy pool on level %s." % level.level_id)
		return result

	var count: int = scaling.get_enemy_count(wave)
	var path_order: Array[GridPathData] = _build_path_spawn_order(paths, count)
	var jobs: Array = []
	for i: int in range(count):
		var job := WaveSpawnJob.new()
		job.insect_data = pool[i % pool.size()]
		job.path = path_order[i]
		job.hp_multiplier = level_hp * wave_hp
		job.speed_multiplier = level_speed * wave_speed
		job.core_damage_multiplier = level_core * wave_core
		jobs.append(job)
	result["jobs"] = jobs
	return result


func get_active_paths(wave_number: int) -> Array[GridPathData]:
	var active: Array[GridPathData] = []
	if level == null:
		return active
	var wave: int = maxi(wave_number, 1)
	if level.path_rules.is_empty():
		var primary: GridPathData = level.get_primary_path()
		if primary != null:
			active.append(primary)
		return active

	for rule: PathActivationRule in level.path_rules:
		if rule == null or rule.path == null:
			continue
		if wave >= maxi(rule.unlock_from_wave, 1):
			active.append(rule.path)
	return active


## Ensures each active path appears early when count >= path count, then round-robins.
func _build_path_spawn_order(paths: Array[GridPathData], count: int) -> Array[GridPathData]:
	var order: Array[GridPathData] = []
	if paths.is_empty() or count <= 0:
		return order

	var path_count: int = paths.size()
	# First pass: one spawn per path (as many as count allows) so multi-path is simultaneous.
	var guaranteed: int = mini(count, path_count)
	for i: int in range(guaranteed):
		order.append(paths[i])

	# Remaining: continue round-robin from index 0.
	for i: int in range(guaranteed, count):
		order.append(paths[i % path_count])

	return order
