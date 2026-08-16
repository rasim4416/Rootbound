## Applies EditorMapData onto the live Main gameplay systems.
class_name EditorMapApplier
extends RefCounted


static func apply(map: EditorMapData, main: Node) -> bool:
	if map == null or main == null:
		return false
	var grid: GridManager = main.get_node_or_null("Grid") as GridManager
	var wave_manager: WaveManager = main.get_node_or_null("WaveManager") as WaveManager
	var path_visual: PathVisual = main.get_node_or_null("Paths/PathVisual") as PathVisual
	var planting: PlantingAreaVisual = main.get_node_or_null("Grid/PlantingAreaVisual") as PlantingAreaVisual
	var core: Core = main.get_node_or_null("Core") as Core
	var plant_manager: PlantManager = main.get_node_or_null("PlantManager") as PlantManager
	var organel_manager: OrganelManager = main.get_node_or_null("OrganelManager") as OrganelManager

	if grid == null or wave_manager == null:
		return false

	grid.columns = map.grid_columns
	grid.rows = map.grid_rows
	grid.cell_size = map.cell_size
	grid.queue_redraw()

	if not wave_manager.apply_editor_map_data(map):
		return false

	var paths: Array[GridPathData] = map.get_all_grid_paths()
	grid.apply_grid_paths(paths)
	if path_visual != null:
		path_visual.apply_grid_paths(paths)
	if planting != null:
		planting.apply_grid_paths(paths)

	var primary: GridPathData = paths[0] if not paths.is_empty() else null
	if core != null and primary != null and not primary.cells.is_empty():
		var core_data := CoreData.new()
		core_data.core_id = &"level_nucleus"
		core_data.display_name = "Nucleus"
		core_data.max_health = map.nucleus_max_health
		core.initialize(core_data)
		var visual := core.get_node_or_null("Visual") as Node2D
		if visual != null:
			var end_cell: Vector2i = primary.cells[primary.cells.size() - 1]
			visual.global_position = grid.grid_to_world_center(end_cell) + Vector2(-10.0, 0.0)

	if GameManager != null:
		var resources: ResourceManager = GameManager.get_resource_manager()
		if resources != null:
			resources.biomass = int(map.starting_bio_energy)

	if plant_manager != null and plant_manager.has_method("clear_all_placed"):
		plant_manager.clear_all_placed()
	else:
		_clear_layer(main.get_node_or_null("PlantLayer"))
	if organel_manager != null and organel_manager.has_method("clear_all_placed"):
		organel_manager.clear_all_placed()
	else:
		_clear_layer(main.get_node_or_null("OrganelLayer"))
	grid.clear_all_occupancy()

	if plant_manager != null:
		for slot: EditorTurretSlot in map.turret_slots:
			if slot == null or not slot.enabled or not slot.starts_active or slot.plant_id == &"":
				continue
			_place_prebuilt_plant(plant_manager, grid, slot)

	if organel_manager != null:
		for obj: EditorPlacedObject in map.placed_objects:
			if obj == null:
				continue
			if obj.kind == EditorPlacedObject.ObjectKind.ORGANELLE:
				_place_organelle(organel_manager, obj)
			elif obj.kind == EditorPlacedObject.ObjectKind.GENERATOR and plant_manager != null:
				var gen_slot := EditorTurretSlot.new()
				gen_slot.cell = obj.cell
				gen_slot.plant_id = obj.data_id if obj.data_id != &"" else &"clover"
				gen_slot.starts_active = true
				gen_slot.enabled = true
				_place_prebuilt_plant(plant_manager, grid, gen_slot)

	return true


static func _clear_layer(layer: Node) -> void:
	if layer == null:
		return
	for c: Node in layer.get_children():
		c.queue_free()


static func _place_prebuilt_plant(pm: PlantManager, grid: GridManager, slot: EditorTurretSlot) -> void:
	# Prefer typed place API via reflection-safe path: spend-free place if available.
	if pm.has_method("dev_place_at_cell"):
		pm.call("dev_place_at_cell", slot.cell, slot.plant_id)
		return
	# Fallback: mark occupied only (visual spawn may be missing until PlantManager hook exists).
	if grid != null:
		grid.mark_occupied(slot.cell)


static func _place_organelle(om: OrganelManager, obj: EditorPlacedObject) -> void:
	if om.has_method("dev_place_at_cell"):
		om.call("dev_place_at_cell", obj.cell, obj.data_id)
