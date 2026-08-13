## Lightweight decorative backdrop for menu screens (cell / sci-fi look).
class_name MenuBackdrop
extends Node2D

const SIZE := Vector2(1152, 648)


func _ready() -> void:
	_build()


func _build() -> void:
	while get_child_count() > 0:
		var child: Node = get_child(0)
		remove_child(child)
		child.free()

	_poly("Outside", _rect(SIZE), Color(0.05, 0.07, 0.12, 1.0), Vector2.ZERO)
	_poly(
		"Cytoplasm",
		PackedVector2Array([
			Vector2(80, 60), Vector2(520, 30), Vector2(980, 70), Vector2(1100, 220),
			Vector2(1080, 480), Vector2(860, 600), Vector2(400, 620), Vector2(80, 520),
			Vector2(40, 280),
		]),
		Color(0.10, 0.28, 0.34, 1.0),
		Vector2.ZERO
	)
	_poly("NucleusGlow", _circle(70.0, 16), Color(0.55, 0.30, 0.75, 0.35), Vector2(860, 200))
	_poly("Nucleus", _circle(42.0, 14), Color(0.65, 0.35, 0.85, 0.55), Vector2(860, 200))
	_poly("Mito", PackedVector2Array([
		Vector2(-30, -12), Vector2(30, -12), Vector2(34, 0), Vector2(30, 12), Vector2(-30, 12), Vector2(-34, 0),
	]), Color(0.85, 0.45, 0.35, 0.55), Vector2(220, 480))
	_poly("Golgi", PackedVector2Array([
		Vector2(-40, -8), Vector2(40, -8), Vector2(48, 0), Vector2(40, 8), Vector2(-40, 8), Vector2(-48, 0),
	]), Color(0.70, 0.50, 0.85, 0.45), Vector2(980, 500))
	_poly("RibosomeA", _circle(8.0, 6), Color(0.40, 0.75, 0.60, 0.5), Vector2(180, 160))
	_poly("RibosomeB", _circle(6.0, 6), Color(0.40, 0.75, 0.60, 0.5), Vector2(260, 200))
	_poly("RibosomeC", _circle(7.0, 6), Color(0.40, 0.75, 0.60, 0.5), Vector2(140, 240))


func _poly(node_name: String, points: PackedVector2Array, color: Color, at: Vector2) -> void:
	var p := Polygon2D.new()
	p.name = node_name
	p.polygon = points
	p.color = color
	p.position = at
	add_child(p)


func _rect(size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])


func _circle(radius: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(segments):
		var angle: float = float(i) / float(segments) * TAU
		out.append(Vector2(cos(angle), sin(angle)) * radius)
	return out
