## Draws glowing curved edges between ResearchNodeUI children.
class_name ResearchConnectionRenderer
extends Control

@export var graph_root: Control
@export var line_width: float = 2.5

var _nodes_by_id: Dictionary = {} ## StringName → ResearchNodeUI


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if graph_root == null:
		graph_root = get_parent() as Control
	_rebuild_index()
	if GameManager != null:
		var research: ResearchManager = GameManager.get_research_manager()
		if research != null and not research.research_unlocked.is_connected(_on_research_unlocked):
			research.research_unlocked.connect(_on_research_unlocked)
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _on_research_unlocked(_research_id: StringName) -> void:
	_rebuild_index()
	queue_redraw()


func _rebuild_index() -> void:
	_nodes_by_id.clear()
	if graph_root == null:
		return
	for child: Node in graph_root.get_children():
		var node := child as ResearchNodeUI
		if node == null or node.node_id == &"":
			continue
		_nodes_by_id[node.node_id] = node


func _draw() -> void:
	_rebuild_index()
	var research: ResearchManager = null
	if GameManager != null:
		research = GameManager.get_research_manager()

	for id: Variant in _nodes_by_id.keys():
		var child_node: ResearchNodeUI = _nodes_by_id[id] as ResearchNodeUI
		if child_node == null:
			continue
		for parent_id: StringName in child_node.get_parent_node_ids():
			if parent_id == &"" or not _nodes_by_id.has(parent_id):
				continue
			var parent_node: ResearchNodeUI = _nodes_by_id[parent_id] as ResearchNodeUI
			if parent_node == null:
				continue
			var from_pt: Vector2 = _center_of(parent_node)
			var to_pt: Vector2 = _center_of(child_node)
			var color: Color = _connection_color(research, parent_id, child_node.node_id)
			_draw_curved_connection(from_pt, to_pt, color)
			_draw_arrowhead(from_pt, to_pt, color)


func _center_of(node: ResearchNodeUI) -> Vector2:
	var global_center: Vector2 = node.global_position + node.size * 0.5
	return get_global_transform_with_canvas().affine_inverse() * global_center


func _draw_curved_connection(from_pt: Vector2, to_pt: Vector2, color: Color) -> void:
	var delta: Vector2 = to_pt - from_pt
	var ctrl_a: Vector2 = from_pt + Vector2(delta.x * 0.42, delta.y * 0.08)
	var ctrl_b: Vector2 = to_pt - Vector2(delta.x * 0.42, delta.y * 0.08)
	var glow: Color = Color(color.r, color.g, color.b, color.a * 0.25)
	_draw_bezier(from_pt, ctrl_a, ctrl_b, to_pt, glow, line_width * 3.2)
	_draw_bezier(from_pt, ctrl_a, ctrl_b, to_pt, color, line_width)


func _draw_bezier(
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	p3: Vector2,
	color: Color,
	width: float
) -> void:
	var segments: int = 20
	var prev: Vector2 = p0
	for i: int in range(1, segments + 1):
		var t: float = float(i) / float(segments)
		var u: float = 1.0 - t
		var pt: Vector2 = (
			u * u * u * p0
			+ 3.0 * u * u * t * p1
			+ 3.0 * u * t * t * p2
			+ t * t * t * p3
		)
		draw_line(prev, pt, color, width, true)
		prev = pt


func _connection_color(research: ResearchManager, parent_id: StringName, child_id: StringName) -> Color:
	if research == null:
		return Color(0.35, 0.40, 0.48, 0.55)
	var parent_unlocked: bool = research.is_unlocked(parent_id)
	var child_unlocked: bool = research.is_unlocked(child_id)
	if parent_unlocked and child_unlocked:
		return Color(0.45, 0.92, 0.95, 0.95)
	if parent_unlocked:
		return Color(0.75, 0.85, 1.0, 0.85)
	return Color(0.30, 0.34, 0.40, 0.45)


func _draw_arrowhead(from_pt: Vector2, to_pt: Vector2, color: Color) -> void:
	var dir: Vector2 = to_pt - from_pt
	if dir.length_squared() < 4.0:
		return
	dir = dir.normalized()
	var tip: Vector2 = to_pt - dir * 18.0
	var side: Vector2 = dir.orthogonal() * 6.0
	var points := PackedVector2Array([
		to_pt - dir * 8.0,
		tip + side,
		tip - side,
	])
	draw_colored_polygon(points, color)
