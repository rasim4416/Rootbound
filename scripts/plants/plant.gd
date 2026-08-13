## Runtime plant / nanobot instance.
##
## PlantData is shared static config. This node owns install state, combat aiming,
## and per-instance XP / level / upgrade modifiers.
class_name Plant
extends Node2D

enum InstallState {
	PENDING,
	INSTALLING,
	READY,
}

signal health_changed(current_health: float, max_health: float)
signal install_started
signal install_completed
signal died
signal xp_changed(current_xp: float, xp_to_next: float, level: int)
signal level_up_available(nanobot: Plant)
signal leveled_up(new_level: int, upgrade: NanobotUpgradeData)
signal proteins_changed

@export var data: PlantData:
	set(value):
		data = value
		_sync_from_data()

@export var progression_data: NanobotProgressionData
@export var visual_scale_min: float = 0.25
@export var visual_scale_max: float = 1.0
@export var base_rotation_speed: float = 6.0
@export var debug_nanobot_xp: bool = false

var current_health: float = 0.0
var is_alive: bool = true
var install_state: InstallState = InstallState.PENDING

var level: int = 1
var current_xp: float = 0.0
var total_xp: float = 0.0
var _instance_modifiers: Array[StatModifier] = []
var _pending_level_ups: int = 0
var _protein_counts: Dictionary = {} ## protein_id → count
var _protein_names: Dictionary = {} ## protein_id → display_name
var _protein_token: int = 0
var _aim_target_world: Vector2 = Vector2.ZERO
var _has_aim_target: bool = false

static var _next_debug_id: int = 1
var debug_id: int = 0

@onready var _visual: Node2D = $Visual

var _body_pivot: Node2D = null

var _install_timer: SceneTreeTimer
var _install_token: int = 0
var _install_duration: float = 0.0
var _install_start_time_sec: float = 0.0
var _install_elapsed: float = 0.0

const _DEFAULT_PROGRESSION: NanobotProgressionData = preload(
	"res://data/progression/default_nanobot_progression.tres"
)


func _ready() -> void:
	if debug_id == 0:
		debug_id = _next_debug_id
		_next_debug_id += 1
	if progression_data == null:
		progression_data = _DEFAULT_PROGRESSION
	add_to_group("nanobots")
	_ensure_upgrade_indicator()
	_ensure_install_progress_bar()
	_ensure_attack_range_indicator()
	_rebuild_prototype_visual()
	_update_install_visual()
	set_process(true)


func _ensure_upgrade_indicator() -> void:
	if has_node("UpgradeIndicator"):
		return
	var indicator := NanobotUpgradeIndicator.new()
	indicator.name = "UpgradeIndicator"
	add_child(indicator)


func _ensure_install_progress_bar() -> void:
	if has_node("InstallProgressBar"):
		return
	var bar := InstallProgressBar.new()
	bar.name = "InstallProgressBar"
	add_child(bar)


func _ensure_attack_range_indicator() -> void:
	if has_node("AttackRangeIndicator"):
		return
	# Support bots use SupportComponent aura; generators have no attack range.
	if data != null and (data.is_support() or data.attack_range <= 0.0):
		return
	var indicator := AttackRangeIndicator.new()
	indicator.name = "AttackRangeIndicator"
	add_child(indicator)


func _process(delta: float) -> void:
	if not is_alive:
		return
	if GameManager != null and GameManager.is_gameplay_frozen():
		return

	if install_state == InstallState.INSTALLING:
		_install_elapsed += delta
		if _install_elapsed >= _install_duration:
			_finish_install()
		return

	if install_state == InstallState.READY:
		_apply_health_regen(delta)
		if _has_aim_target:
			_rotate_toward(_aim_target_world, delta)


