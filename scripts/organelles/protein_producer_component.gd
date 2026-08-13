## Consumes ATP to synthesize proteins onto the nearest mature Nanobot.
class_name ProteinProducerComponent
extends Node

@export var debug_protein: bool = false

var _organel: Organel = null
var _timer: float = 0.0
var _last_target: Plant = null
var _last_protein: ProteinData = null


func _ready() -> void:
	_organel = get_parent() as Organel
	if _organel == null:
		push_error("ProteinProducerComponent: parent must be an Organel.")
		return
	if _organel.data != null:
		_timer = maxf(_organel.data.production_interval, 0.0)
	set_process(true)


func get_production_progress() -> float:
	if _organel == null or _organel.data == null:
		return 0.0
	var interval: float = maxf(_organel.data.production_interval, 0.001)
	return clampf(1.0 - (_timer / interval), 0.0, 1.0)


func get_time_remaining() -> float:
	return maxf(_timer, 0.0)


func get_last_target() -> Plant:
	if _last_target != null and is_instance_valid(_last_target) and _last_target.is_alive:
		return _last_target
	return null


func get_active_protein() -> ProteinData:
	if _organel == null or _organel.data == null:
		return null
	return _organel.data.protein


func preview_target() -> Plant:
	return _find_nearest_nanobot()


func _process(delta: float) -> void:
	if _organel == null or not _organel.is_alive or not _organel.is_mature():
		return
	if GameManager != null and GameManager.is_gameplay_frozen():
		return
	if not _is_wave_active():
		return
	if _organel.data == null:
		return

	_timer -= delta
	if _timer > 0.0:
		return

	_timer = maxf(_organel.data.production_interval, 0.1)
	_try_synthesize()


func _is_wave_active() -> bool:
	if GameManager != null:
		return GameManager.is_infection_wave_active()
	return false


func _try_synthesize() -> void:
	var protein: ProteinData = _organel.data.protein
	if protein == null:
		return
	# ResearchManager is authoritative for protein unlocks.
	if GameManager != null:
		var research: ResearchManager = GameManager.get_research_manager()
		if research != null and not research.is_protein_data_unlocked(protein):
			if debug_protein:
				print("Ribosome #%d: protein research locked" % _organel.debug_id)
			return
	elif not protein.is_available():
		return

	var cost: int = maxi(_organel.data.protein_atp_cost, 0)
	var resources: ResourceManager = _get_resources()
	if resources == null:
		return
	if cost > 0 and not resources.can_afford_atp(cost):
		if debug_protein:
			print("Ribosome #%d: not enough ATP (%d needed)" % [_organel.debug_id, cost])
		return

	var target: Plant = _find_nearest_nanobot()
	if target == null:
		if debug_protein:
			print("Ribosome #%d: no valid Nanobot target" % _organel.debug_id)
		return

	if cost > 0 and not resources.spend_atp(cost):
		return

	if not target.apply_protein(protein):
		# Refund if apply failed (e.g. stacking disallowed).
		if cost > 0:
			resources.add_atp(cost)
		return

	_last_target = target
	_last_protein = protein
	_organel.protein_produced.emit(target, protein)
	ProteinDeliveryVisual.play(_organel, target)

	if debug_protein:
		print(
			"Ribosome #%d synthesized %s onto Nanobot #%d (-%d ATP)"
			% [_organel.debug_id, protein.display_name, target.debug_id, cost]
		)


func _find_nearest_nanobot() -> Plant:
	if _organel == null or get_tree() == null:
		return null
	var best: Plant = null
	var best_dist_sq: float = INF
	var origin: Vector2 = _organel.global_position
	for node: Node in get_tree().get_nodes_in_group("nanobots"):
		var nanobot := node as Plant
		if nanobot == null or not is_instance_valid(nanobot):
			continue
		if not nanobot.is_alive or not nanobot.is_mature():
			continue
		var dist_sq: float = origin.distance_squared_to(nanobot.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = nanobot
	return best


func _get_resources() -> ResourceManager:
	if GameManager == null:
		return null
	return GameManager.get_resource_manager()
