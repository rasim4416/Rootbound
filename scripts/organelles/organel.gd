## Runtime Organelle instance (Mitochondrion, Ribosome, …).
##
## OrganelData is shared static config. This node owns install state and health.
## Behavior lives in child components (ATPProducer / ProteinProducer).
class_name Organel
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
signal protein_produced(target: Plant, protein: ProteinData)

@export var data: OrganelData:
	set(value):
		data = value
		_sync_from_data()

@export var visual_scale_min: float = 0.25
@export var visual_scale_max: float = 1.0
@export var debug_organel: bool = false

var current_health: float = 0.0
var is_alive: bool = true
var install_state: InstallState = InstallState.PENDING

static var _next_debug_id: int = 1
var debug_id: int = 0

@onready var _visual: Node2D = $Visual

var _install_duration: float = 0.0
var _install_elapsed: float = 0.0


func _ready() -> void:
	if debug_id == 0:
		debug_id = _next_debug_id
		_next_debug_id += 1
	add_to_group("organelles")
	_ensure_install_progress_bar()
	_rebuild_prototype_visual()
	_update_install_visual()
	set_process(true)


func _ensure_install_progress_bar() -> void:
	if has_node("InstallProgressBar"):
		return
	var bar := InstallProgressBar.new()
	bar.name = "InstallProgressBar"
	add_child(bar)


func _process(delta: float) -> void:
	if not is_alive:
		return
	if GameManager != null and GameManager.is_gameplay_frozen():
		return
	if install_state != InstallState.INSTALLING:
		return
	_install_elapsed += delta
	if _install_elapsed >= _install_duration:
		_finish_install()


func initialize(organel_data: OrganelData) -> void:
	data = organel_data
	is_alive = true
	install_state = InstallState.PENDING
	_install_duration = 0.0
	_install_elapsed = 0.0
	_sync_from_data()
	if is_node_ready():
		_update_install_visual()


func install() -> void:
	if not is_alive or data == null:
		return
	if install_state == InstallState.INSTALLING or install_state == InstallState.READY:
		return
	install_state = InstallState.INSTALLING
	_install_duration = maxf(data.build_time, 0.0)
	_install_elapsed = 0.0
	install_started.emit()
	_update_install_visual()
	if _install_duration <= 0.0:
		_finish_install()


func is_ready() -> bool:
	return install_state == InstallState.READY


func is_mature() -> bool:
	return is_ready()


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
	current_health = 0.0
	_emit_health_changed()
	died.emit()


func _sync_from_data() -> void:
	if data == null:
		current_health = 0.0
		return
	current_health = data.max_health
	_emit_health_changed()
	if is_node_ready():
		_rebuild_prototype_visual()


func _rebuild_prototype_visual() -> void:
	if _visual == null:
		return
	var organelle_id: StringName = data.organelle_id if data != null else &""
	OrganelPrototypeVisual.rebuild(_visual, organelle_id)


func _emit_health_changed() -> void:
	var max_hp: float = data.max_health if data != null else 0.0
	health_changed.emit(current_health, max_hp)


func _finish_install() -> void:
	if not is_alive or install_state != InstallState.INSTALLING:
		return
	install_state = InstallState.READY
	_update_install_visual()
	install_completed.emit()


func _update_install_visual() -> void:
	if _visual == null:
		return
	_visual.scale = Vector2(visual_scale_max, visual_scale_max)
