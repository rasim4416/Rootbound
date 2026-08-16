## Procedural Nucleus presentation — biological core, not a generic orb.
## Presentation only. Parent Core owns HP / damage / game-over logic.
class_name NucleusVisual
extends Node2D

@export var radius: float = 58.0
@export var pulse_speed: float = 1.35
@export var pulse_amount: float = 0.035
@export var membrane_wobble: float = 0.045
@export var chromatin_spin_speed: float = 0.18
@export var mote_count: int = 10
@export var show_local_hp: bool = true

var _time: float = 0.0
var _hit_flash: float = 0.0
var _core: Core
var _hp_ratio: float = 1.0

var _membrane_outer: Polygon2D
var _membrane_mid: Polygon2D
var _membrane_inner: Polygon2D
var _nucleoplasm_deep: Polygon2D
var _nucleoplasm: Polygon2D
var _nucleolus_halo: Polygon2D
var _nucleolus: Polygon2D
var _nucleolus_core: Polygon2D
var _chromatin: Node2D
var _inlet: Node2D
var _motes_root: Node2D
var _motes: Array[Polygon2D] = []
var _mote_angles: Array[float] = []
var _mote_radii: Array[float] = []
var _base_outer: PackedVector2Array
var _base_mid: PackedVector2Array
var _base_inner: PackedVector2Array


func _ready() -> void:
	_core = get_parent() as Core
	_rebuild()
	_bind_core()
	set_process(true)
	queue_redraw()


func _bind_core() -> void:
	if _core == null:
		return
	if not _core.health_changed.is_connected(_on_health_changed):
		_core.health_changed.connect(_on_health_changed)
	if not _core.damaged.is_connected(_on_damaged):
		_core.damaged.connect(_on_damaged)
	var max_hp: float = _core.data.max_health if _core.data != null else 1.0
	_on_health_changed(_core.current_health, max_hp)


func _on_health_changed(current: float, maximum: float) -> void:
	_hp_ratio = clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	queue_redraw()


func _on_damaged(_amount: float) -> void:
	_hit_flash = 1.0


func _process(delta: float) -> void:
	_time += delta
	if _hit_flash > 0.0:
		_hit_flash = maxf(_hit_flash - delta * 2.8, 0.0)

	var pulse: float = 1.0 + sin(_time * pulse_speed) * pulse_amount
	var hit_scale: float = 1.0 + _hit_flash * 0.06
	scale = Vector2.ONE * pulse * hit_scale

	_animate_membrane()
	_animate_nucleolus()
	_animate_chromatin(delta)
	_animate_motes(delta)
	_animate_inlet()
	queue_redraw()


func _rebuild() -> void:
	while get_child_count() > 0:
		var child: Node = get_child(0)
		remove_child(child)
		child.free()
	_motes.clear()
	_mote_angles.clear()
	_mote_radii.clear()

	# Path inlet sits behind the body so energy reads as flowing INTO the nucleus.
	_inlet = Node2D.new()
	_inlet.name = "PathInlet"
	_inlet.z_index = -2
	add_child(_inlet)
	_build_path_inlet()

	var halo := Polygon2D.new()
	halo.name = "OuterHalo"
	halo.z_index = -1
	halo.color = Color(0.55, 0.18, 0.55, 0.22)
	halo.polygon = _organic_circle(radius * 1.55, 28, 0.04, 1)
	add_child(halo)

	_base_outer = _organic_circle(radius, 26, 0.07, 11)
	_membrane_outer = _add_poly("MembraneOuter", _base_outer, Color(0.72, 0.28, 0.62, 0.38), 0)

	_base_mid = _organic_circle(radius * 0.88, 24, 0.06, 22)
	_membrane_mid = _add_poly("MembraneMid", _base_mid, Color(0.55, 0.20, 0.58, 0.55), 1)

	_base_inner = _organic_circle(radius * 0.74, 22, 0.05, 33)
	_membrane_inner = _add_poly("MembraneInner", _base_inner, Color(0.42, 0.16, 0.52, 0.72), 2)

	_nucleoplasm_deep = _add_poly(
		"NucleoplasmDeep",
		_organic_circle(radius * 0.62, 20, 0.04, 44),
		Color(0.28, 0.10, 0.40, 0.92),
		3
	)
	_nucleoplasm = _add_poly(
		"Nucleoplasm",
		_organic_circle(radius * 0.48, 18, 0.035, 55),
		Color(0.48, 0.22, 0.62, 0.88),
		4
	)

	_chromatin = Node2D.new()
	_chromatin.name = "Chromatin"
	_chromatin.z_index = 5
	add_child(_chromatin)
	_build_chromatin()

	_nucleolus_halo = _add_poly(
		"NucleolusHalo",
		_circle(radius * 0.28, 16),
		Color(1.0, 0.55, 0.85, 0.35),
		6
	)
	_nucleolus = _add_poly(
		"Nucleolus",
		_organic_circle(radius * 0.18, 14, 0.08, 66),
		Color(0.95, 0.45, 0.78, 0.95),
		7
	)
	_nucleolus_core = _add_poly(
		"NucleolusCore",
		_circle(radius * 0.08, 12),
		Color(1.0, 0.88, 0.96, 0.98),
		8
	)

	_motes_root = Node2D.new()
	_motes_root.name = "OrbitMotes"
	_motes_root.z_index = 9
	add_child(_motes_root)
	_build_motes()
	# World position stays on path end cell (Main sets global_position).
	# Content is built in local space around origin.


