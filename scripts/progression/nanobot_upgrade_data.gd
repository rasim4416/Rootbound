## One selectable Nanobot level-up upgrade definition.
class_name NanobotUpgradeData
extends Resource

@export var upgrade_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var stat_id: StringName = &""
@export var modifier_type: StatModifier.ModifierType = StatModifier.ModifierType.MULTIPLICATIVE
@export var modifier_value: float = 0.0


func create_modifier() -> StatModifier:
	return StatModifier.make(stat_id, modifier_type, modifier_value)
