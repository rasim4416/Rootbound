## Static definition for a biological element (H/C/O/N/S).
class_name ElementData
extends Resource

@export var element_id: StringName = &""
@export var symbol: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Informational only — gameplay must not depend on this.
@export var atomic_number: int = 0
