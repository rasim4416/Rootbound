## Scene-local insect target detection / selection.
##
## Scans InsectLayer for living Insect nodes. Combat systems (future) call into
## this helper — plants and insects stay unaware of each other.
##
## Selection modes FIRST / STRONGEST / WEAKEST / PRIORITY are reserved for later;
## only NEAREST is implemented now.
class_name TargetingSystem
extends Node

## Future expansion — only NEAREST is used today.
enum SelectMode {
	NEAREST,
	FIRST,
	STRONGEST,
	WEAKEST,
	PRIORITY,
}

@export var insect_layer: Node2D

@export_group("Temporary Debug")
## TEMPORARY: print nearest target on an interval. Disable/remove when combat UI exists.
@export var debug_print_nearest: bool = true
@export var debug_origin: Vector2 = Vector2(560, 320)
@export var debug_range: float = 400.0
@export var debug_interval: float = 1.0

var _debug_timer: float = 0.0


func _ready() -> void:
	if insect_layer == null:
		push_error("TargetingSystem: insect_layer is not assigned.")
	add_to_group("targeting_system")


func _process(delta: float) -> void:
	# TEMPORARY DEBUG — remove with debug_print_nearest / this block later.
	if not debug_print_nearest:
		return
	_debug_timer += delta
	if _debug_timer < debug_interval:
		return
	_debug_timer = 0.0
	_debug_print_nearest_target()


## Living insects within range of origin (inclusive), optionally filtered.
## filter_fn receives an Insect and should return true to keep it.
func get_targets_in_range(
	origin: Vector2,
	range_radius: float,
	filter_fn: Callable = Callable()
) -> Array[Insect]:
	var results: Array[Insect] = []

	if insect_layer == null:
		push_warning("TargetingSystem.get_targets_in_range: insect_layer is null.")
		return results
	if range_radius < 0.0:
		push_warning("TargetingSystem.get_targets_in_range: range must be >= 0.")
		return results

	var range_sq: float = range_radius * range_radius

	for child: Node in insect_layer.get_children():
		var insect := child as Insect
		if insect == null or not insect.is_alive:
			continue
		if not is_instance_valid(insect):
			continue

		var offset: Vector2 = insect.global_position - origin
		if offset.length_squared() > range_sq:
			continue

		if filter_fn.is_valid() and not filter_fn.call(insect):
			continue

		results.append(insect)

	return results


## Nearest living insect within range, or null if none.
## Optional filter_fn receives an Insect and should return true to keep it.
func find_nearest_target(
	origin: Vector2,
	range_radius: float,
	filter_fn: Callable = Callable()
) -> Insect:
	return select_target(origin, range_radius, SelectMode.NEAREST, filter_fn)


## Selects a target using the given mode. Non-NEAREST modes fall back to nearest
## until they are implemented.
func select_target(
	origin: Vector2,
	range_radius: float,
	mode: SelectMode = SelectMode.NEAREST,
	filter_fn: Callable = Callable()
) -> Insect:
	var candidates: Array[Insect] = get_targets_in_range(origin, range_radius, filter_fn)
	if candidates.is_empty():
		return null

	match mode:
		SelectMode.NEAREST:
			return _pick_nearest(origin, candidates)
		SelectMode.FIRST, SelectMode.STRONGEST, SelectMode.WEAKEST, SelectMode.PRIORITY:
			# Reserved for future targeting rules.
			return _pick_nearest(origin, candidates)
		_:
			return _pick_nearest(origin, candidates)


func _pick_nearest(origin: Vector2, candidates: Array[Insect]) -> Insect:
	var best: Insect = null
	var best_dist_sq: float = INF

	for insect: Insect in candidates:
		var dist_sq: float = origin.distance_squared_to(insect.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = insect

	return best


func _debug_print_nearest_target() -> void:
	var target: Insect = find_nearest_target(debug_origin, debug_range)
	if target == null or target.data == null:
		print("TargetingSystem debug: no target in range.")
		return
	print(
		"TargetingSystem debug: nearest = %s (%s) dist=%.1f"
		% [
			target.data.display_name,
			String(target.data.insect_id),
			debug_origin.distance_to(target.global_position),
		]
	)
