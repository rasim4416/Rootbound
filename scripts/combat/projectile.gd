## Free-moving combat projectile.
##
## Moves toward an assigned Insect target and applies damage once on contact.
## Stores the firing Nanobot for kill attribution.
class_name Projectile
extends Node2D

## Emitted after damage is successfully applied (not on cancel).
signal hit_applied(target: Insect, damage: float)
signal cancelled

@export var speed: float = 400.0
@export var hit_radius: float = 10.0
@export var debug_log_projectiles: bool = false

var damage: float = 0.0
var target: Insect = null
var attacker: Plant = null
var is_active: bool = false

var _has_hit: bool = false


func initialize(
	p_target: Insect,
	p_damage: float,
	p_speed: float,
	p_attacker: Plant = null
) -> void:
	target = p_target
	damage = p_damage
	speed = maxf(p_speed, 0.0)
	attacker = p_attacker
	is_active = false
	_has_hit = false


func launch() -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive:
		cancel()
		return
	is_active = true
	set_process(true)


func hit() -> void:
	if _has_hit or not is_active:
		return
	_has_hit = true
	is_active = false
	set_process(false)

	if GameManager != null and GameManager.is_gameplay_frozen():
		_cleanup()
		return

	if target == null or not is_instance_valid(target) or not target.is_alive:
		_cleanup()
		return

	var source: Plant = attacker if attacker != null and is_instance_valid(attacker) else null
	target.take_damage(damage, source)
	hit_applied.emit(target, damage)
	_spawn_impact_flash(target.global_position)

	if debug_log_projectiles:
		var insect_name: String = target.data.display_name if target.data != null else "Insect"
		print("Projectile: hit %s for %.0f" % [insect_name, damage])

	_cleanup()


func cancel() -> void:
	if _has_hit:
		return
	is_active = false
	set_process(false)
	cancelled.emit()
	_cleanup()


func _process(delta: float) -> void:
	if not is_active or _has_hit:
		return

	if GameManager != null and GameManager.is_gameplay_frozen():
		return

	if target == null or not is_instance_valid(target) or not target.is_alive:
		cancel()
		return

	var destination: Vector2 = target.global_position
	var to_target: Vector2 = destination - global_position
	var distance: float = to_target.length()

	if distance <= hit_radius:
		hit()
		return

	var step: float = speed * delta
	if step >= distance:
		global_position = destination
		hit()
		return

	global_position += to_target / distance * step
	rotation = to_target.angle()


func _spawn_impact_flash(at: Vector2) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var flash := Node2D.new()
	flash.name = "ImpactFlash"
	flash.global_position = at
	parent_node.add_child(flash)

	var glow := Polygon2D.new()
	glow.color = Color(0.85, 1.0, 1.0, 0.9)
	glow.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(6, -2), Vector2(8, 4), Vector2(0, 8),
		Vector2(-8, 4), Vector2(-6, -2),
	])
	flash.add_child(glow)

	var core := Polygon2D.new()
	core.color = Color(1.0, 1.0, 1.0, 1.0)
	core.polygon = PackedVector2Array([
		Vector2(0, -3), Vector2(3, 0), Vector2(0, 3), Vector2(-3, 0),
	])
	flash.add_child(core)

	var tree := get_tree()
	if tree != null:
		tree.create_timer(0.12).timeout.connect(flash.queue_free)


func _cleanup() -> void:
	if is_instance_valid(self):
		queue_free()
