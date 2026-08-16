## Save / load EditorMapData to user:// and optional res://dev levels.
class_name MapSerializer
extends RefCounted

const USER_DIR: String = "user://dev_levels/"
const RES_DIR: String = "res://data/levels/dev/"


static func ensure_user_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_DIR))


static func user_path(map_id: StringName) -> String:
	return USER_DIR + String(map_id) + ".tres"


static func res_path(map_id: StringName) -> String:
	return RES_DIR + String(map_id) + ".tres"


static func save(map: EditorMapData, also_res: bool = true) -> Error:
	if map == null or map.map_id == &"":
		return ERR_INVALID_PARAMETER
	ensure_user_dir()
	var err: Error = ResourceSaver.save(map, user_path(map.map_id))
	if also_res:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RES_DIR))
		var err_res: Error = ResourceSaver.save(map, res_path(map.map_id))
		if err != OK:
			return err_res
	return err


static func load_map(map_id: StringName) -> EditorMapData:
	var up: String = user_path(map_id)
	if ResourceLoader.exists(up):
		return load(up) as EditorMapData
	var rp: String = res_path(map_id)
	if ResourceLoader.exists(rp):
		return load(rp) as EditorMapData
	return null


static func load_from_path(path: String) -> EditorMapData:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as EditorMapData


static func list_user_maps() -> PackedStringArray:
	ensure_user_dir()
	var out := PackedStringArray()
	var abs_dir: String = ProjectSettings.globalize_path(USER_DIR)
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			out.append(file_name.trim_suffix(".tres"))
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


static func duplicate_map(map: EditorMapData, new_id: StringName) -> EditorMapData:
	if map == null:
		return null
	var copy: EditorMapData = map.clone_deep()
	copy.map_id = new_id
	copy.map_name = map.map_name + " Copy"
	return copy
