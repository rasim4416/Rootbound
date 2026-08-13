## Data definition for an insect type.
##
## Create one .tres per insect under data/insects/. Runtime insect nodes should
## receive an InsectData instance rather than hard-coding stats.
class_name InsectData
extends Resource

## High-level role used by systems to decide which behaviors apply later.
enum InsectRole {
	BASIC,
	TANK,
	FAST,
	FLYING,
	SPECIAL,
}

## Stable identifier for lookups, waves, and saves.
@export var insect_id: StringName = &""

@export var display_name: String = ""

@export_multiline var description: String = ""

@export var insect_role: InsectRole = InsectRole.BASIC

## Selects InsectPrototypeVisual silhouette (e.g. &"bacterium", &"virus").
@export var visual_id: StringName = &"bacterium"

@export_group("Combat")
@export var max_health: float = 1.0
@export var move_speed: float = 0.0
@export var attack_damage: float = 0.0
@export var attack_range: float = 0.0
@export var attack_cooldown: float = 0.0

@export_group("Rewards")
## Bio-Energy granted when this insect dies (economy — not XP).
@export var biomass_reward: int = 0
## XP granted to the Nanobot that scored the kill (instance progression).
@export var xp_reward: float = 0.0
## XP granted to each Support Nanobot actively buffing the killer (no Bio-Energy).
@export var assist_xp_reward: float = 10.0

@export_group("Element Drops")
## Permanent CHONS materials granted on death (not on Core leak / despawn).
@export var element_drops: Array[ElementDrop] = []
