## Scene-local projectile spawner.
##
## Parents projectiles under ProjectileLayer. AttackComponent requests shots here
## instead of owning projectile lifecycle.
class_name ProjectileManager
extends Node

@export var projectile_layer: Node2D
@export var projectile_scene: PackedScene
@export var debug_log_projectiles: bool = false

const _DEFAULT_SCENE: PackedScene = preload("res://scenes/combat/projectile.tscn")


func _ready() -> void:
	if projectile_scene == null:
		projectile_scene = _DEFAULT_SCENE
	add_to_group("projectile_manager")


## Spawns and launches a projectile from origin toward target.
func spawn_projectile(
	origin: Vector2,
	target: Insect,
	damage: float,
	speed: float,
	attacker: Plant = null
) -> Projectile:
	if GameManager != null and GameManager.is_gameplay_frozen():
		return null
	if target == null or not is_instance_valid(target) or not target.is_alive:
		return null
	if projectile_layer == null:
		push_error("ProjectileManager: projectile_layer is not assigned.")
		return null
	if projectile_scene == null:
		push_error("ProjectileManager: projectile_scene is missing.")
		return null

	var projectile := projectile_scene.instantiate() as Projectile
	if projectile == null:
		push_error("ProjectileManager: projectile_scene root must use Projectile.")
		return null

	projectile_layer.add_child(projectile)
	projectile.global_position = origin
	projectile.debug_log_projectiles = debug_log_projectiles
	projectile.initialize(target, damage, speed, attacker)
	projectile.launch()
	return projectile


## Cancels every active projectile (Game Over / scene teardown).
func cancel_all() -> void:
	if projectile_layer == null:
		return
	for child: Node in projectile_layer.get_children():
		var projectile := child as Projectile
		if projectile != null and is_instance_valid(projectile):
			projectile.cancel()
