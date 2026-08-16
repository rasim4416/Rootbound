## Horizontal group bars; LMB drag changes WaveSpawnEntry.start_time.
class_name WaveTimeline
extends Control

signal group_selected(index: int)
signal group_start_changed(index: int, start_time: float)
signal group_drag_ended()
signal event_selected(index: int)

const _ROW_H: float = 28.0
const _PAD: float = 8.0
const _COLORS: Array[Color] = [
	Color(0.35, 0.85, 0.95),
	Color(0.95, 0.55, 0.35),
	Color(0.55, 0.95, 0.45),
	Color(0.85, 0.45, 0.95),
	Color(0.95, 0.85, 0.35),
	Color(0.45, 0.7, 1.0),
]
const _EVENT_COLORS: Array[Color] = [
	Color(0.95, 0.28, 0.28),
	Color(1.0, 0.55, 0.2),
	Color(1.0, 0.88, 0.25),
	Color(0.35, 0.9, 0.5),
	Color(0.75, 0.4, 1.0),
]

var wave: WaveData
var selected_group: int = 0
var selected_event: int = -1
var pixels_per_second: float = 24.0

var _drag_group: int = -1
var _drag_origin_x: float = 0.0
var _drag_origin_start: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(200, 120)
	clip_contents = false


func set_wave(w: WaveData, selected: int, event_index: int = -1) -> void:
	wave = w
	selected_group = selected
	selected_event = event_index
	_update_min_size()
	queue_redraw()


func _update_min_size() -> void:
	var max_t: float = 12.0
	if wave != null:
		max_t = maxf(WaveDesignerStats.last_spawn_at(wave) + 4.0, 12.0)
		if wave.special_events != null:
			for ev: WaveSpecialEvent in wave.special_events:
				if ev != null:
					max_t = maxf(max_t, maxf(ev.time, 0.0) + 2.0)
	custom_minimum_size.x = maxf(_PAD * 2.0 + max_t * pixels_per_second, 240.0)
	var rows: int = wave.spawn_entries.size() if wave != null else 0
	custom_minimum_size.y = maxf(120.0, _PAD + 28.0 + float(rows) * (_ROW_H + 4.0) + 8.0)


func _gui_input(event: InputEvent) -> void:
	if wave == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var ev_idx: int = _hit_event(mb.position)
				if ev_idx >= 0:
					selected_event = ev_idx
					event_selected.emit(ev_idx)
					accept_event()
					return
				var idx: int = _hit_group(mb.position)
				if idx >= 0:
					selected_group = idx
					group_selected.emit(idx)
					_drag_group = idx
					_drag_origin_x = mb.position.x
					_drag_origin_start = wave.spawn_entries[idx].start_time
					accept_event()
			else:
				if _drag_group >= 0:
					_drag_group = -1
					group_drag_ended.emit()
	elif event is InputEventMouseMotion and _drag_group >= 0:
		var mm := event as InputEventMouseMotion
		var dx: float = mm.position.x - _drag_origin_x
		var dt: float = dx / maxf(pixels_per_second, 1.0)
		var next: float = snappedf(maxf(_drag_origin_start + dt, 0.0), 0.1)
		if wave.spawn_entries[_drag_group].start_time != next:
			wave.spawn_entries[_drag_group].start_time = next
			group_start_changed.emit(_drag_group, next)
			_update_min_size()
			queue_redraw()
		accept_event()


func _hit_group(pos: Vector2) -> int:
	if wave == null:
		return -1
	for i: int in range(wave.spawn_entries.size()):
		var rect: Rect2 = _group_rect(i)
		if rect.has_point(pos):
			return i
	return -1


func _hit_event(pos: Vector2) -> int:
	if wave == null or wave.special_events == null:
		return -1
	for i: int in range(wave.special_events.size()):
		var rect: Rect2 = _event_hit_rect(i)
		if rect.has_point(pos):
			return i
	return -1


func _group_rect(index: int) -> Rect2:
	if wave == null or index < 0 or index >= wave.spawn_entries.size():
		return Rect2()
	var e: WaveSpawnEntry = wave.spawn_entries[index]
	if e == null:
		return Rect2()
	var interval: float = e.resolve_interval(wave.spawn_interval)
	var dur: float = maxf(float(maxi(e.count - 1, 0)) * interval, 0.6)
	var x: float = _PAD + maxf(e.start_time, 0.0) * pixels_per_second
	var y: float = _PAD + 22.0 + float(index) * (_ROW_H + 4.0)
	var w: float = maxf(dur * pixels_per_second, 48.0)
	return Rect2(x, y, w, _ROW_H)


func _event_x(index: int) -> float:
	if wave == null or index < 0 or index >= wave.special_events.size() or wave.special_events[index] == null:
		return _PAD
	return _PAD + maxf(wave.special_events[index].time, 0.0) * pixels_per_second


func _event_hit_rect(index: int) -> Rect2:
	var x: float = _event_x(index)
	return Rect2(x - 8.0, 2.0, 16.0, 18.0)


func _draw() -> void:
	_update_min_size()
	var w: float = maxf(size.x, custom_minimum_size.x)
	var h: float = maxf(size.y, custom_minimum_size.y)
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.05, 0.07, 0.1, 1.0), true)
	var max_t: float = maxf((w - _PAD * 2.0) / maxf(pixels_per_second, 1.0), 12.0)
	var font: Font = ThemeDB.fallback_font
	var t: float = 0.0
	while t <= max_t + 0.01:
		var x: float = _PAD + t * pixels_per_second
		draw_line(Vector2(x, 18.0), Vector2(x, h - 4.0), Color(1, 1, 1, 0.08), 1.0)
		if font != null:
			draw_string(font, Vector2(x + 2.0, 14.0), "%ds" % int(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.75, 0.85, 0.8))
		t += 5.0
	if wave == null:
		return
	for i: int in range(wave.spawn_entries.size()):
		var e: WaveSpawnEntry = wave.spawn_entries[i]
		if e == null:
			continue
		var rect: Rect2 = _group_rect(i)
		var col: Color = _COLORS[i % _COLORS.size()]
		if i == selected_group:
			col = Color(col.r, col.g, col.b, 0.95)
		else:
			col.a = 0.55
		draw_rect(rect, col, true)
		draw_rect(rect, Color(1, 1, 1, 0.35 if i == selected_group else 0.12), false, 1.5)
		var label: String = "G%d  %s  x%d  t=%.1f" % [
			i + 1,
			e.insect_data.display_name if e.insect_data != null else "?",
			e.count,
			e.start_time
		]
		if font != null:
			draw_string(font, rect.position + Vector2(6, 18), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8.0, 11, Color(0.05, 0.08, 0.1, 1.0))
	if wave.special_events == null:
		return
	for i: int in range(wave.special_events.size()):
		var ev: WaveSpecialEvent = wave.special_events[i]
		if ev == null:
			continue
		var cx: float = _event_x(i)
		var cy: float = 10.0
		var kind_i: int = int(ev.kind)
		var ecol: Color = _EVENT_COLORS[kind_i % _EVENT_COLORS.size()]
		if i == selected_event:
			ecol = Color(ecol.r, ecol.g, ecol.b, 1.0)
		else:
			ecol.a = 0.8
		var s: float = 7.0 if i == selected_event else 6.0
		var diamond := PackedVector2Array([
			Vector2(cx, cy - s),
			Vector2(cx + s, cy),
			Vector2(cx, cy + s),
			Vector2(cx - s, cy),
		])
		draw_colored_polygon(diamond, ecol)
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(1, 1, 1, 0.55), 1.0)
