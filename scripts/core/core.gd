## Runtime Core / Base the player defends.
##
## CoreData holds static configuration. Core holds HP / alive state.
## Does not reference insects, waves, or ResourceManager. Game Over is deferred.
class_name Core
extends Node

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float)
signal died

@export var data: CoreData:
	set(value):
		data = value
		_sync_from_data()

@export var debug_core_damage: bool = true

var current_health: float = 0.0
var is_alive: bool = true


func _ready() -> void:
	if data != null and current_health <= 0.0 and is_alive:
		_sync_from_data()


## Applies core_data and resets health for a fresh Core.
func initialize(core_data: CoreData) -> void:
	data = core_data
	is_alive = true
	_sync_from_data()


## Reduces health. Zero/negative damage and dead cores are ignored.
func take_damage(amount: float) -> void:
	if not is_alive or amount <= 0.0:
		return

	current_health = maxf(current_health - amount, 0.0)
	damaged.emit(amount)
	_emit_health_changed()

	if debug_core_damage:
		var max_hp: float = data.max_health if data != null else 0.0
		print("Core: %s HP: %.0f/%.0f" % [
			data.display_name if data != null else "Core",
			current_health,
			max_hp,
		])

	if current_health <= 0.0:
		die()


## Marks the Core destroyed once. Game Over is not handled here.
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


func _emit_health_changed() -> void:
	var max_hp: float = data.max_health if data != null else 0.0
	health_changed.emit(current_health, max_hp)
