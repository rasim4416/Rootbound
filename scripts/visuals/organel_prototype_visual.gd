## Builds organelle visuals under Organel/Visual — top-down gameplay sprites when available.
class_name OrganelPrototypeVisual
extends RefCounted


static func rebuild(visual_root: Node2D, organelle_id: StringName) -> void:
	if visual_root == null:
		return
	while visual_root.get_child_count() > 0:
		var child: Node = visual_root.get_child(0)
		visual_root.remove_child(child)
		child.free()

	var sprite: Texture2D = UnitGameplaySprites.get_organelle_sprite(organelle_id)
	if sprite != null:
		var style: Dictionary = UnitGameplaySprites.get_organelle_platform_style(organelle_id)
		UnitSpriteVisual.add_platform_unit(
			visual_root,
			sprite,
			UnitSpriteVisual.ORGANELLE_PLATFORM_SIZE,
			UnitSpriteVisual.ORGANELLE_BODY_SIZE,
			style
		)
		return

	match organelle_id:
		&"ribosome":
			_build_ribosome(visual_root)
		_:
			_build_mitochondrion(visual_root)


static func _build_mitochondrion(visual_root: Node2D) -> void:
	var hull := Polygon2D.new()
	hull.name = "Hull"
	hull.color = Color(0.95, 0.55, 0.25, 1.0)
	hull.polygon = PackedVector2Array([
		Vector2(-18, -8), Vector2(-6, -14), Vector2(10, -12), Vector2(18, -2),
		Vector2(14, 10), Vector2(-2, 14), Vector2(-16, 8), Vector2(-20, 0),
	])
	visual_root.add_child(hull)

	var inner := Polygon2D.new()
	inner.name = "Cristae"
	inner.color = Color(1.0, 0.75, 0.35, 0.9)
	inner.polygon = PackedVector2Array([
		Vector2(-10, -4), Vector2(8, -6), Vector2(10, 2), Vector2(-6, 6),
	])
	visual_root.add_child(inner)

	var core := Polygon2D.new()
	core.name = "Core"
	core.color = Color(1.0, 0.95, 0.55, 1.0)
	core.polygon = _circle(4.0, 8)
	visual_root.add_child(core)


static func _build_ribosome(visual_root: Node2D) -> void:
	var large := Polygon2D.new()
	large.name = "LargeSubunit"
	large.color = Color(0.55, 0.35, 0.85, 1.0)
	large.polygon = _circle(12.0, 12)
	large.position = Vector2(0, -2)
	visual_root.add_child(large)

	var small := Polygon2D.new()
	small.name = "SmallSubunit"
	small.color = Color(0.70, 0.50, 0.95, 1.0)
	small.polygon = _circle(7.0, 10)
	small.position = Vector2(0, 8)
	visual_root.add_child(small)

	var notch := Polygon2D.new()
	notch.name = "Groove"
	notch.color = Color(0.95, 0.85, 1.0, 0.85)
	notch.polygon = PackedVector2Array([
		Vector2(-3, -2), Vector2(3, -2), Vector2(2, 6), Vector2(-2, 6),
	])
	visual_root.add_child(notch)


static func _circle(radius: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(segments):
		var angle: float = float(i) / float(segments) * TAU
		out.append(Vector2(cos(angle), sin(angle)) * radius)
	return out
