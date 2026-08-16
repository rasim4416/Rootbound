## Save/load helpers for ResearchData .tres files.
class_name ResearchDesignerIO
extends RefCounted

const DEV_DIR: String = "res://data/research/dev"


static func save_catalog(catalog: Array[ResearchData]) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEV_DIR))
	var err: Error = OK
	for data: ResearchData in catalog:
		if data == null or data.research_id == &"":
			continue
		var path: String = data.resource_path
		if path.is_empty() or not path.begins_with("res://"):
			path = "%s/%s.tres" % [DEV_DIR, String(data.research_id)]
		var save_err: Error = ResourceSaver.save(data, path)
		if save_err != OK:
			err = save_err
		else:
			data.take_over_path(path)
	return err


static func save_as(data: ResearchData, path: String) -> Error:
	if data == null or path.is_empty():
		return ERR_INVALID_PARAMETER
	var err: Error = ResourceSaver.save(data, path)
	if err == OK:
		data.take_over_path(path)
	return err


static func load_element(element_id: StringName) -> ElementData:
	if element_id == &"":
		return null
	var path: String = "res://data/research/elements/%s.tres" % String(element_id)
	if ResourceLoader.exists(path):
		return load(path) as ElementData
	return null


static func list_proteins() -> Array[ProteinData]:
	var out: Array[ProteinData] = []
	var dir := DirAccess.open("res://data/progression/proteins")
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if not dir.current_is_dir() and (entry_name.ends_with(".tres") or entry_name.ends_with(".res")):
			var loaded: Resource = load("res://data/progression/proteins".path_join(entry_name))
			var protein := loaded as ProteinData
			if protein != null:
				out.append(protein)
		entry_name = dir.get_next()
	dir.list_dir_end()
	return out
