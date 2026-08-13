## World-space install progress bar above a Nanobot or Organelle.
## Visible only while INSTALLING. Unit spawns at full size; this bar fills over time.
class_name InstallProgressBar
extends Node2D

@export var bar_width: float = 44.0
@export var bar_height: float = 6.0
@export var y_offset: float = -38.0
@export var label_text: String = "Installing"
@export var label_font_size: int = 11
@export var background_color: Color = Color(0.06, 0.08, 0.10, 0.85)
@export var fill_color: Color = Color(0.35, 0.85, 0.95, 0.95)
@export var border_color: Color = Color(0.15, 0.35, 0.45, 0.95)
@export var label_color: Color = Color(0.78, 0.94, 1.0, 0.95)

var _host: Node2D = null
var _ratio: float = 0.0


func _ready() -> void:
	_host = get_parent() as Node2D
	if _host == null:
		push_error("InstallProgressBar: parent must be a Node2D host.")
		queue_free()
		return
	position = Vector2(0.0, y_offset)
	z_index = 15
	visible = false
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	if _host == null or not is_instance_valid(_host):
		return

	global_rotation = 0.0
	global_position = _host.global_position + Vector2(0.0, y_offset)

	var installing: bool = false
	var progress: float = 0.0

	var plant := _host as Plant
	if plant != null:
		installing = plant.is_alive and plant.install_state == Plant.InstallState.INSTALLING
		progress = plant.get_install_progress()
	else:
		var organel := _host as Organel
		if organel != null:
			installing = organel.is_alive and organel.install_state == Organel.InstallState.INSTALLING
			progress = organel.get_install_progress()

	_ratio = clampf(progress, 0.0, 1.0)
	visible = installing
	if installing:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var font: Font = ThemeDB.fallback_font
	if font != null and label_text != "":
		var label_y: float = -bar_height - 6.0
		var text_size: Vector2 = font.get_string_size(
			label_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			label_font_size
		)
		draw_string(
			font,
			Vector2(-text_size.x * 0.5, label_y),
			label_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			label_font_size,
			label_color
		)

	var half_w: float = bar_width * 0.5
	var bg := Rect2(Vector2(-half_w, -bar_height * 0.5), Vector2(bar_width, bar_height))
	draw_rect(bg, background_color, true)
	draw_rect(bg, border_color, false, 1.0)

	if _ratio <= 0.0:
		return

	var fill_w: float = bar_width * _ratio
	var fill := Rect2(Vector2(-half_w, -bar_height * 0.5), Vector2(fill_w, bar_height))
	draw_rect(fill, fill_color, true)
