## Per-instance Bio-Energy production for Generator Nanobots.
##
## Each placed generator owns its own timer. Production runs only while
## WaveManager is in an active wave state (SPAWNING / ACTIVE).
class_name BioEnergyProducerComponent
extends Node

@export var debug_bio_energy: bool = false

var _plant: Plant = null
var _wave_manager: WaveManager = null
var _timer: float = 0.0
var _producing: bool = false


func _ready() -> void:
	_plant = get_parent() as Plant
	if _plant == null:
		push_error("BioEnergyProducerComponent: parent must be a Plant.")
		set_process(false)
		return
	call_deferred("_bind_wave_manager")
	set_process(true)


func _bind_wave_manager() -> void:
	if get_tree() == null:
		return
	var nodes: Array[Node] = get_tree().get_nodes_in_group("wave_manager")
	if nodes.is_empty():
		# Fallback: search by class in the current scene.
		var root: Node = get_tree().current_scene
		if root != null:
			_wave_manager = _find_wave_manager(root)
	else:
		_wave_manager = nodes[0] as WaveManager

	if _wave_manager == null:
		push_warning("BioEnergyProducerComponent: WaveManager not found.")
		return

	if not _wave_manager.wave_started.is_connected(_on_wave_started):
		_wave_manager.wave_started.connect(_on_wave_started)
	if not _wave_manager.wave_completed.is_connected(_on_wave_completed):
		_wave_manager.wave_completed.connect(_on_wave_completed)
	if not _wave_manager.state_changed.is_connected(_on_wave_state_changed):
		_wave_manager.state_changed.connect(_on_wave_state_changed)
	if not _wave_manager.all_waves_completed.is_connected(_on_all_waves_completed):
		_wave_manager.all_waves_completed.connect(_on_all_waves_completed)

	_sync_producing_state()


func _find_wave_manager(node: Node) -> WaveManager:
	var as_wm := node as WaveManager
	if as_wm != null:
		return as_wm
	for child: Node in node.get_children():
		var found: WaveManager = _find_wave_manager(child)
		if found != null:
			return found
	return null


func _process(delta: float) -> void:
	if not _can_produce():
		return
	if not _producing:
		return

	_timer -= delta
	if _timer > 0.0:
		return

	_grant_bio_energy()
	_timer = _get_interval()


func _can_produce() -> bool:
	if _plant == null or not is_instance_valid(_plant):
		return false
	if not _plant.is_alive or not _plant.is_mature():
		return false
	if GameManager != null and GameManager.is_gameplay_frozen():
		return false
	if _plant.data == null:
		return false
	if _get_production_amount() <= 0:
		return false
	if _get_interval() <= 0.0:
		return false
	return true


func _is_wave_active_state(state: WaveManager.WaveState) -> bool:
	return state == WaveManager.WaveState.SPAWNING or state == WaveManager.WaveState.ACTIVE


func _sync_producing_state() -> void:
	if _wave_manager == null:
		_stop_production()
		return
	if _is_wave_active_state(_wave_manager.state):
		_start_production_interval()
	else:
		_stop_production()


func _start_production_interval() -> void:
	_producing = true
	_timer = _get_interval()
	if debug_bio_energy and _plant != null:
		print("Generator #%d: production interval started (%.1fs)" % [_plant.debug_id, _timer])


func _stop_production() -> void:
	_producing = false
	_timer = 0.0


func _on_wave_started(_wave_number: int) -> void:
	# Fresh interval each wave start.
	_start_production_interval()


func _on_wave_completed(_wave_number: int) -> void:
	_stop_production()


func _on_all_waves_completed() -> void:
	_stop_production()


func _on_wave_state_changed(new_state: WaveManager.WaveState) -> void:
	if _is_wave_active_state(new_state):
		if not _producing:
			_start_production_interval()
	else:
		_stop_production()


func _grant_bio_energy() -> void:
	if not _can_produce():
		return
	var amount: int = _get_production_amount()
	if amount <= 0:
		return
	if GameManager == null:
		return
	var resources: ResourceManager = GameManager.get_resource_manager()
	if resources == null:
		return
	resources.add_biomass(amount)
	if debug_bio_energy:
		print("Generator #%d: +%d Bio-Energy" % [_plant.debug_id, amount])


func _get_production_amount() -> int:
	if _plant == null or _plant.data == null:
		return 0
	return int(round(_plant.get_effective_stat(
		StatIds.BIO_ENERGY_PRODUCTION_AMOUNT,
		float(_plant.data.bio_energy_production_amount)
	)))


func _get_interval() -> float:
	if _plant == null or _plant.data == null:
		return 10.0
	return maxf(
		_plant.get_effective_stat(
			StatIds.BIO_ENERGY_PRODUCTION_INTERVAL,
			_plant.data.bio_energy_production_interval
		),
		0.05
	)
