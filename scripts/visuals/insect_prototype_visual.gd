## Builds stylized pathogen silhouettes under Insect/Visual.
## Driven by InsectData.visual_id — never by display names.
class_name InsectPrototypeVisual
extends RefCounted

const VISUAL_BACTERIUM: StringName = &"bacterium"
const VISUAL_VIRUS: StringName = &"virus"


static func rebuild(visual_root: Node2D, visual_id: StringName) -> void:
	if visual_root == null:
		return

	while visual_root.get_child_count() > 0:
		var child: Node = visual_root.get_child(0)
		visual_root.remove_child(child)
		child.free()

	match visual_id:
		VISUAL_VIRUS:
			_build_virus(visual_root)
		_:
			_build_bacterium(visual_root)


static func _build_bacterium(visual_root: Node2D) -> void:
	var body := Polygon2D.new()
	body.name = "Body"
	body.color = Color(0.85, 0.25, 0.35, 1.0)
	body.polygon = PackedVector2Array([
		Vector2(-14, -8), Vector2(-4, -12), Vector2(10, -10), Vector2(16, -2),
		Vector2(14, 8), Vector2(2, 12), Vector2(-10, 10), Vector2(-16, 2),
	])
	visual_root.add_child(body)

	var membrane := Polygon2D.new()
	membrane.name = "Membrane"
	membrane.color = Color(0.95, 0.40, 0.45, 0.55)
	membrane.polygon = PackedVector2Array([
		Vector2(-12, -6), Vector2(-2, -10), Vector2(8, -8), Vector2(12, 0),
		Vector2(8, 8), Vector2(-4, 8), Vector2(-12, 2),
	])
	visual_root.add_child(membrane)

	var nucleus := Polygon2D.new()
	nucleus.name = "Nucleus"
	nucleus.color = Color(0.55, 0.10, 0.20, 1.0)
	nucleus.polygon = _circle_poly(4.5, 7)
	visual_root.add_child(nucleus)

	var flagellum := Polygon2D.new()
	flagellum.name = "Flagellum"
	flagellum.color = Color(0.70, 0.20, 0.30, 0.9)
	flagellum.polygon = PackedVector2Array([
		Vector2(-14, 0), Vector2(-24, -4), Vector2(-28, 0), Vector2(-24, 4),
	])
	visual_root.add_child(flagellum)


static func _build_virus(visual_root: Node2D) -> void:
	var core := Polygon2D.new()
	core.name = "Core"
	core.color = Color(0.75, 0.20, 0.85, 1.0)
	core.polygon = PackedVector2Array([
		Vector2(-8, -6), Vector2(0, -10), Vector2(8, -6), Vector2(10, 0),
		Vector2(8, 6), Vector2(0, 10), Vector2(-8, 6), Vector2(-10, 0),
	])
	visual_root.add_child(core)

	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.color = Color(0.95, 0.45, 1.0, 0.85)
	glow.polygon = _circle_poly(4.0, 6)
	visual_root.add_child(glow)

	var spike_color := Color(0.95, 0.35, 0.70, 1.0)
	_add_spike(visual_root, Vector2(0, -8), Vector2(0, -16), spike_color)
	_add_spike(visual_root, Vector2(8, -4), Vector2(15, -9), spike_color)
	_add_spike(visual_root, Vector2(8, 4), Vector2(15, 9), spike_color)
	_add_spike(visual_root, Vector2(0, 8), Vector2(0, 16), spike_color)
	_add_spike(visual_root, Vector2(-8, 4), Vector2(-15, 9), spike_color)
	_add_spike(visual_root, Vector2(-8, -4), Vector2(-15, -9), spike_color)


static func _add_spike(
	visual_root: Node2D,
	base: Vector2,
	tip: Vector2,
	color: Color
) -> void:
	var side: Vector2 = (tip - base).orthogonal().normalized() * 1.8
	var spike := Polygon2D.new()
	spike.name = "Spike"
	spike.color = color
	spike.polygon = PackedVector2Array([base + side, tip, base - side])
	visual_root.add_child(spike)


static func _circle_poly(radius: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(segments):
		var angle: float = float(i) / float(segments) * TAU
		out.append(Vector2(cos(angle), sin(angle)) * radius)
	return out
