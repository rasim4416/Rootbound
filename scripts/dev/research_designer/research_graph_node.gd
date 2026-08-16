## Draggable research node with left (in) / right (out) ports.
class_name ResearchGraphNode
extends Control

signal selected(research_id: StringName)
signal moved(research_id: StringName, position: Vector2)
signal move_ended()
signal output_drag_started(research_id: StringName)
signal input_released(research_id: StringName)
signal context_requested(research_id: StringName)

const SIZE := Vector2(168, 72)
const PORT: float = 8.0

var research_id: StringName = &""
var title: String = ""
var cost_text: String = ""
var portrait: Texture2D
var invalid: bool = false
var selected_visual: bool = false

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func is_dragging() -> bool:
	return _dragging


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = true
	mouse_default_cursor_shape = Control.CURSOR_MOVE


func setup(data: ResearchData, is_invalid: bool, is_selected: bool) -> void:
	research_id = data.research_id if data != null else &""
	title = data.display_name if data != null and not data.display_name.is_empty() else String(research_id)
	cost_text = data.cost_label() if data != null else ""
	portrait = data.resolve_icon() if data != null else null
	invalid = is_invalid
	selected_visual = is_selected
	position = data.editor_position if data != null else position
	queue_redraw()


func output_pos() -> Vector2:
	return Vector2(size.x, size.y * 0.5)


func input_pos() -> Vector2:
	return Vector2(0.0, size.y * 0.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			selected.emit(research_id)
			context_requested.emit(research_id)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				selected.emit(research_id)
				if _in_output(mb.position):
					output_drag_started.emit(research_id)
					accept_event()
					return
				_dragging = true
				_drag_offset = mb.position
				accept_event()
			else:
				if _dragging:
					_dragging = false
					move_ended.emit()
				if _in_input(mb.position):
					input_released.emit(research_id)
				accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		position = position + mm.position - _drag_offset
		moved.emit(research_id, position)
		queue_redraw()
		accept_event()


func _in_output(pos: Vector2) -> bool:
	return pos.distance_to(output_pos()) <= PORT + 6.0


func _in_input(pos: Vector2) -> bool:
	return pos.x <= 22.0


func _draw() -> void:
	var fill := Color(0.10, 0.14, 0.20, 0.96)
	var border := Color(0.40, 0.72, 0.90, 0.9)
	if selected_visual:
		border = Color(0.95, 0.92, 0.45, 1.0)
	if invalid:
		border = Color(0.95, 0.32, 0.28, 1.0)
		fill = Color(0.22, 0.08, 0.08, 0.96)
	draw_rect(Rect2(Vector2.ZERO, size), fill, true)
	draw_rect(Rect2(Vector2.ZERO, size), border, false, 2.0)
	var icon_rect := Rect2(12, 12, 48, 48)
	if portrait != null:
		draw_texture_rect(portrait, icon_rect, false)
	else:
		draw_rect(icon_rect, Color(0.18, 0.28, 0.36, 1.0), true)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(68, 28), title, HORIZONTAL_ALIGNMENT_LEFT, 92.0, 13, Color(0.9, 0.95, 1.0))
		draw_string(font, Vector2(68, 48), cost_text, HORIZONTAL_ALIGNMENT_LEFT, 92.0, 11, Color(0.65, 0.78, 0.88, 0.9))
	draw_circle(input_pos(), PORT, Color(0.35, 0.85, 0.55, 1.0))
	draw_circle(output_pos(), PORT, Color(0.95, 0.7, 0.3, 1.0))
