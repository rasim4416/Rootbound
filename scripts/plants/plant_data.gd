## Data definition for a plant type.
##
## Create one .tres per plant under data/plants/. Runtime plant scenes should
## receive a PlantData instance rather than hard-coding stats.
class_name PlantData
extends Resource

## High-level role used by systems to decide which behaviors apply.
enum PlantRole {
	DEFENDER,
	RESOURCE,
	SUPPORT,
	SPECIAL,
}

## Stable identifier for lookups, saves, and research unlocks.
@export var plant_id: StringName = &""

@export var display_name: String = ""

@export_multiline var description: String = ""

@export var plant_role: PlantRole = PlantRole.DEFENDER

@export_group("Economy")
## Biomass spent to acquire a seed of this plant.
@export var biomass_cost: int = 0

@export_group("Installation")
## Seconds from placement until the nanobot finishes installing and can act.
@export var install_time: float = 0.0

@export_group("Combat")
@export var max_health: float = 1.0
@export var damage: float = 0.0
@export var attack_range: float = 0.0
@export var attack_cooldown: float = 0.0
## World-space travel speed for this plant's projectiles (px/sec). 0 = use default.
@export var projectile_speed: float = 0.0

@export_group("Support")
## World-space radius for support auras (pixels). Used by SUPPORT role Nanobots.
@export var support_range: float = 0.0
## Additive attack-speed bonus granted to allies in range (0.15 = +15%).
@export var support_attack_speed_bonus: float = 0.0
## XP this Support Nanobot receives when an ally it is buffing scores a kill.
@export var assist_xp_reward: float = 0.0

@export_group("Bio-Energy Generation")
## Bio-Energy granted each production tick while a wave is active (Generator Nanobot).
@export var bio_energy_production_amount: int = 0
## Seconds between Bio-Energy grants while a wave is active.
@export var bio_energy_production_interval: float = 10.0

@export_group("Runtime")
## Optional scene override for placement. Empty = PlantManager default plant scene.
@export var runtime_scene: PackedScene


func is_support() -> bool:
	return plant_role == PlantRole.SUPPORT


func is_resource_generator() -> bool:
	return plant_role == PlantRole.RESOURCE
