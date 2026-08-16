## Plant-mounted combat helper.
##
## Finds a target via TargetingSystem, aims smoothly, then fires a projectile
## attributed to the parent Nanobot for kill XP.
class_name AttackComponent
extends Node

signal attack_performed(target: Insect, damage: float)

@export var targeting: TargetingSystem
@export var projectile_manager: ProjectileManager
@export var debug_log_attacks: bool = false

var _plant: Plant
var _cooldown_remaining: float = 0.0


func _ready() -> void:
	_plant = get_parent() as Plant
	if _plant == null:
		push_error("AttackComponent: parent must be a Plant.")
		set_process(false)
		return
	set_process(true)


func _process(delta: float) -> void:
	if _plant == null or not is_instance_valid(_plant):
		return
	if GameManager != null and GameManager.is_gameplay_frozen():
		return
	if not _plant.is_alive or not _plant.is_ready():
		return
	if _plant.data == null:
		return

	var damage: float = _plant.get_effective_stat(StatIds.DAMAGE, _plant.data.damage)
	var attack_range: float = _plant.get_effective_stat(StatIds.ATTACK_RANGE, _plant.data.attack_range)
	if damage <= 0.0 or attack_range <= 0.0:
		_plant.clear_aim()
		return

	var targeting_system: TargetingSystem = _get_targeting()
	if targeting_system == null:
		return

	var target: Insect = targeting_system.select_target(
		_plant.global_position,
		attack_range,
		_plant.get_target_mode()
	)
	if target == null or not target.is_alive:
		_plant.clear_aim()
		_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
		return

	_plant.aim_at(target.global_position)

	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _cooldown_remaining > 0.0:
		return

	_attack(target, damage)


func _attack(target: Insect, damage: float) -> void:
	var manager: ProjectileManager = _get_projectile_manager()
	if manager == null:
		push_warning("AttackComponent: ProjectileManager unavailable; attack skipped.")
		return

	_plant.aim_at(target.global_position)

	var projectile_speed: float = _plant.data.projectile_speed
	if projectile_speed <= 0.0:
		projectile_speed = 400.0

	var projectile: Projectile = manager.spawn_projectile(
		_plant.global_position,
		target,
		damage,
		projectile_speed,
		_plant
	)
	if projectile == null:
		return

	_cooldown_remaining = _plant.get_effective_attack_cooldown()
	attack_performed.emit(target, damage)

	if debug_log_attacks:
		var plant_name: String = _plant.data.display_name if _plant.data != null else "Plant"
		var insect_name: String = target.data.display_name if target.data != null else "Insect"
		print("AttackComponent: %s fired at %s" % [plant_name, insect_name])


func _get_targeting() -> TargetingSystem:
	if targeting != null:
		return targeting
	var nodes: Array[Node] = get_tree().get_nodes_in_group("targeting_system")
	if nodes.is_empty():
		return null
	return nodes[0] as TargetingSystem


func _get_projectile_manager() -> ProjectileManager:
	if projectile_manager != null:
		return projectile_manager
	var nodes: Array[Node] = get_tree().get_nodes_in_group("projectile_manager")
	if nodes.is_empty():
		return null
	return nodes[0] as ProjectileManager