func _add_poly(poly_name: String, points: PackedVector2Array, color: Color, z: int) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = poly_name
	poly.polygon = points
	poly.color = color
	poly.z_index = z
	add_child(poly)
	return poly


func _build_path_inlet() -> void:
	# Funnel from the west (path arrives from left along y = cell center).
	var stem := Polygon2D.new()
	stem.name = "InletStem"
	stem.color = Color(0.78, 0.30, 0.52, 0.72)
	stem.polygon = PackedVector2Array([
		Vector2(-radius * 1.85, -radius * 0.28),
		Vector2(-radius * 0.55, -radius * 0.34),
		Vector2(-radius * 0.55, radius * 0.34),
		Vector2(-radius * 1.85, radius * 0.28),
	])
	_inlet.add_child(stem)

	var stem_core := Polygon2D.new()
	stem_core.name = "InletCore"
	stem_core.color = Color(1.0, 0.72, 0.88, 0.55)
	stem_core.polygon = PackedVector2Array([
		Vector2(-radius * 1.85, -radius * 0.10),
		Vector2(-radius * 0.50, -radius * 0.12),
		Vector2(-radius * 0.50, radius * 0.12),
		Vector2(-radius * 1.85, radius * 0.10),
	])
	_inlet.add_child(stem_core)

	var mouth := Polygon2D.new()
	mouth.name = "InletMouth"
	mouth.color = Color(0.90, 0.40, 0.65, 0.55)
	mouth.polygon = PackedVector2Array([
		Vector2(-radius * 0.70, -radius * 0.42),
		Vector2(-radius * 0.15, -radius * 0.22),
		Vector2(-radius * 0.15, radius * 0.22),
		Vector2(-radius * 0.70, radius * 0.42),
	])
	_inlet.add_child(mouth)

	for i: int in range(4):
		var mote := Polygon2D.new()
		mote.name = "InletFlow_%d" % i
		mote.color = Color(1.0, 0.85, 0.95, 0.75)
		mote.polygon = _circle(2.2, 6)
		mote.set_meta("phase", float(i) / 4.0)
		_inlet.add_child(mote)


func _build_chromatin() -> void:
	var specs: Array[Dictionary] = [
		{"r": radius * 0.36, "thick": 3.2, "color": Color(0.85, 0.55, 1.0, 0.55), "seed": 1},
		{"r": radius * 0.30, "thick": 2.6, "color": Color(0.70, 0.75, 1.0, 0.50), "seed": 2},
		{"r": radius * 0.24, "thick": 2.2, "color": Color(1.0, 0.60, 0.85, 0.48), "seed": 3},
	]
	for i: int in range(specs.size()):
		var spec: Dictionary = specs[i]
		var line := Line2D.new()
		line.name = "Chromatin_%d" % i
		line.width = float(spec["thick"])
		line.default_color = spec["color"] as Color
		line.antialiased = true
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.points = _chromatin_loop(float(spec["r"]), int(spec["seed"]))
		_chromatin.add_child(line)


