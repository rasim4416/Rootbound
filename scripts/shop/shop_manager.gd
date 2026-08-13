## Scene-local shop backend.
##
## Converts Bio-Energy into Nanobot seeds or Organelle units via ShopItem entries.
class_name ShopManager
extends Node

signal purchase_completed(item: ShopItem)
signal purchase_failed(item: ShopItem)

@export var shop_items: Array[ShopItem] = []


func _ready() -> void:
	if _get_resources() == null:
		push_error("ShopManager: ResourceManager unavailable via GameManager.")


func can_purchase(item: ShopItem) -> bool:
	if item == null or not item.unlocked:
		return false
	var cost: int = item.get_effective_biomass_cost()
	if cost < 0:
		return false
	if item.is_nanobot():
		pass
	elif item.is_organelle():
		pass
	else:
		return false

	var resources: ResourceManager = _get_resources()
	if resources == null:
		return false
	return resources.can_afford_biomass(cost)


func purchase(item: ShopItem) -> bool:
	if not can_purchase(item):
		purchase_failed.emit(item)
		return false

	var resources: ResourceManager = _get_resources()
	if resources == null:
		purchase_failed.emit(item)
		return false

	var cost: int = item.get_effective_biomass_cost()
	if not resources.spend_biomass(cost):
		purchase_failed.emit(item)
		return false

	if item.is_nanobot():
		resources.add_seed(item.plant_data, 1)
	elif item.is_organelle():
		resources.add_organelle(item.organel_data, 1)
	else:
		resources.add_biomass(cost)
		purchase_failed.emit(item)
		return false

	purchase_completed.emit(item)
	return true


func get_shop_items() -> Array[ShopItem]:
	return shop_items.duplicate()


func _get_resources() -> ResourceManager:
	if GameManager == null:
		return null
	return GameManager.get_resource_manager()
