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

@export_group("Tree")
## Graph position in Research Lab / F4 designer.
@export var editor_position: Vector2 = Vector2.ZERO
## Parent research ids that must be unlocked first (A→B stores A on B).
@export var prerequisite_ids: Array[StringName] = []
## Display-only grouping for the designer list (not a gameplay gate).
@export var tier: int = 1
## Optional portrait override. Empty = ResearchPortraits.portrait_<id>.png
@export var icon: Texture2D


func cost_label() -> String:
	if costs.is_empty():
		return "Free"
	var parts: PackedStringArray = PackedStringArray()
	for cost: ResearchCost in costs:
		if cost == null or not cost.is_valid():
			continue
		var symbol: String = cost.element.symbol if cost.element != null else "?"
		parts.append("%s %d" % [symbol, cost.amount])
	if parts.is_empty():
		return "Free"
	return ", ".join(parts)


func resolve_icon() -> Texture2D:
	if icon != null:
		return icon
	return ResearchPortraits.get_portrait(research_id)
