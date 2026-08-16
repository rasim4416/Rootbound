## Per-path spawn defaults (inspector / new-wave defaults). Runtime waves are authored.
class_name EditorSpawnProfile
extends Resource

@export var path_id: StringName = &""
@export var spawn_interval: float = 1.0
@export var initial_delay: float = 0.0
@export var spawn_weight: float = 1.0
@export var max_enemies: int = 20
@export var allowed_enemy_ids: Array[StringName] = []
@export var wave_start: int = 1


## Typed deep copy (avoid overriding Resource.duplicate_deep).
func clone_deep() -> EditorSpawnProfile:
	var copy := EditorSpawnProfile.new()
	copy.path_id = path_id
	copy.spawn_interval = spawn_interval
	copy.initial_delay = initial_delay
	copy.spawn_weight = spawn_weight
	copy.max_enemies = max_enemies
	copy.allowed_enemy_ids = allowed_enemy_ids.duplicate()
	copy.wave_start = wave_start
	return copy
