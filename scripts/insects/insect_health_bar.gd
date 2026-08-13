## World-space HP bar drawn above an Insect.
##
## Listens to Insect.health_changed. Presentation only — does not own health.
class_name InsectHealthBar
extends Node2D

@export var bar_width: float = 28.0
@export var bar_height: float = 4.0
@export var y_offset: float = -22.0
@export var background_color: Color = Color(0.08, 0.05, 0.08, 0.75)
@export var fill_healthy: Color = Color(0.35, 0.85, 0.40, 0.95)
@export var fill_hurt: Color = Color(0.95, 0.75, 0.20, 0.95)
@export var fill_critical: Color = Color(0.90, 0.25, 0.30, 0.95)
@export var border_color: Color = Color(0.05, 0.05, 0.08, 0.9)

var _insect: Insect = null
var _ratio: float = 1.0


func _ready() -> void:
	_insect = get_parent() as Insect
	if _insect == null:
		push_error("InsectHealthBar: parent must be an Insect.")
		return
	position = Vector2(0.0, y_offset)
	if not _insect.health_changed.is_connected(_on_health_changed):
		_insect.health_changed.connect(_on_health_changed)
	_sync_from_insect()
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	# Keep the bar upright while the pathogen faces along the path.
	if _insect != null and is_instance_valid(_insect):
		global_rotation = 0.0
		global_position = _insect.global_position + Vector2(0.0, y_offset)


func _on_health_changed(current_health: float, max_health: float) -> void:
	if max_health <= 0.0:
		_ratio = 0.0
	else:
		_ratio = clampf(current_health / max_health, 0.0, 1.0)
	visible = _insect != null and _insect.is_alive
	queue_redraw()


func _sync_from_insect() -> void:
	if _insect == null:
		return
	var max_hp: float = _insect.get_max_health()
	_on_health_changed(_insect.current_health, max_hp)


func _draw() -> void:
	if not visible:
		return

	var half_w: float = bar_width * 0.5
	var bg := Rect2(Vector2(-half_w, -bar_height * 0.5), Vector2(bar_width, bar_height))
	draw_rect(bg, background_color, true)
	draw_rect(bg, border_color, false, 1.0)

	if _ratio <= 0.0:
		return

	var fill_w: float = bar_width * _ratio
	var fill := Rect2(Vector2(-half_w, -bar_height * 0.5), Vector2(fill_w, bar_height))
	draw_rect(fill, _fill_color_for_ratio(_ratio), true)


func _fill_color_for_ratio(ratio: float) -> Color:
	if ratio > 0.55:
		return fill_healthy
	if ratio > 0.25:
		return fill_hurt
	return fill_critical
