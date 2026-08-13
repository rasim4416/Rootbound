## Full-screen research lab backdrop: photographic cell interior + drifting particles.
class_name ResearchLabBackdrop
extends Control

const BG_PATH: String = "res://assets/research/research_lab_background.png"
const PARTICLE_COUNT: int = 48

var _bg_texture: Texture2D
var _particles: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_texture = load(BG_PATH) as Texture2D
	_spawn_particles()
	set_process(true)


func _spawn_particles() -> void:
	_particles.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i: int in range(PARTICLE_COUNT):
		_particles.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"drift": Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.018, -0.006)),
			"size": rng.randf_range(1.2, 3.8),
			"alpha": rng.randf_range(0.12, 0.42),
			"phase": rng.randf() * TAU,
		})


func _process(delta: float) -> void:
	_time += delta
	for p: Dictionary in _particles:
		var pos: Vector2 = p["pos"]
		pos += p["drift"] * delta
		if pos.y < -0.04:
			pos.y = 1.04
			pos.x = randf()
		if pos.x < -0.04:
			pos.x = 1.04
		elif pos.x > 1.04:
			pos.x = -0.04
		p["pos"] = pos
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if _bg_texture != null:
		var tex_size: Vector2 = _bg_texture.get_size()
		var cover_scale: float = maxf(size.x / tex_size.x, size.y / tex_size.y)
		var draw_size: Vector2 = tex_size * cover_scale
		var offset: Vector2 = (size - draw_size) * 0.5
		draw_texture_rect(_bg_texture, Rect2(offset, draw_size), false)
	else:
		draw_rect(rect, Color(0.03, 0.05, 0.09, 1.0), true)

	# Readability tint over the photo.
	draw_rect(rect, Color(0.02, 0.06, 0.10, 0.42), true)
	_draw_vignette(rect)

	for p: Dictionary in _particles:
		var pos: Vector2 = p["pos"] * size
		var twinkle: float = 0.65 + 0.35 * sin(_time * 1.6 + float(p["phase"]))
		var alpha: float = float(p["alpha"]) * twinkle
		var glow: Color = Color(0.55, 0.95, 1.0, alpha * 0.35)
		var core: Color = Color(0.85, 1.0, 1.0, alpha)
		var r: float = float(p["size"])
		draw_circle(pos, r * 2.2, glow)
		draw_circle(pos, r, core)


func _draw_vignette(rect: Rect2) -> void:
	var steps: int = 6
	for i: int in range(steps):
		var t: float = float(i + 1) / float(steps)
		var inset: float = rect.size.length() * 0.08 * t
		var inner: Rect2 = rect.grow(-inset * 0.15)
		var alpha: float = 0.06 * t
		draw_rect(rect, Color(0.0, 0.02, 0.05, alpha), false, inset * 0.5)
