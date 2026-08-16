## Editable continuous wave-scaling formulas (applied after level multipliers).
class_name WaveScalingConfig
extends Resource

@export_group("HP")
## wave_hp = 1.0 + hp_coeff * pow(wave - 1, hp_power)
@export var hp_coeff: float = 0.08
@export var hp_power: float = 0.85

@export_group("Speed")
## wave_speed = 1.0 + speed_coeff * (wave - 1)
@export var speed_coeff: float = 0.025

@export_group("Core Damage")
## wave_core_damage = 1.0 + core_damage_coeff * (wave - 1)
@export var core_damage_coeff: float = 0.05

@export_group("Enemy Count")
## round(count_base + count_linear * (w - 1) + count_quad * pow(w - 1, 2))
@export var count_base: float = 8.0
@export var count_linear: float = 2.0
@export var count_quad: float = 0.03

@export_group("Spawn Interval")
## 1.0 / (1.0 + interval_growth * pow(w - 1, interval_power)) — no minimum clamp
@export var interval_growth: float = 0.05
@export var interval_power: float = 0.9

@export_group("Timing")
@export var delay_before_wave: float = 0.0


func get_wave_hp_multiplier(wave: int) -> float:
	var w: int = maxi(wave, 1)
	return 1.0 + hp_coeff * pow(float(w - 1), hp_power)


func get_wave_speed_multiplier(wave: int) -> float:
	var w: int = maxi(wave, 1)
	return 1.0 + speed_coeff * float(w - 1)


func get_wave_core_damage_multiplier(wave: int) -> float:
	var w: int = maxi(wave, 1)
	return 1.0 + core_damage_coeff * float(w - 1)


func get_enemy_count(wave: int) -> int:
	var w: int = maxi(wave, 1)
	var t: float = float(w - 1)
	return maxi(int(round(count_base + count_linear * t + count_quad * t * t)), 1)


func get_spawn_interval(wave: int) -> float:
	var w: int = maxi(wave, 1)
	var t: float = float(w - 1)
	return 1.0 / (1.0 + interval_growth * pow(t, interval_power))
