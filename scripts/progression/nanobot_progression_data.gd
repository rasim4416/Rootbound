## XP thresholds for individual Nanobot levels.
##
## Index 0 = XP required to go from level 1 → 2, index 1 = 2 → 3, etc.
class_name NanobotProgressionData
extends Resource

@export var progression_id: StringName = &"default"

## XP required to advance from level (i+1) to level (i+2).
@export var xp_thresholds: Array[float] = [100.0, 150.0, 225.0, 325.0, 450.0]

## Soft cap — levels beyond the last threshold reuse the last value.
@export var max_level: int = 10


func get_xp_to_next_level(current_level: int) -> float:
	if current_level < 1:
		return xp_thresholds[0] if not xp_thresholds.is_empty() else 100.0
	if current_level >= max_level:
		return INF
	var index: int = current_level - 1
	if xp_thresholds.is_empty():
		return 100.0
	if index >= xp_thresholds.size():
		return xp_thresholds[xp_thresholds.size() - 1]
	return maxf(xp_thresholds[index], 1.0)


func can_level_up(current_level: int) -> bool:
	return current_level < max_level
