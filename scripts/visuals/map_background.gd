## Stylized biological cell interior (cytoplasm, membrane, organelles).
## Presentation only — no gameplay ownership or grid occupancy.
class_name MapBackground
extends Node2D

const MAP_SIZE := Vector2(1152, 648)

const COLOR_OUTSIDE := Color(0.06, 0.08, 0.14, 1.0)
const COLOR_CYTOPLASM := Color(0.12, 0.32, 0.38, 1.0)
const COLOR_CYTO_A := Color(0.16, 0.42, 0.48, 0.35)
const COLOR_CYTO_B := Color(0.10, 0.28, 0.36, 0.40)
const COLOR_BUBBLE := Color(0.45, 0.78, 0.82, 0.18)
const COLOR_MEMBRANE_OUTER := Color(0.35, 0.72, 0.78, 0.95)
const COLOR_MEMBRANE_INNER := Color(0.55, 0.88, 0.90, 0.55)
const COLOR_ENTRY := Color(0.95, 0.45, 0.55, 0.85)


func _ready() -> void:
	_build()


func _build() -> void:
	while get_child_count() > 0:
		var child: Node = get_child(0)
		remove_child(child)
		child.free()

	# Space outside the cell.
	_add_poly("Outside", _rect_poly(MAP_SIZE), COLOR_OUTSIDE, Vector2.ZERO)

	# Soft cytoplasm fill (slightly organic inset).
	_add_poly("Cytoplasm", _organic_cell_poly(), COLOR_CYTOPLASM, Vector2.ZERO)

	_add_poly(
		"CytoPatchA",
		PackedVector2Array([
			Vector2(120, 80), Vector2(340, 60), Vector2(400, 180),
			Vector2(260, 240), Vector2(100, 160),
		]),
		COLOR_CYTO_A,
		Vector2.ZERO
	)
	_add_poly(
		"CytoPatchB",
		PackedVector2Array([
			Vector2(720, 420), Vector2(980, 400), Vector2(1040, 540),
			Vector2(820, 580), Vector2(700, 500),
		]),
		COLOR_CYTO_B,
		Vector2.ZERO
	)
	_add_poly(
		"CytoPatchC",
		PackedVector2Array([
			Vector2(480, 80), Vector2(700, 100), Vector2(740, 220),
			Vector2(560, 200), Vector2(460, 140),
		]),
		COLOR_CYTO_A,
		Vector2.ZERO
	)

	# Static "vesicle" bubbles — few nodes only.
	_add_bubble(Vector2(180, 120), 18.0)
	_add_bubble(Vector2(420, 520), 14.0)
	_add_bubble(Vector2(900, 100), 20.0)
	_add_bubble(Vector2(640, 560), 12.0)
	_add_bubble(Vector2(250, 480), 10.0)

	_add_membrane()
	_add_entry_pore(Vector2(32, 352))
	_add_organelles()


func _organic_cell_poly() -> PackedVector2Array:
	# Rounded playable interior — reads as cell body, not a hard rectangle.
	return PackedVector2Array([
		Vector2(36, 48), Vector2(200, 20), Vector2(560, 16), Vector2(920, 24),
		Vector2(1116, 56), Vector2(1136, 180), Vector2(1140, 340), Vector2(1128, 500),
		Vector2(1100, 600), Vector2(880, 632), Vector2(560, 636), Vector2(240, 624),
		Vector2(48, 580), Vector2(16, 420), Vector2(12, 240), Vector2(24, 100),
	])


func _add_membrane() -> void:
	var rim: PackedVector2Array = _organic_cell_poly()
	# Close the loop for Line2D.
	var closed := PackedVector2Array(rim)
	closed.append(rim[0])

	var outer := Line2D.new()
	outer.name = "MembraneOuter"
	outer.points = closed
	outer.width = 14.0
	outer.default_color = COLOR_MEMBRANE_OUTER
	outer.antialiased = true
	outer.joint_mode = Line2D.LINE_JOINT_ROUND
	outer.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(outer)

	var inner := Line2D.new()
	inner.name = "MembraneInner"
	inner.points = closed
	inner.width = 5.0
	inner.default_color = COLOR_MEMBRANE_INNER
	inner.antialiased = true
	inner.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(inner)


