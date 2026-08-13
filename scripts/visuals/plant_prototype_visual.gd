## Builds nanobot visuals under Plant/Visual — top-down gameplay sprites when available.
## clover → generator, thornbush → combat, support_nanobot → support.
class_name PlantPrototypeVisual
extends RefCounted


static func rebuild(visual_root: Node2D, plant_id: StringName) -> void:
	if visual_root == null:
		return

	while visual_root.get_child_count() > 0:
		var child: Node = visual_root.get_child(0)
		visual_root.remove_child(child)
		child.free()

	var sprite: Texture2D = UnitGameplaySprites.get_plant_sprite(plant_id)
	if sprite != null:
		_build_sprite_nanobot(visual_root, plant_id, sprite)
		return

	match plant_id:
		&"thornbush":
			_build_combat_nanobot(visual_root)
		&"support_nanobot":
			_build_support_nanobot(visual_root)
		_:
			_build_basic_nanobot(visual_root)


static func _build_sprite_nanobot(
	visual_root: Node2D,
	plant_id: StringName,
	sprite_tex: Texture2D
) -> void:
	if plant_id == &"support_nanobot":
		var ring := Polygon2D.new()
		ring.name = "AuraRing"
		ring.color = Color(0.25, 0.75, 0.95, 0.22)
		ring.polygon = _ring_poly(30.0, 24.0, 24)
		visual_root.add_child(ring)

	var style: Dictionary = UnitGameplaySprites.get_plant_platform_style(plant_id)
	UnitSpriteVisual.add_platform_unit(
		visual_root,
		sprite_tex,
		UnitSpriteVisual.NANOBOT_PLATFORM_SIZE,
		UnitSpriteVisual.NANOBOT_BODY_SIZE,
		style
	)


static func _build_basic_nanobot(visual_root: Node2D) -> void:
	var hull := Polygon2D.new()
	hull.name = "Hull"
	hull.color = Color(0.70, 0.82, 0.90, 1.0)
	hull.polygon = PackedVector2Array([
		Vector2(-12, -8), Vector2(12, -8), Vector2(14, 0), Vector2(12, 8),
		Vector2(-12, 8), Vector2(-14, 0),
	])
	visual_root.add_child(hull)

	var plate := Polygon2D.new()
	plate.name = "Plate"
	plate.color = Color(0.45, 0.55, 0.65, 1.0)
	plate.polygon = PackedVector2Array([
		Vector2(-8, -4), Vector2(8, -4), Vector2(8, 4), Vector2(-8, 4),
	])
	visual_root.add_child(plate)

	var core := Polygon2D.new()
	core.name = "Glow"
	core.color = Color(0.35, 0.95, 1.0, 1.0)
	core.polygon = _circle_poly(4.5, 8)
	visual_root.add_child(core)

	_add_leg(visual_root, Vector2(-10, 8), Vector2(-14, 14))
	_add_leg(visual_root, Vector2(10, 8), Vector2(14, 14))
	_add_leg(visual_root, Vector2(-10, -8), Vector2(-14, -14))
	_add_leg(visual_root, Vector2(10, -8), Vector2(14, -14))


static func _build_combat_nanobot(visual_root: Node2D) -> void:
	var hull := Polygon2D.new()
	hull.name = "Hull"
	hull.color = Color(0.55, 0.70, 0.85, 1.0)
	hull.polygon = PackedVector2Array([
		Vector2(-14, -10), Vector2(10, -12), Vector2(16, -2), Vector2(14, 10),
		Vector2(-10, 12), Vector2(-16, 2),
	])
	visual_root.add_child(hull)

	var armor := Polygon2D.new()
	armor.name = "Armor"
	armor.color = Color(0.30, 0.40, 0.52, 1.0)
	armor.polygon = PackedVector2Array([
		Vector2(-8, -6), Vector2(6, -8), Vector2(8, 6), Vector2(-6, 8),
	])
	visual_root.add_child(armor)

	var emitter := Polygon2D.new()
	emitter.name = "Emitter"
	emitter.color = Color(0.20, 0.90, 1.0, 1.0)
	emitter.polygon = PackedVector2Array([
		Vector2(8, -4), Vector2(22, 0), Vector2(8, 4),
	])
	visual_root.add_child(emitter)

	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.color = Color(0.55, 1.0, 1.0, 0.95)
	glow.polygon = _circle_poly(3.5, 7)
	visual_root.add_child(glow)

	_add_leg(visual_root, Vector2(-12, 10), Vector2(-18, 16))
	_add_leg(visual_root, Vector2(6, 10), Vector2(10, 16))
	_add_leg(visual_root, Vector2(-12, -10), Vector2(-18, -16))


static func _build_support_nanobot(visual_root: Node2D) -> void:
	var ring := Polygon2D.new()
	ring.name = "AuraRing"
	ring.color = Color(0.25, 0.75, 0.95, 0.35)
	ring.polygon = _ring_poly(16.0, 12.0, 20)
	visual_root.add_child(ring)

	var hull := Polygon2D.new()
	hull.name = "Hull"
	hull.color = Color(0.25, 0.70, 0.95, 1.0)
	hull.polygon = PackedVector2Array([
		Vector2(0, -14), Vector2(12, -6), Vector2(12, 6), Vector2(0, 14),
		Vector2(-12, 6), Vector2(-12, -6),
	])
	visual_root.add_child(hull)

	var plate := Polygon2D.new()
	plate.name = "Plate"
	plate.color = Color(0.15, 0.40, 0.62, 1.0)
	plate.polygon = PackedVector2Array([
		Vector2(-6, -5), Vector2(6, -5), Vector2(6, 5), Vector2(-6, 5),
	])
	visual_root.add_child(plate)

	var core := Polygon2D.new()
	core.name = "EnergyCore"
	core.color = Color(0.55, 1.0, 1.0, 1.0)
	core.polygon = _circle_poly(5.0, 10)
	visual_root.add_child(core)

	_add_leg(visual_root, Vector2(-10, 10), Vector2(-14, 16))
	_add_leg(visual_root, Vector2(10, 10), Vector2(14, 16))
	_add_leg(visual_root, Vector2(-10, -10), Vector2(-14, -16))
	_add_leg(visual_root, Vector2(10, -10), Vector2(14, -16))


static func _add_leg(visual_root: Node2D, base: Vector2, tip: Vector2) -> void:
	var side: Vector2 = (tip - base).orthogonal().normalized() * 1.6
	var leg := Polygon2D.new()
	leg.name = "Leg"
	leg.color = Color(0.55, 0.65, 0.75, 1.0)
	leg.polygon = PackedVector2Array([base + side, tip, base - side])
	visual_root.add_child(leg)


static func _circle_poly(radius: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(segments):
		var angle: float = float(i) / float(segments) * TAU
		out.append(Vector2(cos(angle), sin(angle)) * radius)
	return out


static func _ring_poly(outer_radius: float, inner_radius: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(segments):
		var angle: float = float(i) / float(segments) * TAU
		out.append(Vector2(cos(angle), sin(angle)) * outer_radius)
	for i: int in range(segments - 1, -1, -1):
		var angle_inner: float = float(i) / float(segments) * TAU
		out.append(Vector2(cos(angle_inner), sin(angle_inner)) * inner_radius)
	return out
