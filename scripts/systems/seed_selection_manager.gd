## Tracks which seed type the player currently intends to plant.
##
## Owns selection only — inventory counts live on ResourceManager, purchases on
## ShopManager, and placement on PlantManager.
class_name SeedSelectionManager
extends Node

## Emitted whenever the selected seed type changes. Null when cleared.
signal selection_changed(plant_data: PlantData)

var _selected_plant_data: PlantData = null


## Selects a seed type if the player owns at least one of that plant's seeds.
func select_seed(plant_data: PlantData) -> bool:
	if plant_data == null or plant_data.plant_id == &"":
		return false

	var resources: ResourceManager = _get_resources()
	if resources == null:
		return false
	if resources.get_seed_count(plant_data) <= 0:
		return false

	_selected_plant_data = plant_data
	selection_changed.emit(_selected_plant_data)
	return true


## Clears the current selection (e.g. after a successful plant).
func clear_selection() -> void:
	if _selected_plant_data == null:
		return
	_selected_plant_data = null
	selection_changed.emit(null)


func has_selection() -> bool:
	return _selected_plant_data != null


func get_selected_plant_data() -> PlantData:
	return _selected_plant_data


func _get_resources() -> ResourceManager:
	if GameManager == null:
		return null
	return GameManager.get_resource_manager()
