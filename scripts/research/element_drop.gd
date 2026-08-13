## One pathogen element drop entry (data-driven).
class_name ElementDrop
extends Resource

@export var element: ElementData
@export var amount: int = 1
## 0.0–1.0 probability that this drop is granted on death.
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0


func get_element_id() -> StringName:
	if element == null:
		return &""
	return element.element_id


func get_symbol() -> String:
	if element == null:
		return "?"
	if element.symbol != "":
		return element.symbol
	return String(element.element_id)
