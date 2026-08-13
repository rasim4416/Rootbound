## Blinking green up-arrow above a Nanobot when it has a pending level-up.
## Click opens that Nanobot's upgrade menu only (not a global queue).
class_name NanobotUpgradeIndicator
extends Node2D

@export var arrow_size: float = 10.0
@export var offset: Vector2 = Vector2(22.0, -26.0)
@export var arrow_color: Color = Color(0.25, 0.92, 0.35, 1.0)
@export var click_radius: float = 16.0

var _plant: Plant = null
var _blink_t: float = 0.0


func _ready() -> void:
	_plant = get_parent() as Plant
	if _plant == null:
		push_error("NanobotUpgradeIndicator: parent must be a Plant.")
		queue_free()
		return

	position = offset
	z_index = 20

	if not _plant.level_up_available.is_connected(_on_pending_changed):
		_plant.level_up_available.connect(_on_pending_changed)
	if not _plant.leveled_up.is_connected(_on_leveled_up):
		_plant.leveled_up.connect(_on_leveled_up)
	if not _plant.xp_changed.is_connected(_on_xp_changed):
		_plant.xp_changed.connect(_on_xp_changed)

	_refresh_visibility()
	set_process(true)
	set_process_input(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_blink_t += delta
	queue_redraw()
	global_rotation = 0.0


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if GameManager != null and GameManager.is_game_over():
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
			return
		var local: Vector2 = to_local(get_global_mouse_position())
		if local.length() <= click_radius:
			_open_this_bot_upgrades()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if not visible:
		return
	var pulse: float = 0.45 + 0.55 * absf(sin(_blink_t * TAU * 1.6))
	var color := arrow_color
	color.a = pulse

	var s: float = arrow_size
	var tip := Vector2(0.0, -s)
	var left := Vector2(-s * 0.7, s * 0.15)
	var right := Vector2(s * 0.7, s * 0.15)
	draw_colored_polygon(PackedVector2Array([tip, right, left]), color)

	var stem := Rect2(Vector2(-s * 0.22, s * 0.05), Vector2(s * 0.44, s * 0.85))
	draw_rect(stem, color, true)


func _on_pending_changed(_nanobot: Plant) -> void:
	_refresh_visibility()


func _on_leveled_up(_level: int, _upgrade: NanobotUpgradeData) -> void:
	_refresh_visibility()


func _on_xp_changed(_current: float, _to_next: float, _level: int) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	var show: bool = (
		_plant != null
		and is_instance_valid(_plant)
		and _plant.is_alive
		and _plant.has_pending_level_up()
	)
	visible = show
	if show:
		queue_redraw()


func _open_this_bot_upgrades() -> void:
	if _plant == null or not _plant.has_pending_level_up():
		return
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group("nanobot_level_up_controller"):
		var controller := node as NanobotLevelUpController
		if controller != null:
			controller.open_upgrade_menu(_plant)
			return
