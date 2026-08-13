## Static definition for the player's Core / Base.
##
## Create .tres files under data/core/. Runtime Core nodes receive CoreData
## rather than hard-coding HP values.
class_name CoreData
extends Resource

@export var core_id: StringName = &""
@export var display_name: String = ""
@export var max_health: float = 100.0
