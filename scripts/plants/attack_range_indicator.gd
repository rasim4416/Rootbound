## Faint attack-range circle shown while this combat Nanobot is selected or hovered.
class_name AttackRangeIndicator
extends Node2D

@export var fill_color: Color = Color(0.35, 0.85, 0.95, 0.12)
@export var edge_color: Color = Color(0.45, 0.95, 1.0, 0.40)
@export var edge_width: float = 2.0
## Alpha multiplier used when only hovered (no selection).
@export var hover_alpha_scale: float = 0.45

var _plant: Plant = null
var _show_range: bool = false
var _hovered: bool = false
var _radius: float = 0.0


func _ready() -> void:
	_plant = get_parent() as Plant
	if _plant == null:
		push_error("AttackRangeIndicator: parent must be a Plant.")
		queue_free()
		return
	add_to_group("attack_range_indicators")
	z_index = -1
	visible = false
	set_process(true)
	queue_redraw()


func set_range_visible(visible_flag: bool) -> void:
	_show_range = visible_flag
	_apply_visibility()


func set_hover_visible(visible_flag: bool) -> void:
	_hovered = visible_flag
	_apply_visibility()


func get_plant() -> Plant:
	return _plant


func _process(_delta: float) -> void:
	if not _is_requested():
		return
	global_rotation = 0.0
	_refresh_radius()
	queue_redraw()


func _apply_visibility() -> void:
	visible = _is_requested() and _can_show()
	_refresh_radius()
	queue_redraw()


func _is_requested() -> bool:
	return _show_range or _hovered


func _can_show() -> bool:
	if _plant == null or not is_instance_valid(_plant):
		return false
	if not _plant.is_alive:
		return false
	if _plant.is_support_nanobot():
		return false
	if _plant.data == null:
		return false
	return _plant.data.attack_range > 0.0


func _refresh_radius() -> void:
	if _plant == null or _plant.data == null:
		_radius = 0.0
		return
	_radius = maxf(
		_plant.get_effective_stat(StatIds.ATTACK_RANGE, _plant.data.attack_range),
		0.0
	)


func _draw() -> void:
	if not _is_requested() or not _can_show():
		return
	if _radius <= 0.0:
		return
	var fill: Color = fill_color
	var edge: Color = edge_color
	var width: float = edge_width
	if not _show_range:
		var scale_a: float = clampf(hover_alpha_scale, 0.0, 1.0)
		fill.a *= scale_a
		edge.a *= scale_a
		width = maxf(edge_width - 0.5, 1.0)
	draw_circle(Vector2.ZERO, _radius, fill)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 64, edge, width, true)
