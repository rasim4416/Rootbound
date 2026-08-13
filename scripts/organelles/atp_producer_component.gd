## Generates ATP for a mature PRODUCER organelle (Mitochondrion).
## Production runs only while an infection wave is SPAWNING / ACTIVE.
class_name ATPProducerComponent
extends Node

@export var debug_atp: bool = false

var _organel: Organel = null
var _accumulator: float = 0.0
var _wave_manager: WaveManager = null


func _ready() -> void:
	_organel = get_parent() as Organel
	if _organel == null:
		push_error("ATPProducerComponent: parent must be an Organel.")
		return
	call_deferred("_bind_wave_manager")
	set_process(true)


func _bind_wave_manager() -> void:
	if get_tree() == null:
		return
	var nodes: Array[Node] = get_tree().get_nodes_in_group("wave_manager")
	if not nodes.is_empty():
		_wave_manager = nodes[0] as WaveManager


func _process(delta: float) -> void:
	if _organel == null or not _organel.is_alive or not _organel.is_mature():
		return
	if GameManager != null and GameManager.is_gameplay_frozen():
		return
	if not _is_wave_active():
		return
	if _organel.data == null:
		return

	var rate: float = _organel.data.atp_per_second
	if rate <= 0.0:
		return

	_accumulator += rate * delta
	var whole: int = int(floor(_accumulator))
	if whole <= 0:
		return
	_accumulator -= float(whole)

	var resources: ResourceManager = _get_resources()
	if resources == null:
		return
	resources.add_atp(whole)
	if debug_atp:
		print("Mitochondrion #%d produced +%d ATP" % [_organel.debug_id, whole])


func _is_wave_active() -> bool:
	if _wave_manager != null:
		return _wave_manager.is_wave_active()
	if GameManager != null:
		return GameManager.is_infection_wave_active()
	return false


func _get_resources() -> ResourceManager:
	if GameManager == null:
		return null
	return GameManager.get_resource_manager()
