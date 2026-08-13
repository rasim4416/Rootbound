## One entry in the Shop / Fabricator catalog.
##
## Supports Nanobot seeds and Organelle units. Bio-Energy is always the purchase currency.
class_name ShopItem
extends Resource

enum ItemKind {
	NANOBOT,
	ORGANELLE,
}

@export var item_kind: ItemKind = ItemKind.NANOBOT
## Plant granted as a seed when item_kind == NANOBOT.
@export var plant_data: PlantData
## Organelle granted as a unit when item_kind == ORGANELLE.
@export var organel_data: OrganelData
## Bio-Energy price for one unit.
@export var biomass_cost: int = 0
## Whether the player may buy this item (research can flip this later).
@export var unlocked: bool = true


func get_display_name() -> String:
	if item_kind == ItemKind.ORGANELLE and organel_data != null:
		return organel_data.display_name
	if plant_data != null:
		return plant_data.display_name
	return "Unknown"


func is_nanobot() -> bool:
	return item_kind == ItemKind.NANOBOT and plant_data != null


func is_organelle() -> bool:
	return item_kind == ItemKind.ORGANELLE and organel_data != null


## Bio-Energy price after permanent research modifiers (Generator discount, etc.).
func get_effective_biomass_cost() -> int:
	var cost: float = float(biomass_cost)
	if is_nanobot() and plant_data != null and plant_data.is_resource_generator():
		if GameManager != null:
			cost = GameManager.get_effective_stat(StatIds.GENERATOR_SHOP_COST, cost)
	return maxi(int(round(cost)), 0)
