## Bridges path leaks to Core / Nucleus damage.
##
## Listens to WaveManager.insect_spawned, hooks GridPathFollower.path_completed
## (legacy PathFollower still supported), and applies InsectData.attack_damage
## to the Core. Insects despawn without died (no Biomass).
class_name CoreDamageSystem
extends Node

@export var core: Core
@export var wave_manager: WaveManager

## TEMPORARY DEBUG: log leak damage. Disable when a Core HUD exists.
@export var debug_core_damage: bool = true

## Instance IDs that already dealt Core damage (no duplicate hits).
var _damaged_core_instance_ids: Dictionary = {}
var _registered_instance_ids: Dictionary = {}


func _ready() -> void:
	if core == null:
		push_error("CoreDamageSystem: core is not assigned.")
		return
	if wave_manager == null:
		push_error("CoreDamageSystem: wave_manager is not assigned.")
		return

	if not wave_manager.insect_spawned.is_connected(_on_insect_spawned):
		wave_manager.insect_spawned.connect(_on_insect_spawned)


func _on_insect_spawned(insect: Insect) -> void:
	if insect == null or not is_instance_valid(insect):
		return

	var instance_id: int = insect.get_instance_id()
	if _registered_instance_ids.has(instance_id):
		return
	_registered_instance_ids[instance_id] = true

	var grid_follower := insect.get_node_or_null("GridPathFollower") as GridPathFollower
	if grid_follower != null:
		grid_follower.path_completed.connect(_on_path_completed.bind(insect), CONNECT_ONE_SHOT)
		return

	var legacy := insect.get_node_or_null("PathFollower") as PathFollower
	if legacy != null:
		legacy.path_completed.connect(_on_path_completed.bind(insect), CONNECT_ONE_SHOT)
		return

	push_warning("CoreDamageSystem: spawned insect missing GridPathFollower.")


func _on_path_completed(insect: Insect) -> void:
	if insect == null or not is_instance_valid(insect):
		return
	# Combat deaths stop the follower without path_completed; still guard.
	if not insect.is_alive:
		return
	if GameManager != null and GameManager.is_game_over():
		insect.despawn()
		return

	var instance_id: int = insect.get_instance_id()
	if _damaged_core_instance_ids.has(instance_id):
		return
	_damaged_core_instance_ids[instance_id] = true

	var amount: float = insect.get_core_damage()

	if core == null:
		push_error("CoreDamageSystem: core missing when applying damage.")
	elif core.is_alive and amount > 0.0:
		if debug_core_damage:
			var insect_name: String = insect.data.display_name if insect.data != null else "Insect"
			print("CoreDamageSystem: %s reached Core → Core -%.0f HP" % [insect_name, amount])
		core.take_damage(amount)

	# Leak removal: no died signal → no Biomass.
	insect.despawn()
