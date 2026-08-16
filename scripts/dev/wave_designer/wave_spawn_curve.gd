## Editor-only spawn-density sparkline (1s buckets). Does not affect gameplay.
class_name WaveSpawnCurve
extends Control

const _COL_BG := Color(0.05, 0.07, 0.1, 1.0)
const _COL_LINE := Color(0.45, 0.85, 1.0, 0.95)
const _COL_FILL := Color(0.25, 0.55, 0.75, 0.28)
const _COL_GRID := Color(1, 1, 1, 0.08)

var _counts: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 72)
	clip_contents = true


func set_wave(wave: WaveData) -> void:
	_counts = WaveDesignerStats.spawn_density_buckets(wave, 1.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _COL_BG, true)
	var font: Font = ThemeDB.fallback_font
	if _counts.is_empty():
		if font != null:
			draw_string(font, Vector2(8, size.y * 0.55), "No spawns", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.65, 0.75, 0.7))
		return
	var max_c: int = 1
	for c: int in _counts:
		if c > max_c:
			max_c = c
	var n: int = _counts.size()
	var pad: float = 6.0
	var w: float = maxf(size.x - pad * 2.0, 8.0)
	var h: float = maxf(size.y - 22.0, 8.0)
	var origin := Vector2(pad, size.y - 14.0)
	for g: int in range(5):
		var gy: float = origin.y - h * float(g) / 4.0
		draw_line(Vector2(pad, gy), Vector2(pad + w, gy), _COL_GRID, 1.0)
	var pts := PackedVector2Array()
	pts.append(origin)
	for i: int in range(n):
		var x: float = pad + w * float(i) / float(maxi(n - 1, 1))
		if n == 1:
			x = pad + w * 0.5
		var y: float = origin.y - h * float(_counts[i]) / float(max_c)
		pts.append(Vector2(x, y))
	pts.append(Vector2(pad + w, origin.y))
	if pts.size() >= 3:
		draw_colored_polygon(pts, _COL_FILL)
	for i: int in range(n):
		var x0: float = pad + w * float(i) / float(maxi(n - 1, 1))
		if n == 1:
			x0 = pad + w * 0.5
		var y0: float = origin.y - h * float(_counts[i]) / float(max_c)
		if i + 1 < n:
			var x1: float = pad + w * float(i + 1) / float(maxi(n - 1, 1))
			var y1: float = origin.y - h * float(_counts[i + 1]) / float(max_c)
			draw_line(Vector2(x0, y0), Vector2(x1, y1), _COL_LINE, 2.0)
		draw_circle(Vector2(x0, y0), 2.2, _COL_LINE)
	if font != null:
		draw_string(
			font,
			Vector2(pad, 12.0),
			"Spawn / s  (max %d)" % max_c,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color(0.65, 0.75, 0.85, 0.85)
		)
