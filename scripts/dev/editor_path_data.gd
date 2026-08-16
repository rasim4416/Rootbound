## One infection path authored in the Dev Level Editor.
class_name EditorPathData
extends Resource

@export var path_id: StringName = &"path_1"
@export var display_name: String = "Path 1"
@export var cells: Array[Vector2i] = []
@export var color: Color = Color(0.95, 0.35, 0.7, 1.0)
@export var unlock_from_wave: int = 1


func get_spawn() -> Vector2i:
	if cells.is_empty():
		return Vector2i(-1, -1)
	return cells[0]


func get_core() -> Vector2i:
	if cells.is_empty():
		return Vector2i(-1, -1)
	return cells[cells.size() - 1]


func to_grid_path() -> GridPathData:
	var gp := GridPathData.new()
	gp.path_id = path_id
	gp.cells = cells.duplicate()
	return gp


## Typed deep copy (avoid overriding Resource.duplicate_deep).
func clone_deep() -> EditorPathData:
	var copy := EditorPathData.new()
	copy.path_id = path_id
	copy.display_name = display_name
	copy.cells = cells.duplicate()
	copy.color = color
	copy.unlock_from_wave = unlock_from_wave
	return copy
