## Full level blob authored by the Dev Level Editor.
class_name EditorMapData
extends Resource

enum PlacementMode {
	SLOTS_ONLY,
	FREE,
}

@export_group("Map")
@export var map_id: StringName = &"dev_level"
@export var map_name: String = "Dev Level"
@export var grid_columns: int = 18
@export var grid_rows: int = 10
@export var cell_size: Vector2 = Vector2(64, 64)

@export_group("Start")
@export var starting_bio_energy: float = 100.0
@export var nucleus_max_health: float = 100.0
@export var starting_wave: int = 1
@export var maximum_wave: int = 0 ## 0 = unlimited

@export_group("Difficulty")
@export var level_hp_multiplier: float = 1.0
@export var level_speed_multiplier: float = 1.0
@export var level_core_damage_multiplier: float = 1.0

@export_group("Placement")
@export var placement_mode: PlacementMode = PlacementMode.SLOTS_ONLY
@export var restrict_build_to_slots: bool = true

@export_group("Content")
@export var paths: Array[EditorPathData] = []
@export var waves: Array[WaveData] = []
@export var turret_slots: Array[EditorTurretSlot] = []
@export var spawn_profiles: Array[EditorSpawnProfile] = []
@export var placed_objects: Array[EditorPlacedObject] = []
## Sparse flags: key "x,y" → true
@export var blocked_cells: Dictionary = {}
@export var non_buildable_cells: Dictionary = {}

@export_group("Pools")
@export var available_enemy_ids: Array[StringName] = [&"ant", &"virus"]
@export var available_plant_ids: Array[StringName] = [&"clover", &"thornbush", &"support_nanobot"]


func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func is_blocked(cell: Vector2i) -> bool:
	return blocked_cells.has(cell_key(cell))


func is_non_buildable(cell: Vector2i) -> bool:
	return non_buildable_cells.has(cell_key(cell))


func set_blocked(cell: Vector2i, value: bool) -> void:
	var k: String = cell_key(cell)
	if value:
		blocked_cells[k] = true
	else:
		blocked_cells.erase(k)


func set_non_buildable(cell: Vector2i, value: bool) -> void:
	var k: String = cell_key(cell)
	if value:
		non_buildable_cells[k] = true
	else:
		non_buildable_cells.erase(k)


func find_path(path_id: StringName) -> EditorPathData:
	for p: EditorPathData in paths:
		if p != null and p.path_id == path_id:
			return p
	return null


func find_slot_at(cell: Vector2i) -> EditorTurretSlot:
	for s: EditorTurretSlot in turret_slots:
		if s != null and s.cell == cell:
			return s
	return null


func get_all_grid_paths() -> Array[GridPathData]:
	var out: Array[GridPathData] = []
	for p: EditorPathData in paths:
		if p == null or p.cells.size() < 2:
			continue
		out.append(p.to_grid_path())
	return out


## Typed deep copy (avoid overriding Resource.duplicate_deep).
func clone_deep() -> EditorMapData:
	var copy := EditorMapData.new()
	copy.map_id = map_id
	copy.map_name = map_name
	copy.grid_columns = grid_columns
	copy.grid_rows = grid_rows
	copy.cell_size = cell_size
	copy.starting_bio_energy = starting_bio_energy
	copy.nucleus_max_health = nucleus_max_health
	copy.starting_wave = starting_wave
	copy.maximum_wave = maximum_wave
	copy.level_hp_multiplier = level_hp_multiplier
	copy.level_speed_multiplier = level_speed_multiplier
	copy.level_core_damage_multiplier = level_core_damage_multiplier
	copy.placement_mode = placement_mode
	copy.restrict_build_to_slots = restrict_build_to_slots
	copy.blocked_cells = blocked_cells.duplicate(true)
	copy.non_buildable_cells = non_buildable_cells.duplicate(true)
	copy.available_enemy_ids = available_enemy_ids.duplicate()
	copy.available_plant_ids = available_plant_ids.duplicate()
	for p: EditorPathData in paths:
		if p != null:
			copy.paths.append(p.clone_deep())
	for w: WaveData in waves:
		if w != null:
			copy.waves.append(w.duplicate(true) as WaveData)
	for s: EditorTurretSlot in turret_slots:
		if s != null:
			copy.turret_slots.append(s.clone_deep())
	for sp: EditorSpawnProfile in spawn_profiles:
		if sp != null:
			copy.spawn_profiles.append(sp.clone_deep())
	for o: EditorPlacedObject in placed_objects:
		if o != null:
			copy.placed_objects.append(o.clone_deep())
	return copy