func initialize(plant_data: PlantData) -> void:
	_cancel_install_timer()
	data = plant_data
	is_alive = true
	install_state = InstallState.PENDING
	_install_duration = 0.0
	_install_start_time_sec = 0.0
	_install_elapsed = 0.0
	rotation = 0.0
	_body_pivot = null
	level = 1
	current_xp = 0.0
	total_xp = 0.0
	_pending_level_ups = 0
	_instance_modifiers.clear()
	_protein_counts.clear()
	_protein_names.clear()
	_protein_token = 0
	_has_aim_target = false
	if progression_data == null:
		progression_data = _DEFAULT_PROGRESSION
	_sync_from_data()
	if is_node_ready():
		_update_install_visual()
		xp_changed.emit(current_xp, get_xp_to_next_level(), level)


func install() -> void:
	if not is_alive or data == null:
		return
	if install_state == InstallState.INSTALLING or install_state == InstallState.READY:
		return

	_cancel_install_timer()
	install_state = InstallState.INSTALLING
	_install_duration = maxf(get_effective_stat(StatIds.INSTALL_TIME, data.install_time), 0.0)
	_install_elapsed = 0.0
	_install_start_time_sec = Time.get_ticks_msec() / 1000.0
	install_started.emit()
	_update_install_visual()

	if _install_duration <= 0.0:
		_finish_install()


func is_ready() -> bool:
	return install_state == InstallState.READY


func is_mature() -> bool:
	return is_ready()


## Permanent + run + this Nanobot's instance modifiers.
func get_effective_stat(stat_id: StringName, base_value: float) -> float:
	var permanent_mods: Array[StatModifier] = []
	var run_mods: Array[StatModifier] = []
	if GameManager != null:
		var permanent := GameManager.get_permanent_progression()
		var run := GameManager.get_run_progression()
		if permanent != null:
			permanent_mods = permanent.get_modifiers_for_stat(stat_id)
		if run != null:
			run_mods = run.get_modifiers_for_stat(stat_id)
	return StatCalculator.calculate(
		base_value,
		permanent_mods,
		run_mods,
		_get_instance_modifiers_for_stat(stat_id)
	)


func get_effective_attack_cooldown() -> float:
	if data == null:
		return 1.0
	var base_cooldown: float = maxf(data.attack_cooldown, 0.05)
	var attack_speed: float = maxf(get_effective_stat(StatIds.ATTACK_SPEED, 1.0), 0.05)
	return base_cooldown / attack_speed


func get_effective_rotation_speed() -> float:
	return maxf(get_effective_stat(StatIds.ROTATION_SPEED, base_rotation_speed), 0.1)


func get_max_health() -> float:
	if data == null:
		return 0.0
	return maxf(get_effective_stat(StatIds.MAX_HEALTH, data.max_health), 1.0)


func _apply_health_regen(delta: float) -> void:
	var regen: float = get_effective_stat(StatIds.HEALTH_REGEN, 0.0)
	if regen <= 0.0:
		return
	var max_hp: float = get_max_health()
	if current_health >= max_hp:
		return
	current_health = minf(current_health + regen * delta, max_hp)
	_emit_health_changed()


func force_ready() -> void:
	if not is_alive:
		return
	_cancel_install_timer()
	if install_state == InstallState.READY:
		_update_install_visual()
		return
	install_state = InstallState.READY
	_update_install_visual()
	install_completed.emit()


func get_install_progress() -> float:
	match install_state:
		InstallState.PENDING:
			return 0.0
		InstallState.READY:
			return 1.0
		InstallState.INSTALLING:
			if _install_duration <= 0.0:
				return 1.0
			return clampf(_install_elapsed / _install_duration, 0.0, 1.0)
		_:
			return 0.0


## Sets aim destination; smooth rotation happens in _process via ROTATION_SPEED.
func aim_at(world_position: Vector2) -> void:
	if not is_alive or not is_ready():
		return
	_aim_target_world = world_position
	_has_aim_target = true


func clear_aim() -> void:
	_has_aim_target = false


