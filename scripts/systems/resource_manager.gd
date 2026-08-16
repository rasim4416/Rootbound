## Central store for player progression resources.
##
## Bio-Energy (internal field: biomass) buys Nanobots/Organelles.
## ATP is a separate Cell Energy pool produced by Mitochondria.
## Nanobot units and organelle units are typed inventories
## (internal API still uses "seeds" for nanobot units).
class_name ResourceManager
extends Node

signal biomass_changed(new_amount: int)
signal atp_changed(new_amount: int)
## Total Nanobot unit count across all types (sum of typed inventory).
signal seeds_changed(new_amount: int)
## Fired when one Nanobot type's unit count changes.
signal seed_count_changed(plant_id: StringName, new_amount: int)
signal organelles_changed(new_amount: int)
signal organelle_count_changed(organelle_id: StringName, new_amount: int)

var _biomass: int = 0
var _atp: int = 0
## Sum of all entries in _seed_inventory. Kept for backwards-compatible HUD.
var _seeds: int = 0
var _organelles: int = 0
## plant_id (StringName) → owned Nanobot unit count.
var _seed_inventory: Dictionary = {}
## organelle_id (StringName) → owned unit count.
var _organelle_inventory: Dictionary = {}


var biomass: int:
	get:
		return _biomass
	set(value):
		var clamped: int = maxi(value, 0)
		if _biomass == clamped:
			return
		_biomass = clamped
		biomass_changed.emit(_biomass)


var atp: int:
	get:
		return _atp
	set(value):
		var clamped: int = maxi(value, 0)
		if _atp == clamped:
			return
		_atp = clamped
		atp_changed.emit(_atp)


## Total Nanobot units owned across every type.
var seeds: int:
	get:
		return _seeds
	set(value):
		var clamped: int = maxi(value, 0)
		if _seeds == clamped:
			return
		_seeds = clamped
		seeds_changed.emit(_seeds)


var organelles: int:
	get:
		return _organelles
	set(value):
		var clamped: int = maxi(value, 0)
		if _organelles == clamped:
			return
		_organelles = clamped
		organelles_changed.emit(_organelles)


func can_afford_biomass(amount: int) -> bool:
	return amount >= 0 and _biomass >= amount


func spend_biomass(amount: int) -> bool:
	if not can_afford_biomass(amount):
		return false
	biomass = _biomass - amount
	return true


func add_biomass(amount: int) -> void:
	if amount <= 0:
		return
	biomass = _biomass + amount


func can_afford_atp(amount: int) -> bool:
	return amount >= 0 and _atp >= amount


func spend_atp(amount: int) -> bool:
	if not can_afford_atp(amount):
		return false
	atp = _atp - amount
	return true


func add_atp(amount: int) -> void:
	if amount <= 0:
		return
	atp = _atp + amount


func get_seed_count(plant_data: PlantData) -> int:
	var plant_id: StringName = _plant_id_of(plant_data)
	if plant_id == &"":
		return 0
	return int(_seed_inventory.get(plant_id, 0))


func add_seed(plant_data: PlantData, amount: int = 1) -> void:
	if amount <= 0:
		return
	var plant_id: StringName = _plant_id_of(plant_data)
	if plant_id == &"":
		push_warning("ResourceManager.add_seed: plant_data missing plant_id.")
		return

	var new_count: int = get_seed_count(plant_data) + amount
	_seed_inventory[plant_id] = new_count
	_sync_total_seeds()
	seed_count_changed.emit(plant_id, new_count)


func spend_seed(plant_data: PlantData) -> bool:
	var plant_id: StringName = _plant_id_of(plant_data)
	if plant_id == &"":
		return false

	var current: int = get_seed_count(plant_data)
	if current <= 0:
		return false

	var new_count: int = current - 1
	if new_count <= 0:
		_seed_inventory.erase(plant_id)
	else:
		_seed_inventory[plant_id] = new_count

	_sync_total_seeds()
	seed_count_changed.emit(plant_id, new_count)
	return true


func get_organelle_count(organel_data: OrganelData) -> int:
	var organelle_id: StringName = _organelle_id_of(organel_data)
	if organelle_id == &"":
		return 0
	return int(_organelle_inventory.get(organelle_id, 0))


func add_organelle(organel_data: OrganelData, amount: int = 1) -> void:
	if amount <= 0:
		return
	var organelle_id: StringName = _organelle_id_of(organel_data)
	if organelle_id == &"":
		push_warning("ResourceManager.add_organelle: missing organelle_id.")
		return
	var new_count: int = get_organelle_count(organel_data) + amount
	_organelle_inventory[organelle_id] = new_count
	_sync_total_organelles()
	organelle_count_changed.emit(organelle_id, new_count)


func spend_organelle(organel_data: OrganelData) -> bool:
	var organelle_id: StringName = _organelle_id_of(organel_data)
	if organelle_id == &"":
		return false
	var current: int = get_organelle_count(organel_data)
	if current <= 0:
		return false
	var new_count: int = current - 1
	if new_count <= 0:
		_organelle_inventory.erase(organelle_id)
	else:
		_organelle_inventory[organelle_id] = new_count
	_sync_total_organelles()
	organelle_count_changed.emit(organelle_id, new_count)
	return true


## @deprecated Prefer add_seed(plant_data). Untyped pool adds are unsupported.
func add_seeds(amount: int) -> void:
	push_warning("ResourceManager.add_seeds is deprecated; use add_seed(plant_data).")
	if amount <= 0:
		return
	seeds = _seeds + amount


## @deprecated Prefer spend_seed(plant_data). Untyped spends are unsupported.
func spend_seeds(amount: int) -> bool:
	push_warning("ResourceManager.spend_seeds is deprecated; use spend_seed(plant_data).")
	if amount < 0 or _seeds < amount:
		return false
	seeds = _seeds - amount
	return true


func _plant_id_of(plant_data: PlantData) -> StringName:
	if plant_data == null:
		return &""
	return plant_data.plant_id


func _organelle_id_of(organel_data: OrganelData) -> StringName:
	if organel_data == null:
		return &""
	return organel_data.organelle_id


func _sync_total_seeds() -> void:
	var total: int = 0
	for key: Variant in _seed_inventory.keys():
		total += int(_seed_inventory[key])
	seeds = total


func _sync_total_organelles() -> void:
	var total: int = 0
	for key: Variant in _organelle_inventory.keys():
		total += int(_organelle_inventory[key])
	organelles = total


## Clears inventories and restores starter Bio-Energy / ATP for a fresh run.
func reset_run(starting_biomass: int = 100, starting_atp: int = 0) -> void:
	_seed_inventory.clear()
	_organelle_inventory.clear()
	_seeds = 0
	_organelles = 0
	seeds_changed.emit(_seeds)
	organelles_changed.emit(_organelles)
	_biomass = maxi(starting_biomass, 0)
	biomass_changed.emit(_biomass)
	_atp = maxi(starting_atp, 0)
	atp_changed.emit(_atp)
