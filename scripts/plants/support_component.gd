## Aura component for SUPPORT-role Nanobots.
##
## Finds mature allied Nanobots in world-space range and applies temporary
## instance StatModifiers (attack speed). Does not attack or grant Bio-Energy.
class_name SupportComponent
extends Node2D

@export var debug_support: bool = false
@export var refresh_interval_sec: float = 0.1
@export var show_aura: bool = false

var _plant: Plant = null
var _buffed_targets: Dictionary = {} ## instance_id → Plant
var _applied_bonus: Dictionary = {} ## instance_id → float
var _source_id: StringName = &""
var _refresh_cooldown: float = 0.0
var _aura_radius: float = 0.0


func _ready() -> void:
	_plant = get_parent() as Plant
	if _plant == null:
		push_error("SupportComponent: parent must be a Plant.")
		return

	_source_id = StringName("support_as_%d" % _plant.get_instance_id())
	add_to_group("support_components")

	if not _plant.install_completed.is_connected(_on_install_completed):
		_plant.install_completed.connect(_on_install_completed)
	if not _plant.died.is_connected(_on_plant_died):
		_plant.died.connect(_on_plant_died)
	if not _plant.tree_exiting.is_connected(_on_plant_exiting):
		_plant.tree_exiting.connect(_on_plant_exiting)

	set_process(true)
	queue_redraw()


func get_plant() -> Plant:
	return _plant


func get_source_id() -> StringName:
	return _source_id


func is_buffing(nanobot: Plant) -> bool:
	if nanobot == null or not is_instance_valid(nanobot):
		return false
	return _buffed_targets.has(nanobot.get_instance_id())


func set_aura_visible(visible_flag: bool) -> void:
	show_aura = visible_flag
	queue_redraw()


func clear_all_buffs() -> void:
	var ids: Array = _buffed_targets.keys()
	for id: Variant in ids:
		var target: Plant = _buffed_targets[id] as Plant
		_stop_buffing(target)
	_buffed_targets.clear()
	_applied_bonus.clear()


func _process(delta: float) -> void:
	if _plant == null or not is_instance_valid(_plant):
		return

	_refresh_cooldown -= delta
	if _refresh_cooldown > 0.0:
		return
	_refresh_cooldown = maxf(refresh_interval_sec, 0.05)

	if GameManager != null and GameManager.is_game_over():
		clear_all_buffs()
		_aura_radius = 0.0
		queue_redraw()
		return

	if not _can_support():
		clear_all_buffs()
		_aura_radius = 0.0
		queue_redraw()
		return

	_refresh_support()


func _can_support() -> bool:
	if _plant == null or not _plant.is_alive:
		return false
	if not _plant.is_mature():
		return false
	if _plant.data == null or not _plant.data.is_support():
		return false
	if GameManager != null and GameManager.is_gameplay_frozen():
		return false
	return true


func _refresh_support() -> void:
	var range_px: float = _plant.get_effective_support_range()
	if not is_equal_approx(range_px, _aura_radius):
		_aura_radius = range_px
		queue_redraw()

	var range_sq: float = range_px * range_px
	var bonus: float = _plant.get_effective_support_attack_speed_bonus()
	var still_in_range: Dictionary = {}

	if bonus > 0.0 and range_px > 0.0:
		for node: Node in get_tree().get_nodes_in_group("nanobots"):
			var ally := node as Plant
			if not _is_valid_support_target(ally):
				continue
			var dist_sq: float = _plant.global_position.distance_squared_to(ally.global_position)
			if dist_sq > range_sq:
				continue
			still_in_range[ally.get_instance_id()] = ally
			_start_buffing(ally, bonus)

	# Remove buffs for allies that left range / became invalid.
	var previous_ids: Array = _buffed_targets.keys()
	for id: Variant in previous_ids:
		if still_in_range.has(id):
			continue
		var target: Plant = _buffed_targets[id] as Plant
		_stop_buffing(target)


func _is_valid_support_target(ally: Plant) -> bool:
	if ally == null or not is_instance_valid(ally):
		return false
	if ally == _plant:
		return false
	if not ally.is_alive or not ally.is_mature():
		return false
	return true


func _start_buffing(ally: Plant, bonus: float) -> void:
	var id: int = ally.get_instance_id()
	var already: bool = _buffed_targets.has(id)
	if already and ally.has_instance_modifier_source(_source_id):
		if is_equal_approx(float(_applied_bonus.get(id, -1.0)), bonus):
			return

	var mod: StatModifier = StatModifier.make(
		StatIds.ATTACK_SPEED,
		StatModifier.ModifierType.ADDITIVE,
		bonus,
		_source_id
	)
	ally.add_instance_modifier(mod)
	_buffed_targets[id] = ally
	_applied_bonus[id] = bonus

	if not already and debug_support:
		print(
			"Support Nanobot #%d buffed Combat Nanobot #%d (+%.0f%% AS)"
			% [_plant.debug_id, ally.debug_id, bonus * 100.0]
		)


func _stop_buffing(ally: Plant) -> void:
	if ally == null:
		return
	var id: int = ally.get_instance_id()
	_buffed_targets.erase(id)
	_applied_bonus.erase(id)
	if is_instance_valid(ally):
		ally.remove_instance_modifier_by_source(_source_id)
		if debug_support and _plant != null:
			print(
				"Support Nanobot #%d stopped buffing Combat Nanobot #%d"
				% [_plant.debug_id, ally.debug_id]
			)


func _on_install_completed() -> void:
	_refresh_cooldown = 0.0


func _on_plant_died() -> void:
	clear_all_buffs()
	show_aura = false
	queue_redraw()


func _on_plant_exiting() -> void:
	clear_all_buffs()


func _draw() -> void:
	if not show_aura:
		return
	if _plant == null or not _plant.is_alive or not _plant.is_mature():
		return
	var radius: float = _aura_radius
	if radius <= 0.0:
		radius = _plant.get_effective_support_range()
	if radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.85, 1.0, 0.12))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.35, 0.95, 1.0, 0.45), 2.0, true)
