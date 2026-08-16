## Tracks which Nanobot type the player currently intends to place.
##
## Owns selection only — inventory counts live on ResourceManager, purchases on
## ShopManager, and placement on PlantManager.
## Legacy name: SeedSelectionManager ("seed" = owned Nanobot unit).
class_name SeedSelectionManager
extends Node

## Emitted whenever the selected Nanobot type changes. Null when cleared.
signal selection_changed(plant_data: PlantData)

var _selected_plant_data: PlantData = null


## Selects a Nanobot type if the player owns at least one unit of that type.
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


## Clears the current selection (e.g. after a successful placement).
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