func _chromatin_loop(loop_radius: float, seed: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments: int = 28
	for i: int in range(segments + 1):
		var t: float = float(i) / float(segments) * TAU
		var wobble: float = 1.0 + 0.12 * sin(t * 3.0 + float(seed)) + 0.06 * sin(t * 5.0 - float(seed))
		var rr: float = loop_radius * wobble
		# Slight oval / offset so loops feel like chromatin, not perfect rings.
		var ox: float = cos(t + float(seed) * 0.7) * rr
		var oy: float = sin(t * 1.08 + float(seed) * 0.4) * rr * 0.82
		points.append(Vector2(ox, oy))
	return points


func _build_motes() -> void:
	for i: int in range(maxi(mote_count, 1)):
		var mote := Polygon2D.new()
		mote.name = "Mote_%d" % i
		var size: float = 1.6 + float(i % 3) * 0.7
		mote.polygon = _circle(size, 6)
		mote.color = Color(1.0, 0.75, 0.92, 0.55 - float(i % 3) * 0.08)
		_motes_root.add_child(mote)
		_motes.append(mote)
		_mote_angles.append(TAU * float(i) / float(mote_count) + float(i) * 0.37)
		_mote_radii.append(radius * (0.52 + float(i % 4) * 0.08))


func _animate_membrane() -> void:
	var wobble: float = 1.0 + sin(_time * 0.9) * membrane_wobble
	if _membrane_outer != null:
		_membrane_outer.polygon = _scale_poly(_base_outer, wobble)
		_membrane_outer.color = Color(0.72, 0.28, 0.62, 0.34 + 0.06 * sin(_time * 1.1))
	if _membrane_mid != null:
		_membrane_mid.polygon = _scale_poly(_base_mid, 1.0 + sin(_time * 1.05 + 0.8) * membrane_wobble * 0.7)
	if _membrane_inner != null:
		_membrane_inner.polygon = _scale_poly(_base_inner, 1.0 + sin(_time * 1.2 + 1.4) * membrane_wobble * 0.5)

	var flash: Color = Color(1.0, 0.35, 0.45, 1.0)
	if _hit_flash > 0.0 and _membrane_outer != null:
		_membrane_outer.color = _membrane_outer.color.lerp(flash, _hit_flash * 0.65)


func _animate_nucleolus() -> void:
	if _nucleolus == null:
		return
	var glow: float = 0.85 + 0.15 * sin(_time * 2.1)
	var dim: float = lerpf(0.55, 1.0, _hp_ratio)
	_nucleolus.scale = Vector2.ONE * (glow * dim)
	_nucleolus.color = Color(0.95, 0.45, 0.78, 0.85 + 0.1 * sin(_time * 2.1)).lerp(
		Color(1.0, 0.4, 0.5, 1.0),
		_hit_flash * 0.7
	)
	if _nucleolus_halo != null:
		_nucleolus_halo.scale = Vector2.ONE * (1.05 + 0.12 * sin(_time * 1.6))
		_nucleolus_halo.modulate.a = (0.7 + 0.3 * sin(_time * 1.6)) * dim
	if _nucleolus_core != null:
		_nucleolus_core.scale = Vector2.ONE * (0.9 + 0.15 * sin(_time * 2.4))
		_nucleolus_core.modulate.a = dim


func _animate_chromatin(delta: float) -> void:
	if _chromatin == null:
		return
	_chromatin.rotation += chromatin_spin_speed * delta
	_chromatin.modulate.a = 0.75 + 0.15 * sin(_time * 0.8)


func _animate_motes(delta: float) -> void:
	for i: int in range(_motes.size()):
		_mote_angles[i] += delta * (0.35 + float(i % 3) * 0.08) * (1.0 if i % 2 == 0 else -1.0)
		var a: float = _mote_angles[i]
		var rr: float = _mote_radii[i] + sin(_time * 1.4 + float(i)) * 3.0
		_motes[i].position = Vector2(cos(a), sin(a) * 0.88) * rr
		_motes[i].modulate.a = 0.35 + 0.35 * (0.5 + 0.5 * sin(_time * 2.0 + float(i)))


func _animate_inlet() -> void:
	if _inlet == null:
		return
	for child: Node in _inlet.get_children():
		if not String(child.name).begins_with("InletFlow_"):
			continue
		var mote: Polygon2D = child as Polygon2D
		if mote == null:
			continue
		var phase: float = float(mote.get_meta("phase", 0.0))
		var t: float = fposmod(_time * 0.55 + phase, 1.0)
		mote.position = Vector2(lerpf(-radius * 1.75, -radius * 0.35, t), sin((_time + phase) * 3.0) * 4.0)
		mote.modulate.a = 0.25 + 0.55 * (1.0 - absf(t - 0.5) * 2.0)


func _draw() -> void:
	if not show_local_hp:
		return
	# Compact HP strip just above the membrane — reads as belonging to Nucleus.
	var bar_w: float = radius * 1.55
	var bar_h: float = 6.0
	var top: float = -radius * 1.28
	var left: float = -bar_w * 0.5
	draw_rect(Rect2(left - 1.0, top - 1.0, bar_w + 2.0, bar_h + 2.0), Color(0.08, 0.05, 0.12, 0.75), true)
	draw_rect(Rect2(left, top, bar_w, bar_h), Color(0.25, 0.10, 0.22, 0.90), true)
	var fill_w: float = bar_w * _hp_ratio
	if fill_w > 0.5:
		var hp_col := Color(0.95, 0.45, 0.75, 0.95)
		if _hp_ratio < 0.35:
			hp_col = Color(1.0, 0.35, 0.45, 0.95)
		elif _hp_ratio < 0.65:
			hp_col = Color(1.0, 0.60, 0.45, 0.95)
		draw_rect(Rect2(left, top, fill_w, bar_h), hp_col, true)
	# Tiny label cue
	# (no DynamicFont dependency — top HUD keeps full text)


func _organic_circle(r: float, segments: int, irregularity: float, seed: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(segments):
		var t: float = float(i) / float(segments) * TAU
		var n1: float = sin(t * 2.0 + float(seed)) * 0.55
		var n2: float = cos(t * 3.0 - float(seed) * 0.7) * 0.35
		var n3: float = sin(t * 5.0 + float(seed) * 1.3) * 0.15
		var rr: float = r * (1.0 + irregularity * (n1 + n2 + n3))
		out.append(Vector2(cos(t), sin(t)) * rr)
	return out


func _circle(r: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(segments):
		var t: float = float(i) / float(segments) * TAU
		out.append(Vector2(cos(t), sin(t)) * r)
	return out


func _scale_poly(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p * factor)
	return out
