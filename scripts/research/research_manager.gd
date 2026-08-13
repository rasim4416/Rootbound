## Permanent research unlock state. Costs are paid in CHONS elements.
##
## Catalog auto-loads every ResearchData under res://data/research/.
## Adding a normal research = drop a .tres file (no ResearchManager code edit).
class_name ResearchManager
extends Node

signal research_unlocked(research_id: StringName)

const RESEARCH_DATA_ROOT: String = "res://data/research"

@export var research_catalog: Array[ResearchData] = []

var _unlocked: Dictionary = {} ## research_id → true


func _ready() -> void:
	if research_catalog.is_empty():
		_load_catalog_from_disk()
	_apply_defaults()
	_sync_permanent_effects()


func get_research(research_id: StringName) -> ResearchData:
	for entry: ResearchData in research_catalog:
		if entry != null and entry.research_id == research_id:
			return entry
	return null


func get_all_research() -> Array[ResearchData]:
	return research_catalog.duplicate()


func is_unlocked(research_id: StringName) -> bool:
	if research_id == &"":
		return false
	return _unlocked.has(research_id)


func get_unlocked_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: Variant in _unlocked.keys():
		ids.append(key as StringName)
	return ids


func can_unlock(research_id: StringName) -> bool:
	if is_unlocked(research_id):
		return false
	var data: ResearchData = get_research(research_id)
	if data == null:
		return false
	if not data.unlockable:
		return false
	return can_afford_costs(data.costs)


func can_afford_costs(costs: Array[ResearchCost]) -> bool:
	var inventory: ElementInventory = _get_inventory()
	if inventory == null:
		return false
	for cost: ResearchCost in costs:
		if cost == null or not cost.is_valid():
			continue
		if not inventory.can_afford(cost.get_element_id(), cost.amount):
			return false
	return true


func unlock(research_id: StringName) -> bool:
	if is_unlocked(research_id):
		return false
	var data: ResearchData = get_research(research_id)
	if data == null:
		return false
	if not data.unlockable:
		return false
	if not can_afford_costs(data.costs):
		return false

	var inventory: ElementInventory = _get_inventory()
	if inventory == null:
		return false

	for cost: ResearchCost in data.costs:
		if cost == null or not cost.is_valid():
			continue
		if not inventory.spend_element(cost.get_element_id(), cost.amount):
			push_error("ResearchManager: spend failed mid-unlock for %s" % research_id)
			return false

	_unlocked[research_id] = true
	_sync_permanent_effects()
	research_unlocked.emit(research_id)
	return true


## Authoritative protein unlock check used by Ribosomes.
func is_protein_unlocked(protein_id: StringName) -> bool:
	if protein_id == &"":
		return false
	for entry: ResearchData in research_catalog:
		if entry == null or entry.protein == null:
			continue
		if entry.protein.protein_id != protein_id:
			continue
		return is_unlocked(entry.research_id)
	return false


func is_protein_data_unlocked(protein: ProteinData) -> bool:
	if protein == null:
		return false
	return is_protein_unlocked(protein.protein_id)


## Restore unlocks from save, then re-apply default unlocks + permanent effects.
func apply_saved_unlocks(unlocked_ids: Array[StringName]) -> void:
	_unlocked.clear()
	for research_id: StringName in unlocked_ids:
		if research_id != &"":
			_unlocked[research_id] = true
	_apply_defaults()
	_sync_permanent_effects()


func get_cost_summary(research_id: StringName) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var data: ResearchData = get_research(research_id)
	if data == null:
		return results
	for cost: ResearchCost in data.costs:
		if cost == null or not cost.is_valid():
			continue
		results.append({
			"element_id": cost.get_element_id(),
			"amount": cost.amount,
			"symbol": cost.element.symbol if cost.element != null else "?",
		})
	return results


func _apply_defaults() -> void:
	for entry: ResearchData in research_catalog:
		if entry == null or entry.research_id == &"":
			continue
		if entry.unlocked_by_default:
			_unlocked[entry.research_id] = true


## Rebuild PermanentProgressionManager modifiers from all unlocked research.
func _sync_permanent_effects() -> void:
	var permanent: PermanentProgressionManager = _get_permanent()
	if permanent == null:
		return
	permanent.remove_modifiers_with_source_prefix(&"research_")
	for research_id: Variant in _unlocked.keys():
		var data: ResearchData = get_research(research_id as StringName)
		if data == null:
			continue
		for mod: StatModifier in data.permanent_modifiers:
			if mod == null or mod.stat_id == &"":
				continue
			var applied: StatModifier = StatModifier.make(
				mod.stat_id,
				mod.modifier_type,
				mod.value,
				StringName("research_%s_%s" % [String(data.research_id), String(mod.stat_id)])
			)
			permanent.add_modifier(applied)


## Loads every ResearchData .tres under data/research (recursive).
func _load_catalog_from_disk() -> void:
	research_catalog.clear()
	var found: Array[ResearchData] = []
	_scan_research_dir(RESEARCH_DATA_ROOT, found)
	research_catalog = found


func _scan_research_dir(path: String, out_list: Array[ResearchData]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("ResearchManager: cannot open %s" % path)
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if entry_name.begins_with("."):
			entry_name = dir.get_next()
			continue
		var full: String = path.path_join(entry_name)
		if dir.current_is_dir():
			_scan_research_dir(full, out_list)
		elif entry_name.ends_with(".tres") or entry_name.ends_with(".res"):
			var loaded: Resource = load(full)
			var research := loaded as ResearchData
			if research != null and research.research_id != &"":
				out_list.append(research)
		entry_name = dir.get_next()
	dir.list_dir_end()


func _get_inventory() -> ElementInventory:
	if GameManager == null:
		return null
	return GameManager.get_element_inventory()


func _get_permanent() -> PermanentProgressionManager:
	if GameManager == null:
		return null
	return GameManager.get_permanent_progression()
