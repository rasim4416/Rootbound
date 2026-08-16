## Research Lab — icon tree with pan/drag navigation (no scrollbars).
## Unlock/economy logic stays on ResearchManager + ElementInventory.
## Graph nodes spawn from the ResearchData catalog (same layout as F4).
extends Control

const _NODE_SCENE: PackedScene = preload("res://scenes/research/research_node.tscn")

@onready var _back_button: Button = %BackButton
@onready var _graph_viewport: Control = %GraphViewport
@onready var _graph_area: Control = %GraphArea
@onready var _pan_surface: Control = %PanSurface
@onready var _detail_panel: ResearchDetailPanel = %ResearchDetailPanel
@onready var _connection_renderer: ResearchConnectionRenderer = %Connections

var _nodes_by_id: Dictionary = {} ## StringName → ResearchNodeUI
var _selected_id: StringName = &""
var _panning: bool = false


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	if _detail_panel != null:
		_detail_panel.unlock_requested.connect(_on_unlock_requested)
		_detail_panel.closed.connect(_on_detail_closed)
	_spawn_graph_from_catalog()
	_ensure_element_display()
	if _connection_renderer != null:
		_connection_renderer.graph_root = _graph_area
	if _pan_surface != null:
		_pan_surface.gui_input.connect(_on_pan_surface_gui_input)
	if _graph_viewport != null:
		_graph_viewport.clip_contents = true
	_center_graph_on_start()
	if _nodes_by_id.has(&"center"):
		_on_node_selected(&"center")


func _spawn_graph_from_catalog() -> void:
	_nodes_by_id.clear()
	if _graph_area == null:
		return
	for child: Node in _graph_area.get_children():
		if child is ResearchNodeUI:
			_graph_area.remove_child(child)
			child.queue_free()
	var research: ResearchManager = null
	if GameManager != null:
		research = GameManager.get_research_manager()
	if research == null:
		return
	for data: ResearchData in research.get_all_research():
		if data == null or data.research_id == &"":
			continue
		var node: ResearchNodeUI = _NODE_SCENE.instantiate() as ResearchNodeUI
		if node == null:
			continue
		node.node_id = data.research_id
		node.parent_node_ids = data.prerequisite_ids.duplicate()
		node.fallback_display_name = data.display_name
		node.node_type = ResearchNodeUI.NodeType.UPGRADE if data.tier >= 2 else ResearchNodeUI.NodeType.STRUCTURE
		if data.tier >= 2:
			node.tile_size = Vector2(48, 48)
		else:
			node.tile_size = Vector2(80, 80)
		node.position = data.editor_position
		node.node_selected.connect(_on_node_selected)
		_graph_area.add_child(node)
		_nodes_by_id[data.research_id] = node
		node.refresh()


func _center_graph_on_start() -> void:
	if _graph_viewport == null or _graph_area == null:
		return
	var viewport_size: Vector2 = _graph_viewport.size
	if viewport_size.x < 8.0 or viewport_size.y < 8.0:
		viewport_size = Vector2(900, 600)
	_graph_area.position = Vector2(
		viewport_size.x * 0.5 - 600.0,
		viewport_size.y * 0.2 - 80.0
	)


func _ensure_element_display() -> void:
	if has_node("ElementInventoryDisplay"):
		return
	var display := ElementInventoryDisplay.new()
	display.name = "ElementInventoryDisplay"
	display.show_header = true
	display.header_text = "META MATERIALS"
	display.compact = true
	display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	display.offset_left = 16.0
	display.offset_top = 64.0
	display.offset_right = 146.0
	display.grow_horizontal = Control.GROW_DIRECTION_END
	display.custom_minimum_size = Vector2(130, 0)
	add_child(display)


func _on_pan_surface_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_panning = true
				_pan_surface.set_default_cursor_shape(Control.CURSOR_DRAG)
			else:
				_panning = false
				_pan_surface.set_default_cursor_shape(Control.CURSOR_ARROW)
			_pan_surface.accept_event()
	elif event is InputEventMouseMotion and _panning:
		var motion := event as InputEventMouseMotion
		if _graph_area != null:
			_graph_area.position += motion.relative
		_pan_surface.accept_event()


func _on_node_selected(node_id: StringName) -> void:
	_panning = false
	_selected_id = node_id
	for id: Variant in _nodes_by_id.keys():
		var node: ResearchNodeUI = _nodes_by_id[id] as ResearchNodeUI
		if node != null:
			node.set_selected(node.node_id == node_id)
	if _detail_panel != null:
		var research: ResearchManager = GameManager.get_research_manager() if GameManager != null else null
		var parents_ok: bool = research != null and research.prerequisites_met(node_id)
		_detail_panel.show_research(node_id, parents_ok)


func _on_detail_closed() -> void:
	_selected_id = &""
	for id: Variant in _nodes_by_id.keys():
		var node: ResearchNodeUI = _nodes_by_id[id] as ResearchNodeUI
		if node != null:
			node.set_selected(false)


func _on_unlock_requested(node_id: StringName) -> void:
	if GameManager == null:
		return
	var research: ResearchManager = GameManager.get_research_manager()
	if research == null:
		return
	if research.unlock(node_id):
		_refresh_all_nodes()
		if _detail_panel != null:
			_detail_panel.show_research(node_id, research.prerequisites_met(node_id))


func _refresh_all_nodes() -> void:
	for id: Variant in _nodes_by_id.keys():
		var node: ResearchNodeUI = _nodes_by_id[id] as ResearchNodeUI
		if node != null:
			node.refresh()


func _on_back_pressed() -> void:
	SceneRouter.to_main_menu(get_tree())