func _add_entry_pore(at: Vector2) -> void:
	# Visual breach where pathogens enter — not a collider.
	_add_poly(
		"EntryGlow",
		_circle_poly(22.0, 10),
		Color(0.95, 0.40, 0.55, 0.35),
		at
	)
	_add_poly(
		"EntryRing",
		_ringish_poly(18.0, 10.0, 10),
		COLOR_ENTRY,
		at
	)


func _add_organelles() -> void:
	# Kept clear of the infection corridor; visual-only (no grid occupancy).
	_mitochondrion(Vector2(140, 90), 0.3)
	_mitochondrion(Vector2(980, 520), -0.5)
	_mitochondrion(Vector2(200, 540), 1.1)

	_golgi(Vector2(720, 90))
	_lysosome(Vector2(480, 560))

	_ribosome(Vector2(360, 70))
	_ribosome(Vector2(860, 560))
	_ribosome(Vector2(100, 400))
	_ribosome(Vector2(1040, 180))
	_ribosome(Vector2(600, 60))
	_ribosome(Vector2(300, 580))

	_er_hint(Vector2(900, 80))


func _mitochondrion(at: Vector2, rotation_rad: float) -> void:
	var body := _add_poly(
		"Mitochondrion",
		PackedVector2Array([
			Vector2(-28, -10), Vector2(-18, -16), Vector2(18, -16), Vector2(28, -8),
			Vector2(28, 8), Vector2(18, 16), Vector2(-18, 16), Vector2(-28, 8),
		]),
		Color(0.85, 0.45, 0.35, 0.85),
		at
	)
	body.rotation = rotation_rad
	var inner := _add_poly(
		"MitoCristae",
		PackedVector2Array([
			Vector2(-16, -4), Vector2(-4, 4), Vector2(4, -4), Vector2(16, 4),
		]),
		Color(0.95, 0.65, 0.40, 0.7),
		at
	)
	inner.rotation = rotation_rad


func _golgi(at: Vector2) -> void:
	for i: int in range(4):
		var y: float = float(i) * 8.0 - 12.0
		var w: float = 22.0 + float(i) * 4.0
		_add_poly(
			"GolgiCistern",
			PackedVector2Array([
				Vector2(-w, y - 3.0), Vector2(w, y - 3.0),
				Vector2(w + 4.0, y + 3.0), Vector2(-w - 4.0, y + 3.0),
			]),
			Color(0.75, 0.55, 0.85, 0.75 - float(i) * 0.08),
			at
		)


func _lysosome(at: Vector2) -> void:
	_add_poly("Lysosome", _circle_poly(16.0, 10), Color(0.55, 0.35, 0.75, 0.8), at)
	_add_poly("LysosomeCore", _circle_poly(7.0, 8), Color(0.75, 0.45, 0.90, 0.9), at)


func _ribosome(at: Vector2) -> void:
	_add_poly("Ribosome", _circle_poly(5.0, 6), Color(0.40, 0.70, 0.55, 0.75), at)


func _er_hint(at: Vector2) -> void:
	_add_poly(
		"ER",
		PackedVector2Array([
			Vector2(-40, -6), Vector2(-20, -14), Vector2(0, -6), Vector2(20, -14),
			Vector2(40, -4), Vector2(20, 4), Vector2(0, -2), Vector2(-20, 6), Vector2(-40, 2),
		]),
		Color(0.50, 0.70, 0.85, 0.35),
		at
	)


func _add_bubble(at: Vector2, radius: float) -> void:
	_add_poly("Bubble", _circle_poly(radius, 8), COLOR_BUBBLE, at)


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
	# Simple crescent-ish entry marker (not a true ring mesh).
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
