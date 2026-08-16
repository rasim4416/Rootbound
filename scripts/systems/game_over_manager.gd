## Scene-local Game Over coordinator.
##
## Listens to Core.died, flips GameManager to GAME_OVER once, stops waves,
## freezes insects, and shows the HUD overlay. Does not own Core UI or economy.
class_name GameOverManager
extends Node

@export var core: Core
@export var wave_manager: WaveManager
@export var insect_layer: Node2D
@export var gameplay_hud: Control
@export var projectile_manager: ProjectileManager
@export var level_up_controller: NanobotLevelUpController

var _game_over_handled: bool = false


func _ready() -> void:
	if core == null:
		push_error("GameOverManager: core is not assigned.")
		return
	if wave_manager == null:
		push_error("GameOverManager: wave_manager is not assigned.")
		return

	if not core.died.is_connected(_on_core_died):
		core.died.connect(_on_core_died)


func _on_core_died() -> void:
	if _game_over_handled:
		return
	_game_over_handled = true

	if GameManager != null:
		GameManager.enter_game_over()

	if wave_manager != null:
		wave_manager.stop_all_waves()

	_freeze_all_insects()
	_cancel_all_projectiles()
	_clear_all_support_buffs()
	_close_level_up_ui()

	if gameplay_hud != null and gameplay_hud.has_method("show_game_over"):
		gameplay_hud.call("show_game_over")


func _clear_all_support_buffs() -> void:
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group("support_components"):
		var support := node as SupportComponent
		if support != null:
			support.clear_all_buffs()
			support.set_aura_visible(false)
	for node: Node in get_tree().get_nodes_in_group("attack_range_indicators"):
		var indicator := node as AttackRangeIndicator
		if indicator != null:
			indicator.set_range_visible(false)
			indicator.set_hover_visible(false)


func _freeze_all_insects() -> void:
	if insect_layer == null:
		return

	for child: Node in insect_layer.get_children():
		var insect := child as Insect
		if insect == null or not is_instance_valid(insect):
			continue
		for sub: Node in insect.get_children():
			var grid_follower := sub as GridPathFollower
			if grid_follower != null:
				grid_follower.pause()
				continue
			var legacy := sub as PathFollower
			if legacy != null:
				legacy.pause()


func _cancel_all_projectiles() -> void:
	var manager: ProjectileManager = projectile_manager
	if manager == null and get_tree() != null:
		var nodes: Array[Node] = get_tree().get_nodes_in_group("projectile_manager")
		if not nodes.is_empty():
			manager = nodes[0] as ProjectileManager
	if manager != null:
		manager.cancel_all()


func _close_level_up_ui() -> void:
	var controller: NanobotLevelUpController = level_up_controller
	if controller == null and get_tree() != null:
		var nodes: Array[Node] = get_tree().get_nodes_in_group("nanobot_level_up_controller")
		if not nodes.is_empty():
			controller = nodes[0] as NanobotLevelUpController
	if controller != null:
		controller.force_close()
