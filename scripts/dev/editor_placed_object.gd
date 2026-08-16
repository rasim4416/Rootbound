## Placed map object (organelle / decorative / stub).
class_name EditorPlacedObject
extends Resource

enum ObjectKind {
	ORGANELLE,
	GENERATOR,
	DECORATIVE,
	RESEARCH_POINT,
}

@export var object_id: StringName = &""
@export var kind: ObjectKind = ObjectKind.DECORATIVE
@export var cell: Vector2i = Vector2i.ZERO
## For ORGANELLE / GENERATOR — matches OrganelData / PlantData ids.
@export var data_id: StringName = &""


## Typed deep copy (avoid overriding Resource.duplicate_deep).
func clone_deep() -> EditorPlacedObject:
	var copy := EditorPlacedObject.new()
	copy.object_id = object_id
	copy.kind = kind
	copy.cell = cell
	copy.data_id = data_id
	return copy
