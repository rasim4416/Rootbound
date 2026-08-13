## Canonical StringName IDs for progression stats.
##
## Use these constants instead of string literals when adding modifiers or
## requesting effective values.
class_name StatIds
extends Object

const DAMAGE: StringName = &"damage"
const MAX_HEALTH: StringName = &"max_health"
const ATTACK_RANGE: StringName = &"attack_range"
const ATTACK_COOLDOWN: StringName = &"attack_cooldown"
## Multiplier on fire rate. Effective cooldown = base_cooldown / ATTACK_SPEED.
const ATTACK_SPEED: StringName = &"attack_speed"
## Radians/sec turning rate for Nanobot aiming.
const ROTATION_SPEED: StringName = &"rotation_speed"
const INSTALL_TIME: StringName = &"install_time"
const BIOMASS_REWARD: StringName = &"biomass_reward"
const BIOMASS_GENERATION: StringName = &"biomass_generation"
const MOVE_SPEED: StringName = &"move_speed"
## Core / Nucleus damage dealt when a pathogen leaks.
const ATTACK_DAMAGE: StringName = &"attack_damage"
const XP_REWARD: StringName = &"xp_reward"
## World-space support aura radius (Support Nanobots).
const SUPPORT_RANGE: StringName = &"support_range"
## Additive attack-speed bonus this Support grants to allies.
const SUPPORT_ATTACK_SPEED_BONUS: StringName = &"support_attack_speed_bonus"
## Assist XP granted to a Support Nanobot when a buffed ally scores a kill.
const ASSIST_XP_REWARD: StringName = &"assist_xp_reward"
## Flat HP restored per second on Nanobots (permanent research, etc.).
const HEALTH_REGEN: StringName = &"health_regen"
## Global ATP generated per second from permanent research.
const ATP_GENERATION: StringName = &"atp_generation"
## Flat Bio-Energy granted per Generator production tick.
const BIO_ENERGY_PRODUCTION_AMOUNT: StringName = &"bio_energy_production_amount"
## Seconds between Generator Bio-Energy ticks (additive; negative = faster).
const BIO_ENERGY_PRODUCTION_INTERVAL: StringName = &"bio_energy_production_interval"
## Flat shop Bio-Energy discount for Generator Nanobot purchases.
const GENERATOR_SHOP_COST: StringName = &"generator_shop_cost"
