## Scene-local plant placement and Nanobot selection coordinator.
##
## Placement flow (left click with seed selected):
## 1. Require a selected seed from SeedSelectionManager.
## 2. Require at least one owned seed of that PlantData.
## 3. Convert mouse → grid cell; reject OOB / occupied (no seed spent).
## 4. Spend one typed seed, spawn Plant, mark occupied, start installation.
## 5. Clear seed selection on success.
##
## Selection flow (left click with no seed selected):
## Click an occupied Nanobot cell to inspect it.
## Click an empty in-bounds cell to open the Fabricator side panel.
class_name PlantManager
extends Node

signal nanobot_selected(nanobot: Plant)
signal nanobot_deselected
## Empty, in-bounds, unoccupied cell clicked with no seed selected.
signal empty_cell_clicked(cell: Vector2i)

@export var grid: GridManager
@export var plant_layer: Node2D
@export var seed_selection: SeedSelectionManager
@export var organel_selection: OrganelSelectionManager
@export var plant_scene: PackedScene

const _DEFAULT_PLANT_SCENE: PackedScene = preload("res://scenes/plants/plant.tscn")

var _selected_nanobot: Plant = null
var _occupancy: Dictionary = {} ## Vector2i → Plant


func _ready() -> void:
	if plant_scene == null:
		plant_scene = _DEFAULT_PLANT_SCENE

	if grid == null or plant_layer == null:
		push_error("PlantManager: grid or plant_layer is null — check scene NodePath exports.")
	if seed_selection == null:
		push_error("PlantManager: seed_selection is null — check scene NodePath exports.")


func _unhandled_input(event: InputEvent) -> void:
	if GameManager != null and GameManager.is_game_over():
		return
	if _is_placement_drag_active():
		return
	if grid == null or plant_layer == null or seed_selection == null:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var world: Vector2 = grid.get_global_mouse_position()
			if seed_selection.has_selection():
				if _try_place_at(world):
					get_viewport().set_input_as_handled()
			else:
				if _try_select_or_open_fabricator(world):
					get_viewport().set_input_as_handled()


func _try_place_at(world_position: Vector2) -> bool:
	if GameManager != null and GameManager.is_game_over():
		return false
	if not seed_selection.has_selection():
		return false

	var selected_data: PlantData = seed_selection.get_selected_plant_data()
	if selected_data == null:
		return false

	var resources: ResourceManager = _get_resources()
	if resources == null:
		return false
	if resources.get_seed_count(selected_data) < 1:
		return false

	var cell: Vector2i = grid.world_to_grid(world_position)
	if not grid.is_placeable(cell):
		return false

	if not resources.spend_seed(selected_data):
		return false

	if not _place_plant(cell, selected_data):
		resources.add_seed(selected_data, 1)
		return false

	seed_selection.clear_selection()
	return true


func _try_select_or_open_fabricator(world_position: Vector2) -> bool:
	var cell: Vector2i = grid.world_to_grid(world_position)
	if not grid.is_in_bounds(cell):
		_clear_selection()
		return false

	var nanobot: Plant = _occupancy.get(cell, null) as Plant
	if nanobot != null and is_instance_valid(nanobot) and nanobot.is_alive:
		_selected_nanobot = nanobot
		nanobot_selected.emit(nanobot)
		return true

	# Occupied by organelle (or other) — let OrganelManager handle selection.
	if grid.is_occupied(cell):
		_clear_selection()
		return false

	# Organelle placement mode — don't open Fabricator.
	if organel_selection != null and organel_selection.has_selection():
		_clear_selection()
		return false

	if grid.is_path_cell(cell):
		_clear_selection()
		return false

	_clear_selection()
	return false


func _is_placement_drag_active() -> bool:
	if get_tree() == null:
		return false
	for node: Node in get_tree().get_nodes_in_group("placement_drag_controller"):
		var controller := node as PlacementDragController
		if controller != null and controller.is_dragging():
			return true
	return false


func get_selected_nanobot() -> Plant:
	if _selected_nanobot != null and is_instance_valid(_selected_nanobot) and _selected_nanobot.is_alive:
		return _selected_nanobot
	return null


func _clear_selection() -> void:
	if _selected_nanobot == null:
		return
	_selected_nanobot = null
	nanobot_deselected.emit()


## Places an owned Nanobot unit onto an exact grid cell (Fabricator Buy).
## Spends one seed. Returns false without spending if the cell is invalid.
func place_owned_at_cell(cell: Vector2i, plant_data: PlantData) -> bool:
	if GameManager != null and GameManager.is_game_over():
		return false
	if grid == null or plant_data == null:
		return false
	if not grid.is_placeable(cell):
		return false

	var resources: ResourceManager = _get_resources()
	if resources == null or resources.get_seed_count(plant_data) < 1:
		return false
	if not resources.spend_seed(plant_data):
		return false
	if not _place_plant(cell, plant_data):
		resources.add_seed(plant_data, 1)
		return false
	if seed_selection != null:
		seed_selection.clear_selection()
	return true


func _place_plant(cell: Vector2i, plant_data: PlantData) -> bool:
	if plant_data == null:
		push_warning("PlantManager: missing plant_data.")
		return false

	var scene: PackedScene = plant_data.runtime_scene
	if scene == null:
		scene = plant_scene
	if scene == null:
		scene = _DEFAULT_PLANT_SCENE
	if scene == null:
		push_warning("PlantManager: missing plant_scene.")
		return false

	var plant := scene.instantiate() as Plant
	if plant == null:
		push_error("PlantManager: plant scene root must use the Plant script.")
		return false

	plant.initialize(plant_data)
	plant.global_position = grid.grid_to_world_center(cell)
	plant_layer.add_child(plant)
	plant.install()
	grid.mark_occupied(cell)
	_occupancy[cell] = plant
	plant.tree_exiting.connect(_on_plant_exiting.bind(cell, plant))

	var controllers: Array[Node] = get_tree().get_nodes_in_group("nanobot_level_up_controller")
	for node: Node in controllers:
		var controller := node as NanobotLevelUpController
		if controller != null:
			controller.register_nanobot(plant)

	return true


func _on_plant_exiting(cell: Vector2i, plant: Plant) -> void:
	if _occupancy.get(cell, null) == plant:
		_occupancy.erase(cell)
		if grid != null:
			grid.mark_free(cell)
	if _selected_nanobot == plant:
		_clear_selection()


func _get_resources() -> ResourceManager:
	if GameManager == null:
		return null
	return GameManager.get_resource_manager()
