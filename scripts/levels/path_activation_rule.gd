## When a path becomes available for spawning within a level.
class_name PathActivationRule
extends Resource

@export var path: GridPathData
## First wave number (1-based) where this path may receive spawns.
@export var unlock_from_wave: int = 1
