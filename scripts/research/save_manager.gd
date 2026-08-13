## Persists meta-progression (CHONS, research unlocks, best wave per level).
##
## Path: user://rootbound_save.json
## Does not store run state (Bio-Energy, ATP, Nanobot XP, placements).
class_name SaveManager
extends Node

const SAVE_PATH: String = "user://rootbound_save.json"
const SAVE_VERSION: int = 2

@export var debug_save: bool = false

var _suppress_autosave: bool = false


func _ready() -> void:
	call_deferred("_bind_and_load")


func _bind_and_load() -> void:
	var inventory: ElementInventory = _get_inventory()
	if inventory != null:
		if not inventory.element_changed.is_connected(_on_element_changed):
			inventory.element_changed.connect(_on_element_changed)
	var research: ResearchManager = _get_research()
	if research != null:
		if not research.research_unlocked.is_connected(_on_research_unlocked):
			research.research_unlocked.connect(_on_research_unlocked)
	var levels: LevelManager = _get_levels()
	if levels != null:
		if not levels.best_wave_changed.is_connected(_on_best_wave_changed):
			levels.best_wave_changed.connect(_on_best_wave_changed)
	load_save()


func load_save() -> bool:
	_suppress_autosave = true
	var ok: bool = _load_internal()
	_suppress_autosave = false
	return ok


func save_now() -> bool:
	if _suppress_autosave:
		return true
	return _save_internal()


func _on_element_changed(_element_id: StringName, _new_amount: int) -> void:
	save_now()


func _on_research_unlocked(_research_id: StringName) -> void:
	save_now()


func _on_best_wave_changed(_level_id: StringName, _best_wave: int) -> void:
	save_now()


func _load_internal() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		if debug_save:
			print("SaveManager: no save at %s — using defaults." % SAVE_PATH)
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to open save for read (%s)." % SAVE_PATH)
		return false

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: malformed save (not an object). Using defaults.")
		return false

	var data: Dictionary = parsed as Dictionary
	_apply_elements(data.get("elements", {}))
	_apply_research(data.get("research", {}))
	_apply_best_waves(data.get("best_waves", {}))

	if debug_save:
		print("SaveManager: loaded meta progression from %s" % SAVE_PATH)
	return true


func _save_internal() -> bool:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"elements": _serialize_elements(),
		"research": _serialize_research(),
		"best_waves": _serialize_best_waves(),
	}
	var json_text: String = JSON.stringify(payload, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open save for write (%s)." % SAVE_PATH)
		return false
	file.store_string(json_text)
	file.close()
	if debug_save:
		print("SaveManager: wrote %s" % SAVE_PATH)
	return true


func _serialize_elements() -> Dictionary:
	var out: Dictionary = {}
	var inventory: ElementInventory = _get_inventory()
	if inventory == null:
		for element_id: StringName in ElementIds.ALL:
			out[String(element_id)] = 0
		return out
	var all_amounts: Dictionary = inventory.get_all_elements()
	for element_id: StringName in ElementIds.ALL:
		out[String(element_id)] = int(all_amounts.get(element_id, 0))
	return out


func _serialize_research() -> Dictionary:
	var research: ResearchManager = _get_research()
	var unlocked: Array = []
	if research != null:
		for research_id: StringName in research.get_unlocked_ids():
			unlocked.append(String(research_id))
	return {"unlocked": unlocked}


func _serialize_best_waves() -> Dictionary:
	var levels: LevelManager = _get_levels()
	if levels == null:
		return {}
	return levels.serialize_best_waves()


func _apply_elements(raw: Variant) -> void:
	var inventory: ElementInventory = _get_inventory()
	if inventory == null:
		return
	if typeof(raw) != TYPE_DICTIONARY:
		inventory.apply_saved_amounts({})
		return
	inventory.apply_saved_amounts(raw as Dictionary)


func _apply_research(raw: Variant) -> void:
	var research: ResearchManager = _get_research()
	if research == null:
		return
	if typeof(raw) != TYPE_DICTIONARY:
		research.apply_saved_unlocks([])
		return
	var unlocked_raw: Variant = (raw as Dictionary).get("unlocked", [])
	var ids: Array[StringName] = []
	if typeof(unlocked_raw) == TYPE_ARRAY:
		for entry: Variant in unlocked_raw:
			ids.append(StringName(str(entry)))
	research.apply_saved_unlocks(ids)


func _apply_best_waves(raw: Variant) -> void:
	var levels: LevelManager = _get_levels()
	if levels == null:
		return
	if typeof(raw) != TYPE_DICTIONARY:
		levels.apply_saved_best_waves({})
		return
	levels.apply_saved_best_waves(raw as Dictionary)


func _get_inventory() -> ElementInventory:
	if GameManager == null:
		return null
	return GameManager.get_element_inventory()


func _get_research() -> ResearchManager:
	if GameManager == null:
		return null
	return GameManager.get_research_manager()


func _get_levels() -> LevelManager:
	if GameManager == null:
		return null
	return GameManager.get_level_manager()
