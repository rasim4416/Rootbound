## One protein definition that Ribosomes can synthesize onto Nanobots.
##
## Proteins become instance StatModifiers on a specific Nanobot for the run.
## Unlock authority lives on ResearchManager (not ProteinData.unlocked at runtime).
class_name ProteinData
extends Resource

@export var protein_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var stat_id: StringName = &""
@export var modifier_type: StatModifier.ModifierType = StatModifier.ModifierType.MULTIPLICATIVE
@export var modifier_value: float = 0.0
## When true, multiple copies may stack on the same Nanobot.
@export var allow_multiple: bool = true
## Legacy / editor hint only. Runtime unlocks come from ResearchManager.
@export var unlocked: bool = false


## True when ResearchManager has unlocked this protein (fallback: unlocked flag).
func is_available() -> bool:
	if protein_id == &"":
		return false
	if GameManager != null:
		var research: ResearchManager = GameManager.get_research_manager()
		if research != null:
			return research.is_protein_unlocked(protein_id)
	return unlocked


func create_modifier(source_id: StringName) -> StatModifier:
	return StatModifier.make(stat_id, modifier_type, modifier_value, source_id)
