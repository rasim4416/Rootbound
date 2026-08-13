## Permanent CHONS element stockpile (meta-progression).
##
## Lives under GameManager. Never reset by Game Over / RESTART / scene reload.
## Persist via SaveManager. Separate from ResourceManager (Bio-Energy / ATP).
class_name ElementInventory
extends Node

signal element_changed(element_id: StringName, new_amount: int)
signal inventory_changed

@export var debug_starting_elements: bool = false
@export var debug_starting_amount: int = 0

var _amounts: Dictionary = {} ## element_id → int


func _ready() -> void:
	_ensure_defaults()
	if debug_starting_elements and debug_starting_amount > 0:
		for element_id: StringName in ElementIds.ALL:
			_amounts[element_id] = debug_starting_amount
		inventory_changed.emit()
		for element_id: StringName in ElementIds.ALL:
			element_changed.emit(element_id, int(_amounts[element_id]))


func get_amount(element_id: StringName) -> int:
	if element_id == &"":
		return 0
	return int(_amounts.get(element_id, 0))


func add_element(element_id: StringName, amount: int) -> void:
	if element_id == &"" or amount <= 0:
		return
	_ensure_defaults()
	var new_amount: int = get_amount(element_id) + amount
	_amounts[element_id] = new_amount
	element_changed.emit(element_id, new_amount)
	inventory_changed.emit()


func can_afford(element_id: StringName, amount: int) -> bool:
	if amount < 0:
		return false
	return get_amount(element_id) >= amount


func spend_element(element_id: StringName, amount: int) -> bool:
	if amount < 0 or element_id == &"":
		return false
	if amount == 0:
		return true
	if not can_afford(element_id, amount):
		return false
	var new_amount: int = get_amount(element_id) - amount
	_amounts[element_id] = new_amount
	element_changed.emit(element_id, new_amount)
	inventory_changed.emit()
	return true


## Returns a copy: element_id → amount for all known CHONS elements.
func get_all_elements() -> Dictionary:
	_ensure_defaults()
	return _amounts.duplicate()


## Wipe all amounts to 0. Not called on RESTART — only for debug / new profile.
func reset_inventory() -> void:
	_amounts.clear()
	_ensure_defaults()
	inventory_changed.emit()
	for element_id: StringName in ElementIds.ALL:
		element_changed.emit(element_id, 0)


## Restore from save without emitting per-element spam; emits inventory_changed once.
func apply_saved_amounts(saved: Dictionary) -> void:
	_ensure_defaults()
	for element_id: StringName in ElementIds.ALL:
		var key: String = String(element_id)
		var value: int = 0
		if saved.has(key):
			value = maxi(int(saved[key]), 0)
		elif saved.has(element_id):
			value = maxi(int(saved[element_id]), 0)
		_amounts[element_id] = value
	inventory_changed.emit()
	for element_id: StringName in ElementIds.ALL:
		element_changed.emit(element_id, int(_amounts[element_id]))


func _ensure_defaults() -> void:
	for element_id: StringName in ElementIds.ALL:
		if not _amounts.has(element_id):
			_amounts[element_id] = 0
