## One spawn job produced by WaveGenerator (insect + path).
class_name WaveSpawnJob
extends RefCounted

var insect_data: InsectData = null
var path: GridPathData = null
## Combined level × wave multipliers (applied at spawn; InsectData untouched).
var hp_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var core_damage_multiplier: float = 1.0
## Seconds after wave delay. 0 for all jobs = use WaveManager global interval.
var spawn_at: float = 0.0
