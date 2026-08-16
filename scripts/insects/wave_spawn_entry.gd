## One spawn group inside a WaveData (supports mixed pathogen waves).
class_name WaveSpawnEntry
extends Resource

@export var insect_data: InsectData
@export var count: int = 1
## Optional path override for this entry (empty = wave.path_id / primary).
@export var path_id: StringName = &""
## Seconds after wave delay before this group's first spawn.
@export var start_time: float = 0.0
## Per-group interval. Negative = use WaveData.spawn_interval (legacy).
@export var spawn_interval: float = -1.0


func resolve_interval(wave_interval: float) -> float:
	if spawn_interval < 0.0:
		return maxf(wave_interval, 0.0)
	return spawn_interval
