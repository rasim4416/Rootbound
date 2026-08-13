## Tracks which Organelle type the player intends to place.
class_name OrganelSelectionManager
extends Node

signal selection_changed(organel_data: OrganelData)

var _selected: OrganelData = null


func select_organel(organel_data: OrganelData) -> bool:
	if organel_data == null or organel_data.organelle_id == &"":
		return false
	var resources: ResourceManager = _get_resources()
	if resources == null:
		return false
	if resources.get_organelle_count(organel_data) <= 0:
		return false
	_selected = organel_data
	selection_changed.emit(_selected)
	return true


func clear_selection() -> void:
	if _selected == null:
		return
	_selected = null
	selection_changed.emit(null)


func has_selection() -> bool:
	return _selected != null


func get_selected_organel_data() -> OrganelData:
	return _selected


func _get_resources() -> ResourceManager:
	if GameManager == null:
		return null
	return GameManager.get_resource_manager()
