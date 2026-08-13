## One element line in a Research unlock cost.
class_name ResearchCost
extends Resource

@export var element: ElementData
@export var amount: int = 0


func get_element_id() -> StringName:
	if element == null:
		return &""
	return element.element_id


func is_valid() -> bool:
	return get_element_id() != &"" and amount > 0
