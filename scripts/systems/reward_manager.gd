## Scene-local Bio-Energy payouts and Nanobot XP attribution for kills / assists.
##
## Listens to WaveManager.insect_spawned, connects each Insect.died once.
## Bio-Energy goes to ResourceManager once per kill.
## Kill XP goes to the killing Nanobot; assist XP goes to active Supports.
class_name RewardManager
extends Node

signal biomass_rewarded(insect: Insect, amount: int)
signal xp_rewarded(nanobot: Plant, insect: Insect, amount: float)
signal assist_xp_rewarded(supporter: Plant, killer: Plant, insect: Insect, amount: float)
signal elements_rewarded(insect: Insect, drops: Dictionary)

@export var wave_manager: WaveManager
@export var debug_rewards: bool = false
@export var debug_nanobot_xp: bool = false
@export var debug_support: bool = false
@export var debug_element_rewards: bool = false

var _rewarded_instance_ids: Dictionary = {}
var _registered_instance_ids: Dictionary = {}


func _ready() -> void:
	if wave_manager == null:
		push_error("RewardManager: wave_manager is not assigned.")
		return

	if not wave_manager.insect_spawned.is_connected(_on_insect_spawned):
		wave_manager.insect_spawned.connect(_on_insect_spawned)


func register_insect(insect: Insect) -> void:
	_on_insect_spawned(insect)


func _on_insect_spawned(insect: Insect) -> void:
	if insect == null or not is_instance_valid(insect):
		return

	var instance_id: int = insect.get_instance_id()
	if _registered_instance_ids.has(instance_id):
		return
	_registered_instance_ids[instance_id] = true

	insect.died.connect(_on_insect_died.bind(insect), CONNECT_ONE_SHOT)


func _on_insect_died(killer: Plant, insect: Insect) -> void:
	if insect == null or not is_instance_valid(insect):
		return

	var instance_id: int = insect.get_instance_id()
	if _rewarded_instance_ids.has(instance_id):
		return
	_rewarded_instance_ids[instance_id] = true

	if insect.data == null:
		push_warning("RewardManager: dead insect has no InsectData.")
		return

	_grant_bio_energy(insect)
	_grant_element_drops(insect)
	_grant_kill_xp(killer, insect)
	_grant_assist_xp(killer, insect)


func _grant_bio_energy(insect: Insect) -> void:
	var base_reward: float = float(insect.data.biomass_reward)
	var reward: int = int(round(insect.get_effective_stat(StatIds.BIOMASS_REWARD, base_reward)))
	if reward <= 0:
		return

	var resources: ResourceManager = _get_resources()
	if resources == null:
		push_error("RewardManager: ResourceManager unavailable.")
		return

	resources.add_biomass(reward)
	biomass_rewarded.emit(insect, reward)

	if debug_rewards:
		print(
			"RewardManager: %s died → +%d Bio-Energy"
			% [insect.data.display_name, reward]
		)


func _grant_element_drops(insect: Insect) -> void:
	if insect.data == null:
		return
	var inventory: ElementInventory = _get_element_inventory()
	if inventory == null:
		push_warning("RewardManager: ElementInventory unavailable.")
		return

	var granted: Dictionary = {}
	for drop: ElementDrop in insect.data.element_drops:
		if drop == null:
			continue
		var element_id: StringName = drop.get_element_id()
		if element_id == &"" or drop.amount <= 0:
			continue
		var chance: float = clampf(drop.chance, 0.0, 1.0)
		if chance < 1.0 and randf() > chance:
			continue
		inventory.add_element(element_id, drop.amount)
		granted[element_id] = int(granted.get(element_id, 0)) + drop.amount
		if debug_element_rewards:
			print(
				"%s died → +%d %s"
				% [insect.data.display_name, drop.amount, drop.get_symbol()]
			)

	if not granted.is_empty():
		elements_rewarded.emit(insect, granted)


func _grant_kill_xp(killer: Plant, insect: Insect) -> void:
	if killer == null or not is_instance_valid(killer) or not killer.is_alive:
		return

	var xp_amount: float = insect.data.xp_reward
	xp_amount = insect.get_effective_stat(StatIds.XP_REWARD, xp_amount)
	if xp_amount <= 0.0:
		return

	killer.debug_nanobot_xp = killer.debug_nanobot_xp or debug_nanobot_xp
	if debug_nanobot_xp:
		print(
			"Combat Nanobot #%d killed %s → +%.0f XP"
			% [
				killer.debug_id,
				insect.data.display_name if insect.data != null else "Pathogen",
				xp_amount,
			]
		)

	killer.add_xp(xp_amount)
	xp_rewarded.emit(killer, insect, xp_amount)


func _grant_assist_xp(killer: Plant, insect: Insect) -> void:
	if killer == null or not is_instance_valid(killer) or not killer.is_alive:
		return
	if GameManager != null and GameManager.is_game_over():
		return

	var assist_base: float = insect.data.assist_xp_reward
	if assist_base <= 0.0:
		return

	var supporters: Array[Plant] = _find_active_supporters(killer)
	for supporter: Plant in supporters:
		if supporter == null or not is_instance_valid(supporter) or not supporter.is_alive:
			continue
		if supporter == killer:
			continue

		var xp_amount: float = supporter.get_effective_assist_xp_reward()
		if xp_amount <= 0.0:
			# Fall back to pathogen assist value when support data leaves it unset.
			xp_amount = assist_base
		if xp_amount <= 0.0:
			continue

		supporter.debug_nanobot_xp = supporter.debug_nanobot_xp or debug_nanobot_xp
		supporter.add_xp(xp_amount)
		assist_xp_rewarded.emit(supporter, killer, insect, xp_amount)

		if debug_support or debug_nanobot_xp:
			print(
				"Support Nanobot #%d received +%.0f assist XP (killer #%d)"
				% [supporter.debug_id, xp_amount, killer.debug_id]
			)


## Only Supports that are actively buffing the killer at kill time.
func _find_active_supporters(killer: Plant) -> Array[Plant]:
	var results: Array[Plant] = []
	if get_tree() == null:
		return results
	for node: Node in get_tree().get_nodes_in_group("support_components"):
		var support := node as SupportComponent
		if support == null:
			continue
		if not support.is_buffing(killer):
			continue
		var plant: Plant = support.get_plant()
		if plant == null or not is_instance_valid(plant) or not plant.is_alive:
			continue
		if not plant.is_support_nanobot():
			continue
		results.append(plant)
	return results


func _get_resources() -> ResourceManager:
	if GameManager == null:
		return null
	return GameManager.get_resource_manager()


func _get_element_inventory() -> ElementInventory:
	if GameManager == null:
		return null
	return GameManager.get_element_inventory()
