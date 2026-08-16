## Configuration for a single authored enemy wave (Dev Editor + runtime).
class_name WaveData
extends Resource

@export var wave_number: int = 1
@export var display_name: String = ""

## Legacy: Insect type spawned for every unit when spawn_entries is empty.
@export var insect_data: InsectData
## Legacy: How many insects to spawn when spawn_entries is empty.
@export var insect_count: int = 1
## Ordered spawn groups. When non-empty, overrides insect_data / insect_count.
@export var spawn_entries: Array[WaveSpawnEntry] = []

@export_group("Timing")
@export var spawn_interval: float = 1.0
@export var delay_before_wave: float = 0.0

@export_group("Routing")
## Path used for legacy single-type waves / default for entries without path_id.
@export var path_id: StringName = &""

@export_group("Multipliers")
@export var hp_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export var core_damage_multiplier: float = 1.0

@export_group("Rewards")
## Extra Bio-Energy per kill for this wave (0 = use InsectData.biomass_reward only).
@export var reward_bonus: int = 0

@export_group("Editor")
## Designer markers only — runtime spawn ignores this array.
@export var special_events: Array[WaveSpecialEvent] = []


## Flat spawn queue used by WaveManager (one InsectData per unit).
func build_spawn_queue() -> Array[InsectData]:
	var queue: Array[InsectData] = []
	if not spawn_entries.is_empty():
		for entry: WaveSpawnEntry in spawn_entries:
			if entry == null or entry.insect_data == null:
				continue
			var n: int = maxi(entry.count, 0)
			for _i: int in range(n):
				queue.append(entry.insect_data)
		return queue

	if insect_data == null:
		return queue
	for _i: int in range(maxi(insect_count, 0)):
		queue.append(insect_data)
	return queue


## Parallel path ids matching build_spawn_queue order.
func build_path_id_queue() -> Array[StringName]:
	var queue: Array[StringName] = []
	if not spawn_entries.is_empty():
		for entry: WaveSpawnEntry in spawn_entries:
			if entry == null or entry.insect_data == null:
				continue
			var n: int = maxi(entry.count, 0)
			var pid: StringName = entry.path_id if entry.path_id != &"" else path_id
			for _i: int in range(n):
				queue.append(pid)
		return queue
	for _i: int in range(maxi(insect_count, 0)):
		queue.append(path_id)
	return queue
