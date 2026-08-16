## Turret target-selection modes and the research gate that unlocks them.
##
## NEAREST is always available. First / Last / Weakest / Strongest require the
## Targeting research to be unlocked in the Research Lab.
## Modes travel as int (Mode values) so they can be stored and passed freely.
class_name TargetingModes
extends RefCounted

enum Mode {
	NEAREST,
	FIRST,
	LAST,
	WEAKEST,
	STRONGEST,
}

## ResearchData ids that unlock every non-NEAREST mode. Both spellings are
## accepted so a designer-authored node keeps working after a rename.
const RESEARCH_IDS: Array[StringName] = [&"Targeting", &"targeting"]

## Display order used by the Nanobot info panel.
const ORDER: Array[int] = [
	Mode.NEAREST,
	Mode.FIRST,
	Mode.LAST,
	Mode.WEAKEST,
	Mode.STRONGEST,
]


static func label(mode: int) -> String:
	match mode:
		Mode.FIRST:
			return "First"
		Mode.LAST:
			return "Last"
		Mode.WEAKEST:
			return "Weakest"
		Mode.STRONGEST:
			return "Strongest"
		_:
			return "Nearest"


static func description(mode: int) -> String:
	match mode:
		Mode.FIRST:
			return "Pathogen closest to the Nucleus."
		Mode.LAST:
			return "Pathogen furthest from the Nucleus."
		Mode.WEAKEST:
			return "Lowest current HP in range."
		Mode.STRONGEST:
			return "Highest current HP in range."
		_:
			return "Closest pathogen to this Nanobot."


## NEAREST is free; every other mode needs the Targeting research.
static func requires_research(mode: int) -> bool:
	return mode != Mode.NEAREST


static func is_research_unlocked() -> bool:
	if GameManager == null:
		return false
	var research: ResearchManager = GameManager.get_research_manager()
	if research == null:
		return false
	for id: StringName in RESEARCH_IDS:
		if research.is_unlocked(id):
			return true
	return false


static func is_research_id(research_id: StringName) -> bool:
	return RESEARCH_IDS.has(research_id)


static func is_available(mode: int) -> bool:
	return not requires_research(mode) or is_research_unlocked()
