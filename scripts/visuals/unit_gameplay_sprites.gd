## Top-down gameplay unit sprites (separate from Research Lab portraits).
class_name UnitGameplaySprites
extends RefCounted

const SPRITE_DIR: String = "res://assets/gameplay/units/"

const PLANT_SPRITE_IDS: Dictionary = {
	&"clover": &"generator",
	&"thornbush": &"attacking",
	&"support_nanobot": &"support",
}

## Combat art faces up; Godot angle 0 points right — applied on BodyPivot when aiming.
const COMBAT_SPRITE_FACING_OFFSET: float = PI * 0.5

static var _cache: Dictionary = {}


static func get_plant_sprite(plant_id: StringName) -> Texture2D:
	var sprite_id: StringName = PLANT_SPRITE_IDS.get(plant_id, &"") as StringName
	if sprite_id == &"":
		return null
	return get_sprite(sprite_id)


static func get_organelle_sprite(organelle_id: StringName) -> Texture2D:
	return get_sprite(organelle_id)


static func get_plant_facing_offset(plant_id: StringName) -> float:
	if plant_id == &"thornbush":
		return COMBAT_SPRITE_FACING_OFFSET
	return 0.0


static func get_plant_platform_style(plant_id: StringName) -> Dictionary:
	match plant_id:
		&"thornbush":
			return {
				"fill": Color(0.10, 0.14, 0.22, 0.94),
				"inner": Color(0.14, 0.20, 0.32, 0.72),
				"border": Color(0.45, 0.72, 0.95, 0.88),
			}
		&"support_nanobot":
			return {
				"fill": Color(0.08, 0.16, 0.22, 0.94),
				"inner": Color(0.10, 0.24, 0.32, 0.68),
				"border": Color(0.35, 0.88, 0.95, 0.85),
			}
		_:
			return {
				"fill": Color(0.08, 0.15, 0.18, 0.94),
				"inner": Color(0.10, 0.22, 0.26, 0.68),
				"border": Color(0.30, 0.82, 0.78, 0.85),
			}


static func get_organelle_platform_style(organelle_id: StringName) -> Dictionary:
	match organelle_id:
		&"ribosome":
			return {
				"fill": Color(0.12, 0.10, 0.20, 0.94),
				"inner": Color(0.18, 0.14, 0.28, 0.68),
				"border": Color(0.62, 0.48, 0.95, 0.85),
			}
		_:
			return {
				"fill": Color(0.18, 0.12, 0.08, 0.94),
				"inner": Color(0.28, 0.16, 0.10, 0.68),
				"border": Color(0.95, 0.58, 0.28, 0.85),
			}


static func get_sprite(sprite_id: StringName) -> Texture2D:
	if sprite_id == &"":
		return null
	if _cache.has(sprite_id):
		return _cache[sprite_id] as Texture2D
	# Prefer transparent cutout sprites for in-game units.
	var nobg_path: String = SPRITE_DIR + "gameplay_%s_nobg.png" % String(sprite_id)
	if ResourceLoader.exists(nobg_path):
		var nobg_tex: Texture2D = load(nobg_path) as Texture2D
		if nobg_tex != null:
			_cache[sprite_id] = nobg_tex
			return nobg_tex
	var path: String = SPRITE_DIR + "gameplay_%s.png" % String(sprite_id)
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_cache[sprite_id] = tex
	return tex
