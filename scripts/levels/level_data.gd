## Configuration for one Cell Interior difficulty tier (same map, infinite waves).
##
## Levels do not end. Unlocking the next level is based on best-wave thresholds.
## Enemy stats use LEVEL multipliers × WAVE multipliers (never mutate InsectData).
class_name LevelData
extends Resource

@export var level_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Grid")
@export var grid_columns: int = 18
@export var grid_rows: int = 10
@export var cell_size: Vector2 = Vector2(64, 64)

@export_group("Run Start")
@export var starting_bio_energy: float = 100.0
@export var nucleus_max_health: float = 100.0

@export_group("Unlock")
## Empty = unlocked by default (Level 1).
@export var unlock_required_level_id: StringName = &""
## Best wave required on unlock_required_level_id to unlock this level.
@export var unlock_required_best_wave: int = 0

@export_group("Level Scaling")
## Baseline difficulty for this level (applied before wave scaling).
@export var level_hp_multiplier: float = 1.0
@export var level_speed_multiplier: float = 1.0
@export var level_core_damage_multiplier: float = 1.0

@export_group("Wave Scaling")
@export var wave_scaling: WaveScalingConfig

@export_group("Enemies")
## Pathogen types available in this level.
@export var enemy_pool: Array[InsectData] = []

@export_group("Paths")
## Primary path (visual default / Nucleus end). Prefer path_rules for gameplay.
@export var grid_path: GridPathData
## Data-driven path activation (wave thresholds).
@export var path_rules: Array[PathActivationRule] = []

@export_group("Meta")
@export var difficulty: int = 1


func is_unlocked_by_default() -> bool:
	return unlock_required_level_id == &"" or unlock_required_best_wave <= 0


func get_primary_path() -> GridPathData:
	if grid_path != null:
		return grid_path
	for rule: PathActivationRule in path_rules:
		if rule != null and rule.path != null:
			return rule.path
	return null


func get_enemy_pool() -> Array[InsectData]:
	var pool: Array[InsectData] = []
	for insect: InsectData in enemy_pool:
		if insect != null:
			pool.append(insect)
	return pool


## All unique paths used by this level (for visuals).
func get_all_paths() -> Array[GridPathData]:
	var paths: Array[GridPathData] = []
	var seen: Dictionary = {}
	if grid_path != null:
		paths.append(grid_path)
		seen[grid_path] = true
	for rule: PathActivationRule in path_rules:
		if rule == null or rule.path == null:
			continue
		if seen.has(rule.path):
			continue
		seen[rule.path] = true
		paths.append(rule.path)
	return paths