func add_xp(amount: float) -> void:
	if not is_alive or amount <= 0.0:
		return
	if progression_data == null:
		progression_data = _DEFAULT_PROGRESSION

	current_xp += amount
	total_xp += amount

	if debug_nanobot_xp:
		print(
			"Nanobot #%d (%s) +%.0f XP → %.0f / %.0f (Lv %d)"
			% [
				debug_id,
				data.display_name if data != null else "Nanobot",
				amount,
				current_xp,
				get_xp_to_next_level(),
				level,
			]
		)

	_queue_pending_level_ups()
	xp_changed.emit(current_xp, get_xp_to_next_level(), level)

	if _pending_level_ups > 0:
		level_up_available.emit(self)


func get_xp_to_next_level() -> float:
	if progression_data == null:
		return 100.0
	return progression_data.get_xp_to_next_level(level)


func get_xp_progress() -> float:
	var needed: float = get_xp_to_next_level()
	if needed <= 0.0 or is_inf(needed):
		return 1.0
	return clampf(current_xp / needed, 0.0, 1.0)


func can_level_up() -> bool:
	if progression_data == null:
		return false
	if not progression_data.can_level_up(level):
		return false
	return current_xp >= get_xp_to_next_level() or _pending_level_ups > 0


func has_pending_level_up() -> bool:
	return _pending_level_ups > 0


func get_pending_level_up_count() -> int:
	return _pending_level_ups


## Applies a chosen upgrade and consumes one pending level-up.
func apply_level_up_upgrade(upgrade: NanobotUpgradeData) -> bool:
	if not is_alive or upgrade == null:
		return false
	if _pending_level_ups <= 0 and not can_level_up():
		return false

	if _pending_level_ups <= 0:
		_queue_pending_level_ups()
	if _pending_level_ups <= 0:
		return false

	var needed: float = get_xp_to_next_level()
	if not is_inf(needed):
		current_xp = maxf(current_xp - needed, 0.0)

	level += 1
	_pending_level_ups = maxi(_pending_level_ups - 1, 0)

	var mod: StatModifier = upgrade.create_modifier()
	_instance_modifiers.append(mod)

	if debug_nanobot_xp:
		print(
			"Nanobot #%d selected %s (+%s) → Level %d"
			% [debug_id, upgrade.display_name, upgrade.description, level]
		)

	leveled_up.emit(level, upgrade)
	_queue_pending_level_ups()
	xp_changed.emit(current_xp, get_xp_to_next_level(), level)

	if _pending_level_ups > 0:
		level_up_available.emit(self)
	return true


func get_instance_modifiers() -> Array[StatModifier]:
	return _instance_modifiers.duplicate()


## Adds a temporary/permanent instance modifier. Replaces any existing mod with the same source_id.
func add_instance_modifier(mod: StatModifier) -> void:
	if mod == null:
		return
	if mod.source_id != &"":
		remove_instance_modifier_by_source(mod.source_id)
	_instance_modifiers.append(mod)


## Removes all instance modifiers tagged with source_id. Returns how many were removed.
func remove_instance_modifier_by_source(source_id: StringName) -> int:
	if source_id == &"":
		return 0
	var removed: int = 0
	var i: int = _instance_modifiers.size() - 1
	while i >= 0:
		var mod: StatModifier = _instance_modifiers[i]
		if mod != null and mod.source_id == source_id:
			_instance_modifiers.remove_at(i)
			removed += 1
		i -= 1
	return removed


func has_instance_modifier_source(source_id: StringName) -> bool:
	if source_id == &"":
		return false
	for mod: StatModifier in _instance_modifiers:
		if mod != null and mod.source_id == source_id:
			return true
	return false


## Applies a protein as a run-scoped instance modifier on this Nanobot.
func apply_protein(protein: ProteinData) -> bool:
	if not is_alive or protein == null or not protein.is_available():
		return false
	if not protein.allow_multiple and _protein_counts.has(protein.protein_id):
		return false

	_protein_token += 1
	var source_id: StringName = StringName(
		"%s_%d_%d" % [String(protein.protein_id), get_instance_id(), _protein_token]
	)
	var mod: StatModifier = protein.create_modifier(source_id)
	add_instance_modifier(mod)

	var count: int = int(_protein_counts.get(protein.protein_id, 0)) + 1
	_protein_counts[protein.protein_id] = count
	_protein_names[protein.protein_id] = protein.display_name
	proteins_changed.emit()
	return true


