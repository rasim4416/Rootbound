## Owns the currently selected LevelData for the session and level unlock / best-wave meta.
class_name LevelManager
extends Node

signal level_loaded(level: LevelData)
signal best_wave_changed(level_id: StringName, best_wave: int)

## Catalog of selectable levels (menu reads this).
var available_levels: Array[LevelData] = []

var _current_level: LevelData = null
## Persistent best wave per level_id (loaded/saved via SaveManager).
var _best_wave_by_level: Dictionary = {}


func _ready() -> void:
	_load_catalog()


func _load_catalog() -> void:
	available_levels.clear()
	var paths: Array[String] = [
		"res://data/levels/level_01.tres",
		"res://data/levels/level_02.tres",
		"res://data/levels/level_03.tres",
		"res://data/levels/level_04.tres",
	]
	for path: String in paths:
		var loaded: Resource = load(path)
		var level := loaded as LevelData
		if level == null:
			push_error("LevelManager: failed to load LevelData at %s" % path)
			continue
		available_levels.append(level)


## Selects the level used by the next gameplay session / restart.
func load_level(level_data: LevelData) -> void:
	if level_data == null:
		push_error("LevelManager.load_level: level_data is null.")
		return
	if not is_level_unlocked(level_data):
		push_warning("LevelManager: refused locked level '%s'." % level_data.level_id)
		return
	_current_level = level_data
	level_loaded.emit(_current_level)


func get_current_level() -> LevelData:
	return _current_level


func has_level_loaded() -> bool:
	return _current_level != null


func clear_level() -> void:
	_current_level = null


func is_level_unlocked(level: LevelData) -> bool:
	if level == null:
		return false
	if level.is_unlocked_by_default():
		return true
	var best: int = get_best_wave(level.unlock_required_level_id)
	return best >= level.unlock_required_best_wave


func get_best_wave(level_id: StringName) -> int:
	return int(_best_wave_by_level.get(level_id, 0))


func record_best_wave(level_id: StringName, wave_number: int) -> void:
	if level_id == &"" or wave_number <= 0:
		return
	var previous: int = get_best_wave(level_id)
	if wave_number <= previous:
		return
	_best_wave_by_level[level_id] = wave_number
	best_wave_changed.emit(level_id, wave_number)
	if GameManager != null:
		var save: SaveManager = GameManager.get_save_manager()
		if save != null:
			save.save_now()


func apply_saved_best_waves(raw: Dictionary) -> void:
	_best_wave_by_level.clear()
	for key: Variant in raw.keys():
		_best_wave_by_level[StringName(str(key))] = int(raw[key])


func serialize_best_waves() -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in _best_wave_by_level.keys():
		out[String(key)] = int(_best_wave_by_level[key])
	return out


## Snapshot for future Level Select UI (name, lock, requirement, best wave).
func get_level_select_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for level: LevelData in available_levels:
		entries.append({
			"level_id": level.level_id,
			"display_name": level.display_name,
			"unlocked": is_level_unlocked(level),
			"unlock_required_level_id": level.unlock_required_level_id,
			"unlock_required_best_wave": level.unlock_required_best_wave,
			"best_wave": get_best_wave(level.level_id),
			"level": level,
		})
	return entries
