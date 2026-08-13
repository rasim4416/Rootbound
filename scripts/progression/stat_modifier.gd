## One additive or multiplicative adjustment to a named stat.
##
## PlantData / InsectData stay immutable. Modifiers live in progression managers
## and are combined at query time by StatCalculator.
class_name StatModifier
extends Resource

enum ModifierType {
	ADDITIVE,
	MULTIPLICATIVE,
}

## Which stat this affects (see StatIds).
@export var stat_id: StringName = &""

@export var modifier_type: ModifierType = ModifierType.ADDITIVE

## ADDITIVE: flat amount added to base.
## MULTIPLICATIVE: fraction to apply as (1 + value), e.g. 0.10 = +10%.
@export var value: float = 0.0

## Optional identity for temporary effects (e.g. support aura from one Nanobot).
## Empty = no source tracking. Used to avoid duplicates and remove cleanly.
@export var source_id: StringName = &""


static func make(
	p_stat_id: StringName,
	p_type: ModifierType,
	p_value: float,
	p_source_id: StringName = &""
) -> StatModifier:
	var mod := StatModifier.new()
	mod.stat_id = p_stat_id
	mod.modifier_type = p_type
	mod.value = p_value
	mod.source_id = p_source_id
	return mod
