## Builds pathogen visuals under Insect/Visual.
## Driven by InsectData.visual_id — never by display names.
class_name InsectPrototypeVisual
extends RefCounted

const VISUAL_BACTERIUM: StringName = &"bacterium"
const VISUAL_VIRUS: StringName = &"virus"
const BACTERIUM_SPRITE_PATH: String = "res://assets/gameplay/units/bacterium_idle.png"
const VIRUS_SPRITE_PATH: String = "res://assets/gameplay/units/virus_idle.png"
## Target on-grid size (matches nanobot body scale roughly).
const BACTERIUM_BODY_SIZE: float = 48.0
const VIRUS_BODY_SIZE: float = 52.0

static var _bacterium_texture: Texture2D = null
static var _virus_texture: Texture2D = null


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
	var tex: Texture2D = _get_bacterium_texture()
	if tex != null:
		_build_sprite(visual_root, "BacteriumSprite", tex, BACTERIUM_BODY_SIZE)
		return
	_build_bacterium_fallback(visual_root)


static func _get_bacterium_texture() -> Texture2D:
	if _bacterium_texture != null:
		return _bacterium_texture
	if not ResourceLoader.exists(BACTERIUM_SPRITE_PATH):
		return null
	_bacterium_texture = load(BACTERIUM_SPRITE_PATH) as Texture2D
	return _bacterium_texture


static func _get_virus_texture() -> Texture2D:
	if _virus_texture != null:
		return _virus_texture
	if not ResourceLoader.exists(VIRUS_SPRITE_PATH):
		return null
	_virus_texture = load(VIRUS_SPRITE_PATH) as Texture2D
	return _virus_texture


static func _build_sprite(
	visual_root: Node2D,
	sprite_name: String,
	texture: Texture2D,
	body_size: float
) -> void:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tex_size: Vector2 = texture.get_size()
	var max_dim: float = maxf(tex_size.x, tex_size.y)
	if max_dim > 0.0:
		var scale_factor: float = body_size / max_dim
		sprite.scale = Vector2(scale_factor, scale_factor)
	visual_root.add_child(sprite)


static func _build_bacterium_fallback(visual_root: Node2D) -> void:
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
	var tex: Texture2D = _get_virus_texture()
	if tex != null:
		_build_sprite(visual_root, "VirusSprite", tex, VIRUS_BODY_SIZE)
		return
	_build_virus_fallback(visual_root)


static func _build_virus_fallback(visual_root: Node2D) -> void:
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
