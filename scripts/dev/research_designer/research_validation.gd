## Editor-only checks for the research catalog. Does not change gameplay.
class_name ResearchValidation
extends RefCounted


static func issues_for_catalog(catalog: Array[ResearchData]) -> Dictionary:
	var by_id: Dictionary = {} ## StringName → PackedStringArray
	var seen: Dictionary = {}
	for data: ResearchData in catalog:
		if data == null or data.research_id == &"":
			continue
		var id: StringName = data.research_id
		if seen.has(id):
			_add(by_id, id, "Duplicate ID")
		seen[id] = true
	for data: ResearchData in catalog:
		if data == null or data.research_id == &"":
			continue
		var id: StringName = data.research_id
		var parents: Dictionary = {}
		for parent_id: StringName in data.prerequisite_ids:
			if parent_id == &"":
				continue
			if parent_id == id:
				_add(by_id, id, "Invalid connection")
				continue
			if parents.has(parent_id):
				_add(by_id, id, "Invalid connection")
				continue
			parents[parent_id] = true
			if not seen.has(parent_id):
				_add(by_id, id, "Missing required research")
			if would_cycle(catalog, parent_id, id):
				_add(by_id, id, "Circular dependency")
		for mod: StatModifier in data.permanent_modifiers:
			if mod == null:
				continue
			if mod.stat_id == &"" or not StatIds.is_known(mod.stat_id):
				_add(by_id, id, "Missing effect target")
	return by_id


static func would_cycle(catalog: Array[ResearchData], parent_id: StringName, child_id: StringName) -> bool:
	if parent_id == &"" or child_id == &"":
		return false
	if parent_id == child_id:
		return true
	return _depends_on(catalog, parent_id, child_id, {})


static func _depends_on(
	catalog: Array[ResearchData],
	node_id: StringName,
	maybe_ancestor: StringName,
	seen: Dictionary
) -> bool:
	if node_id == maybe_ancestor:
		return true
	if seen.has(node_id):
		return false
	seen[node_id] = true
	var data: ResearchData = _find(catalog, node_id)
	if data == null:
		return false
	for parent_id: StringName in data.prerequisite_ids:
		if parent_id == &"":
			continue
		if _depends_on(catalog, parent_id, maybe_ancestor, seen):
			return true
	return false


static func _find(catalog: Array[ResearchData], research_id: StringName) -> ResearchData:
	for data: ResearchData in catalog:
		if data != null and data.research_id == research_id:
			return data
	return null


static func _add(by_id: Dictionary, research_id: StringName, message: String) -> void:
	var list: PackedStringArray = by_id.get(research_id, PackedStringArray()) as PackedStringArray
	if not list.has(message):
		list.append(message)
	by_id[research_id] = list
