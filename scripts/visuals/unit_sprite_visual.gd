## Platform base + cutout unit sprite. Platform stays axis-aligned; BodyPivot rotates for aim.
class_name UnitSpriteVisual
extends RefCounted

const NANOBOT_PLATFORM_SIZE: float = 58.0
const ORGANELLE_PLATFORM_SIZE: float = 56.0
const NANOBOT_BODY_SIZE: float = 42.0
const ORGANELLE_BODY_SIZE: float = 40.0

const BODY_PIVOT_NAME: StringName = &"BodyPivot"


static func add_platform_unit(
	visual_root: Node2D,
	texture: Texture2D,
	platform_size: float = NANOBOT_PLATFORM_SIZE,
	body_size: float = NANOBOT_BODY_SIZE,
	platform_style: Dictionary = {}
) -> Node2D:
	_add_platform(visual_root, platform_size, platform_style)

	var pivot := Node2D.new()
	pivot.name = BODY_PIVOT_NAME
	visual_root.add_child(pivot)

	var sprite := Sprite2D.new()
	sprite.name = "UnitSprite"
	sprite.texture = texture
	sprite.centered = true
	var tex_size: Vector2 = texture.get_size()
	var max_dim: float = maxf(tex_size.x, tex_size.y)
	if max_dim > 0.0:
		var scale_factor: float = body_size / max_dim
		sprite.scale = Vector2(scale_factor, scale_factor)
	pivot.add_child(sprite)
	return pivot


static func find_body_pivot(visual_root: Node2D) -> Node2D:
	if visual_root == null:
		return null
	return visual_root.get_node_or_null(String(BODY_PIVOT_NAME)) as Node2D


static func _add_platform(
	visual_root: Node2D,
	platform_size: float,
	platform_style: Dictionary
) -> void:
	var half: float = platform_size * 0.5
	var fill: Color = platform_style.get("fill", Color(0.08, 0.14, 0.20, 0.94))
	var inner: Color = platform_style.get("inner", Color(0.12, 0.20, 0.28, 0.68))
	var border: Color = platform_style.get("border", Color(0.35, 0.78, 0.88, 0.85))

	var shadow := Polygon2D.new()
	shadow.name = "PlatformShadow"
	shadow.color = Color(0.0, 0.0, 0.0, 0.32)
	shadow.polygon = _square_poly(half + 2.0)
	shadow.position = Vector2(1.0, 3.0)
	visual_root.add_child(shadow)

	var base := Polygon2D.new()
	base.name = "Platform"
	base.color = fill
	base.polygon = _square_poly(half)
	visual_root.add_child(base)

	var inset: float = 4.0
	var inner_pad := Polygon2D.new()
	inner_pad.name = "PlatformInner"
	inner_pad.color = inner
	inner_pad.polygon = _square_poly(half - inset)
	visual_root.add_child(inner_pad)

	var frame := Line2D.new()
	frame.name = "PlatformBorder"
	frame.points = _square_poly(half)
	frame.closed = true
	frame.width = 2.0
	frame.default_color = border
	visual_root.add_child(frame)


static func _square_poly(half: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	])
