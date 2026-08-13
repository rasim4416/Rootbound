## Long-lived Research Lab progression (session-owned for now).
##
## Survives Main scene reload. Not saved to disk yet — starts empty each editor
## session. RunProgressionManager owns temporary upgrades and is cleared on restart.
class_name PermanentProgressionManager
extends Node

var _modifiers: Array[StatModifier] = []


func add_modifier(modifier: StatModifier) -> void:
	if modifier == null:
		push_warning("PermanentProgressionManager.add_modifier: modifier is null.")
		return
	if modifier.stat_id == &"":
		push_warning("PermanentProgressionManager.add_modifier: missing stat_id.")
		return
	_modifiers.append(modifier)


func remove_modifier(modifier: StatModifier) -> void:
	if modifier == null:
		return
	_modifiers.erase(modifier)


## Removes modifiers whose source_id starts with the given prefix (e.g. "research_").
func remove_modifiers_with_source_prefix(prefix: StringName) -> void:
	if prefix == &"":
		return
	var prefix_str: String = String(prefix)
	var i: int = _modifiers.size() - 1
	while i >= 0:
		var mod: StatModifier = _modifiers[i]
		if mod != null and String(mod.source_id).begins_with(prefix_str):
			_modifiers.remove_at(i)
		i -= 1


func get_modifiers_for_stat(stat_id: StringName) -> Array[StatModifier]:
	var results: Array[StatModifier] = []
	for mod: StatModifier in _modifiers:
		if mod != null and mod.stat_id == stat_id:
			results.append(mod)
	return results


func get_modified_value(stat_id: StringName, base_value: float) -> float:
	return StatCalculator.calculate(base_value, get_modifiers_for_stat(stat_id), [])


func clear_all() -> void:
	_modifiers.clear()
