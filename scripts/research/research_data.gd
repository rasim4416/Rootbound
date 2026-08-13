## Static Research Lab definition (structure unlocks, upgrades, proteins).
##
## Costs are paid in CHONS elements from ElementInventory — never Research Points.
## Permanent effects use StatModifier → PermanentProgressionManager.
class_name ResearchData
extends Resource

@export var research_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Element costs required to unlock (empty = free).
@export var costs: Array[ResearchCost] = []
## Starts unlocked without spending.
@export var unlocked_by_default: bool = false
## When false, research cannot be unlocked yet (placeholder branch hubs).
@export var unlockable: bool = true
## Optional protein granted/enabled by this research (Ribosome query).
@export var protein: ProteinData
## Permanent run-meta modifiers applied while this research is unlocked.
@export var permanent_modifiers: Array[StatModifier] = []
