## Headless verification for Level × Wave alignment (path_01 only, scaling math).
extends SceneTree


func _init() -> void:
	var ok: bool = true
	ok = _verify_level_paths() and ok
	ok = _verify_scaling_math() and ok
	ok = _verify_unlock_thresholds() and ok
	ok = _verify_generator_hooks() and ok
	print("VERIFY %s" % ("OK" if ok else "FAILED"))
	quit(0 if ok else 1)


func _verify_level_paths() -> bool:
	var paths: Array[String] = [
		"res://data/levels/level_01.tres",
		"res://data/levels/level_02.tres",
		"res://data/levels/level_03.tres",
		"res://data/levels/level_04.tres",
	]
	for path: String in paths:
		var level := load(path) as LevelData
		if level == null:
			push_error("Failed to load %s" % path)
			return false
		var all_paths: Array[GridPathData] = level.get_all_paths()
		if all_paths.size() != 1:
			push_error("%s has %d paths (expected 1)" % [path, all_paths.size()])
			return false
		if String(all_paths[0].path_id) != "path_01":
			push_error("%s primary path is %s (expected path_01)" % [path, all_paths[0].path_id])
			return false
		var pool: Array[InsectData] = level.get_enemy_pool()
		if pool.size() != 1 or String(pool[0].insect_id) != "ant":
			push_error("%s enemy pool must be Bacterium only" % path)
			return false
		var gen := WaveGenerator.new()
		gen.configure(level)
		var active: Array[GridPathData] = gen.get_active_paths(50)
		if active.size() != 1 or String(active[0].path_id) != "path_01":
			push_error("%s wave 50 active paths must be path_01 only" % path)
			return false
	print("paths: OK (all levels path_01 + Bacterium only)")
	return true


func _verify_scaling_math() -> bool:
	var scaling := WaveScalingConfig.new()
	var base_hp := 50.0
	var l1w1: float = base_hp * scaling.get_wave_hp_multiplier(1)
	var l1w10: float = base_hp * scaling.get_wave_hp_multiplier(10)
	var l1w50: float = base_hp * scaling.get_wave_hp_multiplier(50)
	var l2w1: float = base_hp * 1.4 * scaling.get_wave_hp_multiplier(1)
	var l2w10: float = base_hp * 1.4 * scaling.get_wave_hp_multiplier(10)

	if not (l1w10 > l1w1 and l1w50 > l1w10 and l2w1 > l1w1 and l2w10 > l2w1):
		push_error("Scaling inequalities failed")
		return false

	var level2 := load("res://data/levels/level_02.tres") as LevelData
	var gen := WaveGenerator.new()
	gen.configure(level2)
	var w1: Dictionary = gen.generate(1)
	var w10: Dictionary = gen.generate(10)
	if int(w10["jobs"].size()) <= int(w1["jobs"].size()):
		push_error("Enemy count must increase with wave")
		return false
	if float(w10["spawn_interval"]) >= float(w1["spawn_interval"]):
		push_error("Spawn interval must decrease with wave")
		return false
	var job10: WaveSpawnJob = w10["jobs"][0] as WaveSpawnJob
	if job10.hp_multiplier <= float(w1["level_hp"]) * float(w1["wave_hp"]):
		# L2 W10 combined must exceed L2 W1 combined
		var job1: WaveSpawnJob = w1["jobs"][0] as WaveSpawnJob
		if job10.hp_multiplier <= job1.hp_multiplier:
			push_error("L2 W10 HP mult must exceed L2 W1")
			return false

	print(
		"scaling: OK (L1W1=%.1f L1W10=%.1f L1W50=%.1f L2W1=%.1f L2W10=%.1f)"
		% [l1w1, l1w10, l1w50, l2w1, l2w10]
	)
	return true


func _verify_unlock_thresholds() -> bool:
	var l1 := load("res://data/levels/level_01.tres") as LevelData
	var l2 := load("res://data/levels/level_02.tres") as LevelData
	var l3 := load("res://data/levels/level_03.tres") as LevelData
	var l4 := load("res://data/levels/level_04.tres") as LevelData
	if not l1.is_unlocked_by_default():
		push_error("Level 1 must be unlocked by default")
		return false
	if l2.unlock_required_level_id != &"level_01" or l2.unlock_required_best_wave != 20:
		push_error("Level 2 unlock must be L1 best >= 20")
		return false
	if l3.unlock_required_level_id != &"level_02" or l3.unlock_required_best_wave != 30:
		push_error("Level 3 unlock must be L2 best >= 30")
		return false
	if l4.unlock_required_level_id != &"level_03" or l4.unlock_required_best_wave != 40:
		push_error("Level 4 unlock must be L3 best >= 40")
		return false
	print("unlocks: OK (L1 open; L2@20 L3@30 L4@40)")
	return true


func _verify_generator_hooks() -> bool:
	# Ensure WaveManager still exposes is_wave_active for Generator / ATP / protein.
	var source: String = FileAccess.get_file_as_string("res://scripts/insects/wave_manager.gd")
	if not source.contains("func is_wave_active"):
		push_error("WaveManager.is_wave_active missing")
		return false
	var bio: String = FileAccess.get_file_as_string("res://scripts/plants/bio_energy_producer_component.gd")
	if not bio.contains("SPAWNING") or not bio.contains("ACTIVE"):
		push_error("BioEnergyProducer must gate on SPAWNING/ACTIVE")
		return false
	var reward: String = FileAccess.get_file_as_string("res://scripts/systems/reward_manager.gd")
	if reward.is_empty():
		push_error("RewardManager missing")
		return false
	var go: String = FileAccess.get_file_as_string("res://scripts/systems/game_over_manager.gd")
	if not go.contains("enter_game_over"):
		push_error("GameOverManager hook missing")
		return false
	print("combat hooks: OK (Generator / rewards / Game Over present)")
	return true
