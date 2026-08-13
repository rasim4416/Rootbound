## Tracks pending Nanobot level-ups and opens the choice UI on demand.
##
## Upgrades are per-Nanobot and role-gated:
## - Attack bots: combat upgrades
## - Support bots: Range / Aura Bonus / Assist XP
class_name NanobotLevelUpController
extends Node

signal pending_upgrades_changed(count: int)

@export var level_up_ui: NanobotLevelUpUI
@export var upgrades: Array[NanobotUpgradeData] = []
@export var support_upgrades: Array[NanobotUpgradeData] = []
@export var debug_nanobot_xp: bool = false

var _active_nanobot: Plant = null
var _listening: Dictionary = {} ## instance_id → Plant
var _ui_open: bool = false


func _ready() -> void:
	if level_up_ui != null:
		level_up_ui.upgrade_selected.connect(_on_upgrade_selected)
		if level_up_ui.has_signal("closed"):
			level_up_ui.closed.connect(_on_ui_closed)
		level_up_ui.hide_panel()
	add_to_group("nanobot_level_up_controller")
	call_deferred("_bind_existing_nanobots")
	call_deferred("_emit_pending_count")


func _bind_existing_nanobots() -> void:
	for node: Node in get_tree().get_nodes_in_group("nanobots"):
		_register_nanobot(node as Plant)
	_emit_pending_count()


func register_nanobot(nanobot: Plant) -> void:
	_register_nanobot(nanobot)
	_emit_pending_count()


func _register_nanobot(nanobot: Plant) -> void:
	if nanobot == null or not is_instance_valid(nanobot):
		return
	var id: int = nanobot.get_instance_id()
	if _listening.has(id):
		return
	_listening[id] = nanobot
	nanobot.level_up_available.connect(_on_level_up_available)
	nanobot.leveled_up.connect(_on_leveled_up)
	nanobot.tree_exiting.connect(_on_nanobot_exiting.bind(nanobot))


func get_pending_upgrade_count() -> int:
	var total: int = 0
	for id: Variant in _listening.keys():
		var nanobot: Plant = _listening[id] as Plant
		if nanobot == null or not is_instance_valid(nanobot) or not nanobot.is_alive:
			continue
		total += nanobot.get_pending_level_up_count()
	return total


## Opens the upgrade menu for a specific Nanobot (required for per-bot upgrades).
func open_upgrade_menu(preferred_nanobot: Plant = null) -> void:
	if GameManager != null and GameManager.is_game_over():
		return
	if _ui_open:
		if preferred_nanobot != null and preferred_nanobot == _active_nanobot:
			return
		if preferred_nanobot != null and preferred_nanobot != _active_nanobot:
			force_close()
		else:
			return

	var target: Plant = null
	if (
		preferred_nanobot != null
		and is_instance_valid(preferred_nanobot)
		and preferred_nanobot.is_alive
		and preferred_nanobot.has_pending_level_up()
	):
		target = preferred_nanobot

	if target == null:
		return

	_active_nanobot = target
	_ui_open = true
	if level_up_ui != null:
		level_up_ui.show_for_nanobot(target, _upgrades_for(target))


func force_close() -> void:
	_active_nanobot = null
	_ui_open = false
	if level_up_ui != null:
		level_up_ui.hide_panel()
	_emit_pending_count()


func _upgrades_for(nanobot: Plant) -> Array[NanobotUpgradeData]:
	if nanobot != null and nanobot.is_support_nanobot():
		return support_upgrades
	return upgrades


func _on_level_up_available(_nanobot: Plant) -> void:
	_emit_pending_count()


func _on_leveled_up(_level: int, _upgrade: NanobotUpgradeData) -> void:
	_emit_pending_count()


func _on_nanobot_exiting(nanobot: Plant) -> void:
	if nanobot == null:
		return
	_listening.erase(nanobot.get_instance_id())
	if _active_nanobot == nanobot:
		force_close()
	else:
		_emit_pending_count()


func _on_upgrade_selected(upgrade: NanobotUpgradeData) -> void:
	if _active_nanobot == null or not is_instance_valid(_active_nanobot):
		force_close()
		return
	if GameManager != null and GameManager.is_game_over():
		force_close()
		return

	var nanobot: Plant = _active_nanobot
	nanobot.debug_nanobot_xp = nanobot.debug_nanobot_xp or debug_nanobot_xp
	nanobot.apply_level_up_upgrade(upgrade)

	# Stay on this Nanobot only — never auto-switch to another bot's upgrades.
	if nanobot.is_alive and nanobot.has_pending_level_up():
		_active_nanobot = nanobot
		_ui_open = true
		if level_up_ui != null:
			level_up_ui.show_for_nanobot(nanobot, _upgrades_for(nanobot))
		_emit_pending_count()
		return

	force_close()


func _on_ui_closed() -> void:
	_active_nanobot = null
	_ui_open = false
	_emit_pending_count()


func _emit_pending_count() -> void:
	pending_upgrades_changed.emit(get_pending_upgrade_count())
