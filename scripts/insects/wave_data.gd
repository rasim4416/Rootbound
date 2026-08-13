## Configuration for a single enemy wave.
##
## Create one .tres per wave under data/waves/. WaveManager reads these in order
## and does not hard-code insect counts or timings.
##
## Prefer spawn_entries for mixed pathogen waves. Legacy insect_data + insect_count
## still works when spawn_entries is empty.
class_name WaveData
extends Resource

@export var wave_number: int = 1

## Legacy: Insect type spawned for every unit when spawn_entries is empty.
@export var insect_data: InsectData

## Legacy: How many insects to spawn when spawn_entries is empty.
@export var insect_count: int = 1

## Ordered spawn groups. When non-empty, overrides insect_data / insect_count.
@export var spawn_entries: Array[WaveSpawnEntry] = []

## Seconds between individual spawns within the wave.
@export var spawn_interval: float = 1.0

## Seconds to wait after start_next_wave() before the first spawn.
@export var delay_before_wave: float = 0.0


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
