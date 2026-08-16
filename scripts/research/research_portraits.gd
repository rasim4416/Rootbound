## Loads portrait textures for Research Lab nodes (cached by node_id).
class_name ResearchPortraits
extends RefCounted

const PORTRAIT_DIR: String = "res://assets/research/portraits/"

## Maps gameplay PlantData.plant_id (legacy) → research portrait filename id.
const PLANT_PORTRAIT_IDS: Dictionary = {
	&"clover": &"generator_nanobot", # Generator Nanobot
	&"thornbush": &"attacking_nanobot", # Attacking Nanobot
	&"support_nanobot": &"support_nanobot",
}

static var _cache: Dictionary = {}


static func get_portrait(node_id: StringName) -> Texture2D:
	if node_id == &"":
		return null
	if _cache.has(node_id):
		return _cache[node_id] as Texture2D
	var path: String = _path_for(node_id)
	if path == "":
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_cache[node_id] = tex
	return tex


static func get_plant_portrait(plant_id: StringName) -> Texture2D:
	var portrait_id: StringName = PLANT_PORTRAIT_IDS.get(plant_id, plant_id) as StringName
	return get_portrait(portrait_id)


static func get_organelle_portrait(organelle_id: StringName) -> Texture2D:
	return get_portrait(organelle_id)


static func list_portrait_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	var dir := DirAccess.open(PORTRAIT_DIR)
	if dir == null:
		return ids
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if not dir.current_is_dir() and entry_name.begins_with("portrait_") and entry_name.ends_with(".png"):
			var id_part: String = entry_name.trim_prefix("portrait_").trim_suffix(".png")
			ids.append(id_part)
		entry_name = dir.get_next()
	dir.list_dir_end()
	ids.sort()
	return ids


static func _path_for(node_id: StringName) -> String:
	var path: String = PORTRAIT_DIR + "portrait_%s.png" % String(node_id)
	if ResourceLoader.exists(path):
		return path
	return ""
