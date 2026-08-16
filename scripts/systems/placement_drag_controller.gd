## Drag-from-shop placement: ghost preview, grid snap, purchase on valid drop.
class_name PlacementDragController
extends Node

signal drag_started(item: ShopItem)
signal drag_ended(item: ShopItem, placed: bool)

@export var grid: GridManager
@export var shop_manager: ShopManager
@export var plant_manager: PlantManager
@export var organel_manager: OrganelManager
@export var ghost_layer: Node2D
@export var shop_ui: ShopUI

const GHOST_BODY_SIZE: float = 42.0

var _dragging: bool = false
var _item: ShopItem = null
var _ghost: Sprite2D = null
var _cell_overlay: Node2D = null
var _hover_cell: Vector2i = Vector2i(-999, -999)
var _cell_valid: bool = false


func _ready() -> void:
	add_to_group("placement_drag_controller")
	set_process(false)


func is_dragging() -> bool:
	return _dragging


func begin_drag(item: ShopItem) -> void:
	if _dragging or item == null or not item.unlocked:
		return
	if GameManager != null and GameManager.is_game_over():
		return
	if _is_path_dev_active():
		return
	if shop_ui != null:
		shop_ui.hide_tooltip()
	_cancel_drag()
	_dragging = true
	_item = item
	_create_ghost(item)
	set_process(true)
	drag_started.emit(item)


func _process(_delta: float) -> void:
	if not _dragging or grid == null:
		return
	_update_hover_cell()
	if _ghost != null:
		_ghost.global_position = grid.grid_to_world_center(_hover_cell)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_finish_drag()
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_cancel_drag()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_drag()
		get_viewport().set_input_as_handled()


func _finish_drag() -> void:
	if not _dragging or _item == null:
		_cancel_drag()
		return
	var item: ShopItem = _item
	var placed: bool = false
	if _cell_valid and shop_manager != null:
		placed = shop_manager.try_purchase_and_place_at_cell(
			item, _hover_cell, plant_manager, organel_manager
		)
		if not placed and shop_ui != null:
			if not shop_manager.can_purchase(item):
				shop_ui.show_feedback("Not enough Bio-Energy")
			else:
				shop_ui.show_feedback("Cannot place here")
	_cancel_drag()
	drag_ended.emit(item, placed)
	if shop_ui != null:
		shop_ui.refresh_after_drag()


func _cancel_drag() -> void:
	var item: ShopItem = _item
	_dragging = false
	_item = null
	_hover_cell = Vector2i(-999, -999)
	_cell_valid = false
	set_process(false)
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	if _cell_overlay != null and is_instance_valid(_cell_overlay):
		_cell_overlay.queue_free()
	_cell_overlay = null
	if item != null:
		drag_ended.emit(item, false)


func _create_ghost(item: ShopItem) -> void:
	if ghost_layer == null:
		return
	var tex: Texture2D = _resolve_texture(item)
	_ghost = Sprite2D.new()
	_ghost.name = "PlacementGhost"
	_ghost.texture = tex
	_ghost.centered = true
	if tex != null:
		var tex_size: Vector2 = tex.get_size()
		var max_dim: float = maxf(tex_size.x, tex_size.y)
		if max_dim > 0.0:
			var scale_factor: float = GHOST_BODY_SIZE / max_dim
			_ghost.scale = Vector2(scale_factor, scale_factor)
	_ghost.modulate = Color(1, 1, 1, 0.72)
	_ghost.z_index = 50
	ghost_layer.add_child(_ghost)

	if grid != null:
		_cell_overlay = _CellOverlay.new()
		_cell_overlay.grid = grid
		_cell_overlay.z_index = 49
		grid.add_child(_cell_overlay)


func _update_hover_cell() -> void:
	var world: Vector2 = grid.get_global_mouse_position()
	var cell: Vector2i = grid.world_to_grid(world)
	if not grid.is_in_bounds(cell):
		_hover_cell = Vector2i(-999, -999)
		_cell_valid = false
		if _ghost != null:
			_ghost.modulate = Color(1.0, 0.45, 0.45, 0.72)
		if _cell_overlay != null and _cell_overlay is _CellOverlay:
			(_cell_overlay as _CellOverlay).clear_cell()
		return
	if cell == _hover_cell:
		return
	_hover_cell = cell
	_cell_valid = grid.is_placeable(cell)
	if _ghost != null:
		if _cell_valid:
			_ghost.modulate = Color(0.7, 1.0, 0.75, 0.82)
		else:
			_ghost.modulate = Color(1.0, 0.45, 0.45, 0.72)
	if _cell_overlay != null and _cell_overlay is _CellOverlay:
		(_cell_overlay as _CellOverlay).set_cell(_hover_cell, _cell_valid)


func _resolve_texture(item: ShopItem) -> Texture2D:
	if item.is_nanobot() and item.plant_data != null:
		return UnitGameplaySprites.get_plant_sprite(item.plant_data.plant_id)
	if item.is_organelle() and item.organel_data != null:
		return UnitGameplaySprites.get_organelle_sprite(item.organel_data.organelle_id)
	return null


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


class _CellOverlay extends Node2D:
	var grid: GridManager
	var _cell: Vector2i = Vector2i(-999, -999)
	var _valid: bool = false

	func set_cell(cell: Vector2i, valid: bool) -> void:
		_cell = cell
		_valid = valid
		queue_redraw()

	func clear_cell() -> void:
		_cell = Vector2i(-999, -999)
		queue_redraw()

	func _draw() -> void:
		if grid == null or _cell.x < 0 or not grid.is_in_bounds(_cell):
			return
		var origin: Vector2 = grid.grid_origin
		var cell_size: Vector2 = grid.cell_size
		var top_left: Vector2 = origin + Vector2(float(_cell.x) * cell_size.x, float(_cell.y) * cell_size.y)
		var rect := Rect2(top_left, cell_size).grow(-2.0)
		var fill: Color = Color(0.3, 0.95, 0.45, 0.28) if _valid else Color(0.95, 0.25, 0.25, 0.28)
		draw_rect(rect, fill, true)
		var border: Color = Color(0.5, 1.0, 0.55, 0.75) if _valid else Color(1.0, 0.35, 0.35, 0.75)
		draw_rect(rect, border, false, 2.0)
