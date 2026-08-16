## Cell-interior backdrop: translucent navy cytoplasm + drifting motes.
## Presentation only — no organelles, no gameplay / grid ownership.
class_name MapBackground
extends Node2D

const MAP_SIZE := Vector2(1152, 648)

## Deep space outside the membrane.
const COLOR_OUTSIDE := Color(0.03, 0.04, 0.10, 1.0)
## Base cytoplasm — dark navy, slightly transparent feel over outside.
const COLOR_CYTOPLASM := Color(0.06, 0.10, 0.22, 0.92)
const COLOR_CYTO_GLOW_A := Color(0.12, 0.22, 0.48, 0.22)
const COLOR_CYTO_GLOW_B := Color(0.08, 0.16, 0.38, 0.18)
const COLOR_CYTO_GLOW_C := Color(0.10, 0.28, 0.52, 0.14)
const COLOR_ENTRY := Color(0.55, 0.70, 1.0, 0.55)

@export var particle_count: int = 48
@export var particle_drift_speed: float = 12.0

var _particles: Array[Dictionary] = []
var _time: float = 0.0
var _bounds: Rect2 = Rect2(Vector2(40, 40), MAP_SIZE - Vector2(80, 80))


func _ready() -> void:
	_build()
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_update_particles(delta)


func _build() -> void:
	while get_child_count() > 0:
		var child: Node = get_child(0)
		remove_child(child)
		child.free()
	_particles.clear()

	_add_poly("Outside", _rect_poly(MAP_SIZE), COLOR_OUTSIDE, Vector2.ZERO)
	# Squared cytoplasm — no organic blob / rounded blue frame.
	_add_poly("Cytoplasm", _rect_poly(MAP_SIZE), COLOR_CYTOPLASM, Vector2.ZERO)

	# Soft translucent navy washes (cytoplasm depth, not organelles).
	_add_poly(
		"CytoGlowA",
		PackedVector2Array([
			Vector2(80, 60), Vector2(360, 40), Vector2(420, 200),
			Vector2(240, 280), Vector2(60, 180),
		]),
		COLOR_CYTO_GLOW_A,
		Vector2.ZERO
	)
	_add_poly(
		"CytoGlowB",
		PackedVector2Array([
			Vector2(680, 380), Vector2(980, 360), Vector2(1060, 520),
			Vector2(820, 580), Vector2(660, 480),
		]),
		COLOR_CYTO_GLOW_B,
		Vector2.ZERO
	)
	_add_poly(
		"CytoGlowC",
		PackedVector2Array([
			Vector2(420, 120), Vector2(720, 90), Vector2(780, 240),
			Vector2(560, 280), Vector2(400, 200),
		]),
		COLOR_CYTO_GLOW_C,
		Vector2.ZERO
	)
	_add_poly(
		"CytoGlowD",
		PackedVector2Array([
			Vector2(180, 420), Vector2(380, 400), Vector2(420, 560),
			Vector2(200, 580), Vector2(120, 500),
		]),
		Color(0.14, 0.24, 0.55, 0.12),
		Vector2.ZERO
	)

	# Subtle vignette discs (soft depth).
	_add_poly("DepthSoftA", _circle_poly(160.0, 18), Color(0.05, 0.12, 0.35, 0.10), Vector2(200, 180))
	_add_poly("DepthSoftB", _circle_poly(200.0, 18), Color(0.08, 0.18, 0.42, 0.08), Vector2(900, 420))
	_add_poly("DepthSoftC", _circle_poly(140.0, 16), Color(0.10, 0.26, 0.50, 0.09), Vector2(600, 300))

	_add_entry_pore(Vector2(32, 352))
	_spawn_particles()


