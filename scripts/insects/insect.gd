## Runtime insect / pathogen instance.
##
## InsectData holds static configuration. Insect holds per-instance runtime state.
## Difficulty: base × level_mult × wave_mult × permanent × run (via get_effective_stat).
## Grid movement is handled by GridPathFollower (PathFollower is legacy).
class_name Insect
extends Node2D

signal health_changed(current_health: float, max_health: float)
## Killer is the Plant/Nanobot that dealt the lethal hit, or null.
signal died(killer: Plant)

## Static definition for this insect type. Shared across instances; never mutate
## gameplay state on it.
@export var data: InsectData:
	set(value):
		data = value
		_sync_from_data()

var current_health: float = 0.0
var is_alive: bool = true
## Set when lethal damage is applied; cleared after died emits.
var last_attacker: Plant = null

## Combined LEVEL × WAVE multipliers (not permanent/run). Default 1.0.
var _level_wave_hp: float = 1.0
var _level_wave_speed: float = 1.0
var _level_wave_core_damage: float = 1.0

@onready var _visual: Node2D = $Visual


func _ready() -> void:
	_rebuild_prototype_visual()


## Applies insect_data and resets runtime state for a freshly spawned insect.
func initialize(insect_data: InsectData) -> void:
	data = insect_data
	is_alive = true
	last_attacker = null
	_level_wave_hp = 1.0
	_level_wave_speed = 1.0
	_level_wave_core_damage = 1.0
	_sync_from_data()


## Sets combined level×wave multipliers. Does not mutate InsectData.
func apply_level_wave_multipliers(hp: float, speed: float, core_damage: float) -> void:
	_level_wave_hp = maxf(hp, 0.01)
	_level_wave_speed = maxf(speed, 0.01)
	_level_wave_core_damage = maxf(core_damage, 0.01)
	_sync_from_data()


## Base × level×wave (for combat stats) × permanent × run. Does not mutate data.
func get_effective_stat(stat_id: StringName, base_value: float) -> float:
	var scaled_base: float = base_value
	if stat_id == StatIds.MAX_HEALTH:
		scaled_base = base_value * _level_wave_hp
	elif stat_id == StatIds.MOVE_SPEED:
		scaled_base = base_value * _level_wave_speed
	elif stat_id == StatIds.ATTACK_DAMAGE:
		scaled_base = base_value * _level_wave_core_damage

	if GameManager == null:
		return scaled_base
	return GameManager.get_effective_stat(stat_id, scaled_base)


func get_max_health() -> float:
	if data == null:
		return 0.0
	return maxf(get_effective_stat(StatIds.MAX_HEALTH, data.max_health), 1.0)


func get_move_speed() -> float:
	if data == null:
		return 0.0
	return maxf(get_effective_stat(StatIds.MOVE_SPEED, data.move_speed), 1.0)


func get_core_damage() -> float:
	if data == null:
		return 0.0
	return maxf(get_effective_stat(StatIds.ATTACK_DAMAGE, data.attack_damage), 0.0)


## Reduces health. Optional attacker is attributed only if this hit is lethal.
func take_damage(amount: float, attacker: Plant = null) -> void:
	if not is_alive or amount <= 0.0:
		return

	current_health = maxf(current_health - amount, 0.0)
	_emit_health_changed()

	if current_health <= 0.0:
		last_attacker = attacker
		die()


## Marks the insect dead and emits died once. Further damage is ignored.
## Stops path movement and defers removal so died listeners can run first.
func die() -> void:
	if not is_alive:
		return

	is_alive = false
	current_health = 0.0
	_emit_health_changed()
	_stop_path_followers()
	var killer: Plant = last_attacker
	died.emit(killer)
	# Deferred so RewardManager / WaveManager finish handling `died` first.
	call_deferred("queue_free")


## Removes the insect without combat death (no Biomass). Used when reaching Core.
func despawn() -> void:
	if not is_instance_valid(self):
		return
	_stop_path_followers()
	# Alive flag cleared so targeting ignores this node until free.
	is_alive = false
	# Do not emit died — RewardManager must not pay Biomass for leaks.
	call_deferred("queue_free")


## Halts GridPathFollower / legacy PathFollower children without path_completed.
func _stop_path_followers() -> void:
	for child: Node in get_children():
		var grid_follower := child as GridPathFollower
		if grid_follower != null:
			grid_follower.stop()
			continue
		var legacy := child as PathFollower
		if legacy != null:
			legacy.stop()


func _sync_from_data() -> void:
	if data == null:
		current_health = 0.0
		return

	current_health = get_max_health()
	_emit_health_changed()
	if is_node_ready():
		_rebuild_prototype_visual()


func _rebuild_prototype_visual() -> void:
	if _visual == null:
		return
	var visual_id: StringName = data.visual_id if data != null else InsectPrototypeVisual.VISUAL_BACTERIUM
	InsectPrototypeVisual.rebuild(_visual, visual_id)


func _emit_health_changed() -> void:
	var max_hp: float = get_max_health() if data != null else 0.0
	health_changed.emit(current_health, max_hp)
