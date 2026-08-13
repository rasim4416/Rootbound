## Temporary line/pulse from a Ribosome to a Nanobot after protein synthesis.
## Visual-only. Does not affect combat or economy.
class_name ProteinDeliveryVisual
extends Node2D

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _life: float = 0.55
var _elapsed: float = 0.0


static func play(from_node: Node2D, to_node: Node2D) -> void:
	if from_node == null or to_node == null:
		return
	if from_node.get_tree() == null:
		return
	var fx := ProteinDeliveryVisual.new()
	fx._from = from_node.global_position
	fx._to = to_node.global_position
	from_node.get_tree().current_scene.add_child(fx)


func _ready() -> void:
	z_index = 40
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _life:
		queue_free()


func _draw() -> void:
	var t: float = clampf(_elapsed / _life, 0.0, 1.0)
	var alpha: float = 1.0 - t
	var from_local: Vector2 = to_local(_from)
	var to_local_pos: Vector2 = to_local(_to)
	var mid: Vector2 = from_local.lerp(to_local_pos, t)
	draw_line(from_local, to_local_pos, Color(0.75, 0.45, 1.0, 0.35 * alpha), 2.0, true)
	draw_circle(mid, lerpf(6.0, 2.0, t), Color(0.95, 0.75, 1.0, 0.85 * alpha))
	draw_circle(to_local_pos, lerpf(2.0, 10.0, t), Color(0.85, 0.55, 1.0, 0.35 * alpha))
