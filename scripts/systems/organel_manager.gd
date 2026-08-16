## Places Organelles on the shared grid and handles organelle selection/inspection.
class_name OrganelManager
extends Node

signal organel_selected(organel: Organel)
signal organel_deselected

@export var grid: GridManager
@export var organel_layer: Node2D
@export var organel_selection: OrganelSelectionManager
@export var seed_selection: SeedSelectionManager

var _selected_organel: Organel = null
var _occupancy: Dictionary = {} ## Vector2i → Organel


func _ready() -> void:
	if grid == null or organel_layer == null:
		push_error("OrganelManager: grid or organel_layer is null.")
	if organel_selection == null:
		push_error("OrganelManager: organel_selection is null.")


func _unhandled_input(event: InputEvent) -> void:
	if GameManager != null and GameManager.is_game_over():
		return
	if _is_path_dev_active():
		return
	if _is_placement_drag_active():
		return
	if grid == null or organel_layer == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var world: Vector2 = grid.get_global_mouse_position()
			if organel_selection != null and organel_selection.has_selection():
				if _try_place_at(world):
					get_viewport().set_input_as_handled()
			elif seed_selection == null or not seed_selection.has_selection():
				if _try_select_at(world):
					get_viewport().set_input_as_handled()


func get_selected_organel() -> Organel:
	if _selected_organel != null and is_instance_valid(_selected_organel) and _selected_organel.is_alive:
		return _selected_organel
	return null


func _try_place_at(world_position: Vector2) -> bool:
	if GameManager != null and GameManager.is_game_over():
		return false
	if organel_selection == null or not organel_selection.has_selection():
		return false

	var selected_data: OrganelData = organel_selection.get_selected_organel_data()
	if selected_data == null:
		return false

	var resources: ResourceManager = _get_resources()
	if resources == null:
		return false
	if resources.get_organelle_count(selected_data) < 1:
		return false

	var cell: Vector2i = grid.world_to_grid(world_position)
	if not grid.is_placeable(cell):
		return false

	if not resources.spend_organelle(selected_data):
		return false

	if not _place_organel(cell, selected_data):
		resources.add_organelle(selected_data, 1)
		return false

	organel_selection.clear_selection()
	return true


func _try_select_at(world_position: Vector2) -> bool:
	var cell: Vector2i = grid.world_to_grid(world_position)
	if not grid.is_in_bounds(cell):
		_clear_selection()
		return false
	var organel: Organel = _occupancy.get(cell, null) as Organel
	if organel == null or not is_instance_valid(organel) or not organel.is_alive:
		_clear_selection()
		return false
	_selected_organel = organel
	organel_selected.emit(organel)
	return true


func _clear_selection() -> void:
	if _selected_organel == null:
		return
	_selected_organel = null
	organel_deselected.emit()


## Places an owned Organelle unit onto an exact grid cell (Fabricator Buy).
func place_owned_at_cell(cell: Vector2i, organel_data: OrganelData) -> bool:
	if GameManager != null and GameManager.is_game_over():
		return false
	if grid == null or organel_data == null:
		return false
	if not grid.is_placeable(cell):
		return false

	var resources: ResourceManager = _get_resources()
	if resources == null or resources.get_organelle_count(organel_data) < 1:
		return false
	if not resources.spend_organelle(organel_data):
		return false
	if not _place_organel(cell, organel_data):
		resources.add_organelle(organel_data, 1)
		return false
	if organel_selection != null:
		organel_selection.clear_selection()
	return true


func _place_organel(cell: Vector2i, organel_data: OrganelData) -> bool:
	if organel_data == null:
		return false
	var scene: PackedScene = organel_data.runtime_scene
	if scene == null:
		push_warning("OrganelManager: missing runtime_scene for %s" % organel_data.organelle_id)
		return false

	var organel := scene.instantiate() as Organel
	if organel == null:
		push_error("OrganelManager: runtime_scene root must use Organel script.")
		return false

	organel.initialize(organel_data)
	organel.global_position = grid.grid_to_world_center(cell)
	organel_layer.add_child(organel)
	organel.install()
	grid.mark_occupied(cell)
	_occupancy[cell] = organel
	organel.tree_exiting.connect(_on_organel_exiting.bind(cell, organel))
	organel.died.connect(_on_organel_died.bind(organel))
	return true


func _on_organel_died(organel: Organel) -> void:
	if organel == _selected_organel:
		_clear_selection()
	if is_instance_valid(organel):
		organel.queue_free()


func _on_organel_exiting(cell: Vector2i, organel: Organel) -> void:
	if _occupancy.get(cell, null) == organel:
		_occupancy.erase(cell)
		if grid != null:
			grid.mark_free(cell)
	if _selected_organel == organel:
		_clear_selection()


func _get_resources() -> ResourceManager:
	if GameManager == null:
		return null
	return GameManager.get_resource_manager()


func _is_placement_drag_active() -> bool:
	if get_tree() == null:
		return false
	for node: Node in get_tree().get_nodes_in_group("placement_drag_controller"):
		var controller := node as PlacementDragController
		if controller != null and controller.is_dragging():
			return true
	return false


func _is_path_dev_active() -> bool:
	if get_tree() == null:
		return false
	for node: Node in get_tree().get_nodes_in_group("path_dev_mode"):
		if node != null and node.get("is_active") == true:
			return true
	for node2: Node in get_tree().get_nodes_in_group("dev_editor"):
		if node2 != null and bool(node2.get("is_active")) and not bool(node2.get("is_playtesting")):
			return true
	for node3: Node in get_tree().get_nodes_in_group("wave_designer"):
		if node3 != null and bool(node3.get("is_active")):
			return true
	for node4: Node in get_tree().get_nodes_in_group("research_designer"):
		if node4 != null and bool(node4.get("is_active")):
			return true
	return false


## Dev Editor playtest: remove all placed organelles.
func clear_all_placed() -> void:
	_clear_selection()
	var items: Array = _occupancy.values()
	_occupancy.clear()
	for o: Variant in items:
		if o != null and is_instance_valid(o):
			(o as Node).queue_free()


## Dev Editor: place organelle without inventory spend.
func dev_place_at_cell(cell: Vector2i, organelle_id: StringName) -> bool:
	if grid == null or organelle_id == &"":
		return false
	var path: String = "res://data/organelles/%s.tres" % String(organelle_id)
	if not ResourceLoader.exists(path):
		push_warning("OrganelManager.dev_place_at_cell: missing %s" % path)
		return false
	var data: OrganelData = load(path) as OrganelData
	if data == null:
		return false
	var was_restrict: bool = grid.restrict_build_to_slots
	grid.restrict_build_to_slots = false
	var ok: bool = false
	if grid.is_in_bounds(cell) and not grid.is_occupied(cell) and not grid.is_path_cell(cell):
		ok = _place_organel(cell, data)
	grid.restrict_build_to_slots = was_restrict
	return ok