func get_protein_summary() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for protein_id: Variant in _protein_counts.keys():
		results.append({
			"protein_id": protein_id,
			"display_name": String(_protein_names.get(protein_id, protein_id)),
			"count": int(_protein_counts[protein_id]),
		})
	return results


func is_support_nanobot() -> bool:
	return data != null and data.is_support()


func get_effective_support_range() -> float:
	if data == null:
		return 0.0
	return maxf(get_effective_stat(StatIds.SUPPORT_RANGE, data.support_range), 0.0)


func get_effective_support_attack_speed_bonus() -> float:
	if data == null:
		return 0.0
	return get_effective_stat(StatIds.SUPPORT_ATTACK_SPEED_BONUS, data.support_attack_speed_bonus)


func get_effective_assist_xp_reward() -> float:
	if data == null:
		return 0.0
	return maxf(get_effective_stat(StatIds.ASSIST_XP_REWARD, data.assist_xp_reward), 0.0)


func take_damage(amount: float) -> void:
	if not is_alive or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	_emit_health_changed()
	if current_health <= 0.0:
		die()


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	_cancel_install_timer()
	_pending_level_ups = 0
	_has_aim_target = false
	current_health = 0.0
	_emit_health_changed()
	died.emit()


func _queue_pending_level_ups() -> void:
	if progression_data == null:
		_pending_level_ups = 0
		return
	# Recalculate pending from a temp XP bank without mutating until choices apply.
	var bank: float = current_xp
	var sim_level: int = level
	var pending: int = 0
	while progression_data.can_level_up(sim_level):
		var need: float = progression_data.get_xp_to_next_level(sim_level)
		if bank < need:
			break
		bank -= need
		sim_level += 1
		pending += 1
	_pending_level_ups = pending


func _get_instance_modifiers_for_stat(stat_id: StringName) -> Array[StatModifier]:
	var results: Array[StatModifier] = []
	for mod: StatModifier in _instance_modifiers:
		if mod != null and mod.stat_id == stat_id:
			results.append(mod)
	return results


func _rotate_toward(world_position: Vector2, delta: float) -> void:
	if _body_pivot == null:
		return
	var direction: Vector2 = world_position - global_position
	if direction.length_squared() < 0.0001:
		return
	var target_angle: float = direction.angle()
	if data != null:
		target_angle += UnitGameplaySprites.get_plant_facing_offset(data.plant_id)
	var max_step: float = get_effective_rotation_speed() * delta
	_body_pivot.rotation = rotate_toward(_body_pivot.rotation, target_angle, max_step)


func _sync_from_data() -> void:
	if data == null:
		current_health = 0.0
		return
	current_health = get_max_health() if is_node_ready() else data.max_health
	_emit_health_changed()
	if is_node_ready():
		_rebuild_prototype_visual()


func _rebuild_prototype_visual() -> void:
	if _visual == null:
		return
	var plant_id: StringName = data.plant_id if data != null else &""
	PlantPrototypeVisual.rebuild(_visual, plant_id)
	_body_pivot = UnitSpriteVisual.find_body_pivot(_visual)


func _emit_health_changed() -> void:
	health_changed.emit(current_health, get_max_health())


func _finish_install() -> void:
	if not is_alive or install_state != InstallState.INSTALLING:
		return
	install_state = InstallState.READY
	_update_install_visual()
	install_completed.emit()


func _cancel_install_timer() -> void:
	_install_token += 1
	if _install_timer == null:
		return
	var timer := _install_timer
	_install_timer = null
	for connection: Dictionary in timer.timeout.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_object() == self:
			timer.timeout.disconnect(callable)
			break


func _update_install_visual() -> void:
	if _visual == null:
		return
	_visual.scale = Vector2(visual_scale_max, visual_scale_max)
