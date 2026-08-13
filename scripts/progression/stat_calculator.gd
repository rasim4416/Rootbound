## Combines base values with permanent, run, and optional instance StatModifiers.
##
## Order: base → all ADDITIVE (permanent, run, instance) → all MULTIPLICATIVE
## as (1 + value) in the same layer order.
class_name StatCalculator
extends RefCounted


static func calculate(
	base_value: float,
	permanent_modifiers: Array[StatModifier],
	run_modifiers: Array[StatModifier],
	instance_modifiers: Array[StatModifier] = []
) -> float:
	var result: float = base_value

	for mod: StatModifier in permanent_modifiers:
		if mod != null and mod.modifier_type == StatModifier.ModifierType.ADDITIVE:
			result += mod.value
	for mod: StatModifier in run_modifiers:
		if mod != null and mod.modifier_type == StatModifier.ModifierType.ADDITIVE:
			result += mod.value
	for mod: StatModifier in instance_modifiers:
		if mod != null and mod.modifier_type == StatModifier.ModifierType.ADDITIVE:
			result += mod.value

	for mod: StatModifier in permanent_modifiers:
		if mod != null and mod.modifier_type == StatModifier.ModifierType.MULTIPLICATIVE:
			result *= 1.0 + mod.value
	for mod: StatModifier in run_modifiers:
		if mod != null and mod.modifier_type == StatModifier.ModifierType.MULTIPLICATIVE:
			result *= 1.0 + mod.value
	for mod: StatModifier in instance_modifiers:
		if mod != null and mod.modifier_type == StatModifier.ModifierType.MULTIPLICATIVE:
			result *= 1.0 + mod.value

	return result
