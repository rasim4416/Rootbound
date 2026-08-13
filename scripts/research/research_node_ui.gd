## Visual research-tree node with character portrait and glass frame styling.
class_name ResearchNodeUI
extends Control

signal node_selected(node_id: StringName)

enum NodeType {
	STRUCTURE,
	UPGRADE,
}

enum VisualState {
	LOCKED,
	AVAILABLE,
	UNLOCKED,
	SELECTED,
}

@export var node_id: StringName = &""
@export var node_type: NodeType = NodeType.STRUCTURE
@export var parent_node_ids: Array[StringName] = []
## Editor/preview only. Runtime UI shows names in the detail panel on click.
@export var fallback_display_name: String = ""

@export_group("Size")
@export var tile_size: Vector2 = Vector2(80, 80)

var _selected: bool = false
var _visual_state: VisualState = VisualState.LOCKED
var _title: String = ""
var _portrait: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_apply_square_size()
	_portrait = ResearchPortraits.get_portrait(node_id)
	_refresh_from_manager()
	gui_input.connect(_on_gui_input)
	if GameManager != null:
		var research: ResearchManager = GameManager.get_research_manager()
		if research != null and not research.research_unlocked.is_connected(_on_research_unlocked):
			research.research_unlocked.connect(_on_research_unlocked)
		var inventory: ElementInventory = GameManager.get_element_inventory()
		if inventory != null and not inventory.inventory_changed.is_connected(_on_inventory_changed):
			inventory.inventory_changed.connect(_on_inventory_changed)
	queue_redraw()


func get_node_id() -> StringName:
	return node_id


func get_parent_node_ids() -> Array[StringName]:
	return parent_node_ids.duplicate()


func get_center_local() -> Vector2:
	return size * 0.5


func get_center_in(parent_control: Control) -> Vector2:
	if parent_control == null:
		return global_position + size * 0.5
	return parent_control.get_global_transform_with_canvas().affine_inverse() * (global_position + size * 0.5)


func set_selected(selected: bool) -> void:
	_selected = selected
	_refresh_from_manager()


func is_selected() -> bool:
	return _selected


func get_visual_state() -> VisualState:
	return _visual_state


func refresh() -> void:
	_refresh_from_manager()


func _apply_square_size() -> void:
	custom_minimum_size = tile_size
	if size.x < 8.0 or size.y < 8.0 or not is_equal_approx(size.x, size.y):
		size = tile_size


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			node_selected.emit(node_id)
			accept_event()


func _on_research_unlocked(_research_id: StringName) -> void:
	_refresh_from_manager()


func _on_inventory_changed() -> void:
	_refresh_from_manager()


func _refresh_from_manager() -> void:
	_title = fallback_display_name if fallback_display_name != "" else String(node_id)
	var research: ResearchManager = null
	if GameManager != null:
		research = GameManager.get_research_manager()
	if research != null:
		var data: ResearchData = research.get_research(node_id)
		if data != null and data.display_name != "":
			_title = data.display_name
		_visual_state = _compute_state(research)
	else:
		_visual_state = VisualState.LOCKED
	if _selected and _visual_state != VisualState.LOCKED:
		_visual_state = VisualState.SELECTED
	tooltip_text = _title
	queue_redraw()


func _compute_state(research: ResearchManager) -> VisualState:
	if node_id == &"":
		return VisualState.LOCKED
	if research.is_unlocked(node_id):
		return VisualState.UNLOCKED
	var data: ResearchData = research.get_research(node_id)
	if data == null:
		return VisualState.LOCKED
	if not data.unlockable:
		return VisualState.LOCKED
	for parent_id: StringName in parent_node_ids:
		if parent_id == &"":
			continue
		if not research.is_unlocked(parent_id):
			return VisualState.LOCKED
	return VisualState.AVAILABLE


func _draw() -> void:
	var colors: Dictionary = _colors_for_state()
	var rect := Rect2(Vector2.ZERO, size)
	var pad: float = 4.0 if node_type == NodeType.UPGRADE else 5.0

	# Drop shadow
	draw_rect(
		Rect2(rect.position + Vector2(1.0, 4.0), rect.size + Vector2(2.0, 2.0)),
		Color(0.0, 0.0, 0.0, 0.45),
		true
	)

	# Outer glow
	if _visual_state == VisualState.SELECTED or _visual_state == VisualState.UNLOCKED:
		draw_rect(rect.grow(3.0), colors["glow"], true)

	# Frame
	draw_rect(rect, colors["border"], false, 3.0)
	draw_rect(rect.grow(-1.5), colors["fill"], true)

	var portrait_rect := rect.grow(-pad)
	if _portrait != null:
		draw_texture_rect(_portrait, portrait_rect, false, colors["portrait"])
		# Subtle top highlight
		draw_rect(
			Rect2(portrait_rect.position, Vector2(portrait_rect.size.x, portrait_rect.size.y * 0.35)),
			Color(1.0, 1.0, 1.0, 0.06),
			true
		)
		if _visual_state == VisualState.LOCKED:
			draw_rect(portrait_rect, Color(0.02, 0.04, 0.08, 0.55), true)
	else:
		_draw_icon(colors["icon"], portrait_rect)

	if _visual_state == VisualState.SELECTED:
		draw_rect(rect.grow(-1.0), Color(1.0, 0.88, 0.45, 0.85), false, 2.0)


func _draw_icon(color: Color, area: Rect2) -> void:
	var c: Vector2 = area.position + area.size * 0.5
	var s: float = mini(area.size.x, area.size.y) * 0.28
	match String(node_id):
		_:
			var hex := PackedVector2Array()
			for i: int in range(6):
				var ang: float = -PI * 0.5 + float(i) * TAU / 6.0
				hex.append(c + Vector2(cos(ang), sin(ang)) * s)
			draw_colored_polygon(hex, color)


func _colors_for_state() -> Dictionary:
	match _visual_state:
		VisualState.UNLOCKED:
			return {
				"fill": Color(0.08, 0.16, 0.22, 0.92),
				"border": Color(0.35, 0.88, 0.95, 1.0),
				"glow": Color(0.20, 0.65, 0.75, 0.22),
				"portrait": Color(1.0, 1.0, 1.0, 1.0),
				"icon": Color(0.75, 0.98, 1.0, 0.95),
			}
		VisualState.AVAILABLE:
			return {
				"fill": Color(0.07, 0.12, 0.20, 0.94),
				"border": Color(0.70, 0.82, 1.0, 0.95),
				"glow": Color(0.35, 0.50, 0.95, 0.18),
				"portrait": Color(0.88, 0.92, 1.0, 0.96),
				"icon": Color(0.85, 0.92, 1.0, 0.92),
			}
		VisualState.SELECTED:
			return {
				"fill": Color(0.14, 0.22, 0.32, 0.96),
				"border": Color(1.0, 0.86, 0.42, 1.0),
				"glow": Color(1.0, 0.75, 0.25, 0.28),
				"portrait": Color(1.05, 1.02, 0.96, 1.0),
				"icon": Color(1.0, 0.96, 0.75, 0.98),
			}
		_:
			return {
				"fill": Color(0.05, 0.06, 0.09, 0.90),
				"border": Color(0.24, 0.28, 0.34, 0.85),
				"glow": Color(0.0, 0.0, 0.0, 0.0),
				"portrait": Color(0.32, 0.36, 0.42, 0.75),
				"icon": Color(0.40, 0.44, 0.50, 0.7),
			}
