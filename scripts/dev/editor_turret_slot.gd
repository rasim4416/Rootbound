## Buildable turret slot on the grid (one nanobot max).
class_name EditorTurretSlot
extends Resource

@export var cell: Vector2i = Vector2i.ZERO
@export var plant_id: StringName = &""
@export var starts_active: bool = false
@export var enabled: bool = true


## Typed deep copy (avoid overriding Resource.duplicate_deep).
func clone_deep() -> EditorTurretSlot:
	var copy := EditorTurretSlot.new()
	copy.cell = cell
	copy.plant_id = plant_id
	copy.starts_active = starts_active
	copy.enabled = enabled
	return copy