func _spawn_particles() -> void:
	var root := Node2D.new()
	root.name = "CytoplasmParticles"
	add_child(root)

	for i: int in range(maxi(particle_count, 1)):
		var radius: float = randf_range(1.6, 5.5)
		var alpha: float = randf_range(0.12, 0.38)
		var tint := Color(
			randf_range(0.35, 0.65),
			randf_range(0.55, 0.85),
			randf_range(0.90, 1.0),
			alpha
		)
		var disc := Polygon2D.new()
		disc.name = "Mote_%d" % i
		disc.polygon = _circle_poly(radius, 8)
		disc.color = tint
		# Soft halo child
		var halo := Polygon2D.new()
		halo.name = "Halo"
		halo.polygon = _circle_poly(radius * 2.4, 8)
		halo.color = Color(tint.r, tint.g, tint.b, alpha * 0.35)
		disc.add_child(halo)

		var pos := Vector2(
			randf_range(_bounds.position.x, _bounds.end.x),
			randf_range(_bounds.position.y, _bounds.end.y)
		)
		disc.position = pos
		root.add_child(disc)

		_particles.append({
			"node": disc,
			"base_pos": pos,
			"vel": Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
				* randf_range(particle_drift_speed * 0.35, particle_drift_speed),
			"phase": randf() * TAU,
			"bob_amp": randf_range(4.0, 14.0),
			"bob_speed": randf_range(0.4, 1.1),
			"pulse_speed": randf_range(1.2, 2.8),
			"base_scale": randf_range(0.75, 1.25),
		})


func _update_particles(delta: float) -> void:
	for entry: Dictionary in _particles:
		var disc: Polygon2D = entry.get("node", null) as Polygon2D
		if disc == null or not is_instance_valid(disc):
			continue

		var vel: Vector2 = entry.get("vel", Vector2.ZERO) as Vector2
		var base: Vector2 = entry.get("base_pos", disc.position) as Vector2
		base += vel * delta

		# Wrap softly inside cytoplasm bounds.
		if base.x < _bounds.position.x:
			base.x = _bounds.end.x
		elif base.x > _bounds.end.x:
			base.x = _bounds.position.x
		if base.y < _bounds.position.y:
			base.y = _bounds.end.y
		elif base.y > _bounds.end.y:
			base.y = _bounds.position.y

		entry["base_pos"] = base

		var phase: float = float(entry.get("phase", 0.0))
		var bob_amp: float = float(entry.get("bob_amp", 8.0))
		var bob_speed: float = float(entry.get("bob_speed", 0.7))
		var pulse_speed: float = float(entry.get("pulse_speed", 1.8))
		var base_scale: float = float(entry.get("base_scale", 1.0))

		var bob := Vector2(
			sin(_time * bob_speed + phase) * bob_amp * 0.45,
			cos(_time * bob_speed * 0.85 + phase * 1.3) * bob_amp
		)
		disc.position = base + bob

		var pulse: float = 0.85 + 0.15 * sin(_time * pulse_speed + phase)
		disc.scale = Vector2.ONE * (base_scale * pulse)


func _add_entry_pore(at: Vector2) -> void:
	_add_poly(
		"EntryGlow",
		_circle_poly(24.0, 12),
		Color(0.40, 0.55, 1.0, 0.22),
		at
	)
	_add_poly(
		"EntryRing",
		_ringish_poly(18.0, 10.0, 10),
		COLOR_ENTRY,
		at
	)


func _add_poly(
	node_name: String,
	points: PackedVector2Array,
	color: Color,
	offset: Vector2
) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = node_name
	poly.polygon = points
	poly.color = color
	poly.position = offset
	add_child(poly)
	return poly


func _rect_poly(size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])


func _circle_poly(radius: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(segments):
		var angle: float = float(i) / float(segments) * TAU
		out.append(Vector2(cos(angle), sin(angle)) * radius)
	return out


func _ringish_poly(outer_r: float, inner_r: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(segments):
		var t: float = float(i) / float(segments - 1)
		var angle: float = lerpf(-1.2, 1.2, t)
		out.append(Vector2(cos(angle), sin(angle)) * outer_r)
	for i: int in range(segments - 1, -1, -1):
		var t: float = float(i) / float(segments - 1)
		var angle: float = lerpf(-1.2, 1.2, t)
		out.append(Vector2(cos(angle), sin(angle)) * inner_r)
	return out
