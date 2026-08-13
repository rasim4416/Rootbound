## Temporary upgrades for the current run only.
##
## Owned by GameManager and cleared on RESTART. Does not persist between sessions.
class_name RunProgressionManager
extends Node

var _modifiers: Array[StatModifier] = []


func add_modifier(modifier: StatModifier) -> void:
	if modifier == null:
		push_warning("RunProgressionManager.add_modifier: modifier is null.")
		return
	if modifier.stat_id == &"":
		push_warning("RunProgressionManager.add_modifier: missing stat_id.")
		return
	_modifiers.append(modifier)


func remove_modifier(modifier: StatModifier) -> void:
	if modifier == null:
		return
	_modifiers.erase(modifier)


func get_modifiers_for_stat(stat_id: StringName) -> Array[StatModifier]:
	var results: Array[StatModifier] = []
	for mod: StatModifier in _modifiers:
		if mod != null and mod.stat_id == stat_id:
			results.append(mod)
	return results


func get_modified_value(stat_id: StringName, base_value: float) -> float:
	return StatCalculator.calculate(base_value, [], get_modifiers_for_stat(stat_id))


## Clears all run modifiers (called on RESTART).
func reset() -> void:
	_modifiers.clear()
