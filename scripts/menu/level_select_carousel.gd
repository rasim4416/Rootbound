## Horizontal level carousel — mouse wheel slides between cards with smooth focus animation.
class_name LevelSelectCarousel
extends Control

signal focused_index_changed(index: int)

@export var card_width: float = 440.0
@export var card_gap: float = 32.0
@export var scroll_smoothness: float = 12.0

var _track: Control
var _index: int = 0
var _scroll_x: float = 0.0
var _target_x: float = 0.0
var _card_count: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_track = Control.new()
	_track.name = "Track"
	add_child(_track)
	set_process(true)


func set_cards(cards: Array[Control]) -> void:
	for child: Node in _track.get_children():
		child.queue_free()
	for card: Control in cards:
		if card == null:
			continue
		_track.add_child(card)
	_card_count = cards.size()
	_index = clampi(_index, 0, maxi(_card_count - 1, 0))
	call_deferred("_refresh_layout", true)


func get_focused_index() -> int:
	return _index


func slide(direction: int) -> void:
	if _card_count <= 0:
		return
	var next: int = clampi(_index + direction, 0, _card_count - 1)
	if next == _index:
		return
	_index = next
	_refresh_layout(false)
	focused_index_changed.emit(_index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed:
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			slide(-1)
			accept_event()
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			slide(1)
			accept_event()
	elif event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		if absf(pan.delta.y) > absf(pan.delta.x):
			if pan.delta.y > 0.0:
				slide(1)
			else:
				slide(-1)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_layout(false)


func _process(delta: float) -> void:
	if _card_count <= 0:
		return
	var weight: float = 1.0 - exp(-scroll_smoothness * delta)
	_scroll_x = lerpf(_scroll_x, _target_x, weight)
	_track.position.x = _scroll_x
	_update_card_focus()


func _refresh_layout(instant: bool) -> void:
	if _track == null or _card_count <= 0:
		return
	var x: float = 0.0
	for i: int in range(_track.get_child_count()):
		var card := _track.get_child(i) as Control
		if card == null:
			continue
		card.custom_minimum_size = Vector2(card_width, size.y)
		card.size = Vector2(card_width, size.y)
		card.pivot_offset = Vector2(card_width * 0.5, card.size.y * 0.5)
		card.position = Vector2(x, size.y * 0.5 - card.size.y * 0.5)
		x += card_width + card_gap

	var center: float = size.x * 0.5
	var card_center_x: float = float(_index) * (card_width + card_gap) + card_width * 0.5
	_target_x = center - card_center_x
	if instant:
		_scroll_x = _target_x
		_track.position.x = _scroll_x
	_update_card_focus()


func _update_card_focus() -> void:
	if _track == null:
		return
	var center_x: float = size.x * 0.5
	for i: int in range(_track.get_child_count()):
		var card := _track.get_child(i) as Control
		if card == null:
			continue
		var card_center: float = _track.position.x + card.position.x + card_width * 0.5
		var dist: float = absf(card_center - center_x)
		var t: float = clampf(dist / (card_width + card_gap), 0.0, 1.0)
		var scale_factor: float = lerpf(1.0, 0.88, t)
		var alpha: float = lerpf(1.0, 0.52, t)
		card.scale = Vector2(scale_factor, scale_factor)
		card.modulate = Color(1.0, 1.0, 1.0, alpha)
