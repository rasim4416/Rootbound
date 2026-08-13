## Right-side Fabricator panel. Opens when the player clicks an empty grid cell.
## Buy spends Bio-Energy and places the unit directly onto that target cell.
class_name ShopUI
extends Control

@export var shop_manager: ShopManager
@export var seed_selection: SeedSelectionManager
@export var organel_selection: OrganelSelectionManager
@export var plant_manager: PlantManager
@export var organel_manager: OrganelManager

@onready var _shop_button: Button = $ShopButton
@onready var _shop_panel: PanelContainer = $ShopPanel
@onready var _biomass_label: Label = $ShopPanel/Margin/VBox/BiomassLabel
@onready var _seeds_label: Label = $ShopPanel/Margin/VBox/SeedsLabel
@onready var _feedback_label: Label = $ShopPanel/Margin/VBox/FeedbackLabel
@onready var _item_list: VBoxContainer = $ShopPanel/Margin/VBox/ItemScroll/ItemList
@onready var _close_button: Button = $ShopPanel/Margin/VBox/CloseButton

var _buy_buttons: Dictionary = {}
var _select_buttons: Dictionary = {}
var _target_cell: Vector2i = Vector2i.ZERO
var _has_target_cell: bool = false
## Skip auto-select when Buy already placed onto the target cell.
var _suppress_purchase_auto_select: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_panel.visible = false
	_feedback_label.text = ""
	if _shop_button != null:
		_shop_button.visible = false
		_shop_button.pressed.connect(_on_shop_button_pressed)
	_close_button.pressed.connect(_on_close_pressed)

	if shop_manager == null:
		push_error("ShopUI: shop_manager is not assigned.")
		return

	shop_manager.purchase_completed.connect(_on_purchase_completed)
	shop_manager.purchase_failed.connect(_on_purchase_failed)

	if seed_selection != null:
		seed_selection.selection_changed.connect(_on_seed_selection_changed)
	if organel_selection != null:
		organel_selection.selection_changed.connect(_on_organel_selection_changed)

	var resources: ResourceManager = _get_resources()
	if resources != null:
		resources.biomass_changed.connect(_on_biomass_changed)
		resources.seeds_changed.connect(_on_inventory_changed)
		resources.seed_count_changed.connect(_on_typed_inventory_changed)
		resources.organelles_changed.connect(_on_inventory_changed)
		resources.organelle_count_changed.connect(_on_typed_inventory_changed)

	_refresh_resource_labels()
	_rebuild_item_list()


## Opens the right-side Fabricator for a specific empty grid cell.
func open_panel_for_cell(cell: Vector2i) -> void:
	_target_cell = cell
	_has_target_cell = true
	_shop_panel.visible = true
	_feedback_label.text = "Place at cell (%d, %d)" % [cell.x, cell.y]
	_refresh_resource_labels()
	_refresh_owned_counts()
	_refresh_buy_states()
	_refresh_select_states()


## Opens without a placement target (legacy / fallback).
func open_panel() -> void:
	_has_target_cell = false
	_shop_panel.visible = true
	_feedback_label.text = ""
	_refresh_resource_labels()
	_refresh_owned_counts()
	_refresh_buy_states()
	_refresh_select_states()


func close_panel() -> void:
	_shop_panel.visible = false
	_feedback_label.text = ""
	_has_target_cell = false
	_suppress_purchase_auto_select = false


func is_panel_open() -> bool:
	return _shop_panel != null and _shop_panel.visible


func _on_shop_button_pressed() -> void:
	if _shop_panel.visible:
		close_panel()
	else:
		open_panel()


func _on_close_pressed() -> void:
	close_panel()


func _on_buy_pressed(item: ShopItem) -> void:
	if shop_manager == null or item == null:
		return
	_feedback_label.text = ""

	# Buy + place onto the cell that opened this panel.
	if _has_target_cell:
		if not shop_manager.can_purchase(item):
			_feedback_label.text = "Not enough Bio-Energy"
			return
		_suppress_purchase_auto_select = true
		if not shop_manager.purchase(item):
			_suppress_purchase_auto_select = false
			return
		var placed: bool = _place_purchased_item_at_target(item)
		_suppress_purchase_auto_select = false
		_refresh_resource_labels()
		_refresh_owned_counts()
		_refresh_buy_states()
		_refresh_select_states()
		if placed:
			close_panel()
		else:
			_feedback_label.text = "Bought — cell unavailable, unit kept in inventory"
		return

	shop_manager.purchase(item)


func _place_purchased_item_at_target(item: ShopItem) -> bool:
	if not _has_target_cell or item == null:
		return false
	if item.is_nanobot():
		if plant_manager == null or item.plant_data == null:
			return false
		return plant_manager.place_owned_at_cell(_target_cell, item.plant_data)
	if item.is_organelle():
		if organel_manager == null or item.organel_data == null:
			return false
		return organel_manager.place_owned_at_cell(_target_cell, item.organel_data)
	return false


func _on_select_pressed(item: ShopItem) -> void:
	if item == null:
		return
	# Select + place immediately when a target cell is set.
	if _has_target_cell:
		var placed: bool = false
		if item.is_nanobot() and plant_manager != null and item.plant_data != null:
			placed = plant_manager.place_owned_at_cell(_target_cell, item.plant_data)
		elif item.is_organelle() and organel_manager != null and item.organel_data != null:
			placed = organel_manager.place_owned_at_cell(_target_cell, item.organel_data)
		_refresh_resource_labels()
		_refresh_owned_counts()
		_refresh_select_states()
		if placed:
			close_panel()
		else:
			_feedback_label.text = "No units owned or cell unavailable"
		return

	if item.is_nanobot():
		if seed_selection == null:
			return
		if organel_selection != null:
			organel_selection.clear_selection()
		if seed_selection.select_seed(item.plant_data):
			_feedback_label.text = "Selected: %s — click an empty cell" % item.get_display_name()
		else:
			_feedback_label.text = "No %s units owned" % item.get_display_name()
	elif item.is_organelle():
		if organel_selection == null:
			return
		if seed_selection != null:
			seed_selection.clear_selection()
		if organel_selection.select_organel(item.organel_data):
			_feedback_label.text = "Selected: %s — click an empty cell" % item.get_display_name()
		else:
			_feedback_label.text = "No %s units owned" % item.get_display_name()
	_refresh_select_states()


func _on_purchase_completed(item: ShopItem) -> void:
	_feedback_label.text = ""
	_refresh_resource_labels()
	_refresh_owned_counts()
	_refresh_buy_states()
	if _suppress_purchase_auto_select:
		_refresh_select_states()
		return
	if item != null:
		if item.is_nanobot() and seed_selection != null:
			if organel_selection != null:
				organel_selection.clear_selection()
			seed_selection.select_seed(item.plant_data)
			_feedback_label.text = "Selected: %s — click an empty cell" % item.get_display_name()
		elif item.is_organelle() and organel_selection != null:
			if seed_selection != null:
				seed_selection.clear_selection()
			organel_selection.select_organel(item.organel_data)
			_feedback_label.text = "Selected: %s — click an empty cell" % item.get_display_name()
	_refresh_select_states()


func _on_purchase_failed(_item: ShopItem) -> void:
	_feedback_label.text = "Not enough Bio-Energy"
	_refresh_resource_labels()
	_refresh_buy_states()


func _on_biomass_changed(_new_amount: int) -> void:
	_refresh_resource_labels()
	_refresh_buy_states()


func _on_inventory_changed(_new_amount: int) -> void:
	_refresh_resource_labels()
	_refresh_owned_counts()
	_refresh_select_states()


func _on_typed_inventory_changed(_id: StringName, _new_amount: int) -> void:
	_refresh_owned_counts()
	_refresh_select_states()


func _on_seed_selection_changed(_plant_data: PlantData) -> void:
	_refresh_select_states()


func _on_organel_selection_changed(_organel_data: OrganelData) -> void:
	_refresh_select_states()


func _rebuild_item_list() -> void:
	_buy_buttons.clear()
	_select_buttons.clear()
	for child: Node in _item_list.get_children():
		child.queue_free()

	if shop_manager == null:
		return

	_item_list.add_child(_make_section_label("NANOBOTS"))
	for item: ShopItem in shop_manager.shop_items:
		if item != null and item.is_nanobot():
			_item_list.add_child(_create_item_row(item))

	_item_list.add_child(_make_section_label("ORGANELLES"))
	for item: ShopItem in shop_manager.shop_items:
		if item != null and item.is_organelle():
			_item_list.add_child(_create_item_row(item))

	_refresh_buy_states()
	_refresh_select_states()


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	return label


func _create_item_row(item: ShopItem) -> Control:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("shop_item", item)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	row.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = item.get_display_name()
	info.add_child(name_label)

	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "Cost: %d Bio-Energy" % item.get_effective_biomass_cost()
	info.add_child(cost_label)

	var owned := Label.new()
	owned.name = "OwnedLabel"
	owned.text = _format_owned(item)
	info.add_child(owned)

	var select_button := Button.new()
	select_button.text = "Select"
	select_button.pressed.connect(_on_select_pressed.bind(item))
	hbox.add_child(select_button)
	_select_buttons[item] = select_button

	var buy_button := Button.new()
	buy_button.text = "Buy"
	buy_button.disabled = not item.unlocked
	buy_button.pressed.connect(_on_buy_pressed.bind(item))
	hbox.add_child(buy_button)
	_buy_buttons[item] = buy_button

	return row


func _refresh_resource_labels() -> void:
	var resources: ResourceManager = _get_resources()
	var biomass: int = resources.biomass if resources != null else 0
	var seeds: int = resources.seeds if resources != null else 0
	var organelle_units: int = resources.organelles if resources != null else 0
	_biomass_label.text = "Bio-Energy: %d" % biomass
	_seeds_label.text = "Nanobot Units: %d | Organelle Units: %d" % [seeds, organelle_units]


func _refresh_owned_counts() -> void:
	for row: Node in _item_list.get_children():
		var item: ShopItem = row.get_meta("shop_item", null) as ShopItem
		var label := row.find_child("OwnedLabel", true, false) as Label
		if label != null and item != null:
			label.text = _format_owned(item)


func _refresh_buy_states() -> void:
	if shop_manager == null:
		return
	for item: ShopItem in _buy_buttons.keys():
		var button: Button = _buy_buttons[item] as Button
		if button == null or item == null:
			continue
		button.disabled = not shop_manager.can_purchase(item)


func _refresh_select_states() -> void:
	var resources: ResourceManager = _get_resources()
	var selected_plant: PlantData = null
	var selected_organel: OrganelData = null
	if seed_selection != null:
		selected_plant = seed_selection.get_selected_plant_data()
	if organel_selection != null:
		selected_organel = organel_selection.get_selected_organel_data()

	for item: ShopItem in _select_buttons.keys():
		var button: Button = _select_buttons[item] as Button
		if button == null or item == null:
			continue

		var owned: int = 0
		var is_selected: bool = false
		if item.is_nanobot():
			owned = resources.get_seed_count(item.plant_data) if resources != null else 0
			is_selected = (
				selected_plant != null
				and selected_plant.plant_id == item.plant_data.plant_id
			)
		elif item.is_organelle():
			owned = resources.get_organelle_count(item.organel_data) if resources != null else 0
			is_selected = (
				selected_organel != null
				and selected_organel.organelle_id == item.organel_data.organelle_id
			)

		button.disabled = owned <= 0
		button.text = "Place" if _has_target_cell else ("Selected" if is_selected else "Select")


func _format_owned(item: ShopItem) -> String:
	var resources: ResourceManager = _get_resources()
	if resources == null:
		return "Units owned: 0"
	if item.is_nanobot():
		return "Units owned: %d" % resources.get_seed_count(item.plant_data)
	if item.is_organelle():
		return "Units owned: %d" % resources.get_organelle_count(item.organel_data)
	return "Units owned: 0"


func _get_resources() -> ResourceManager:
	if GameManager == null:
		return null
	return GameManager.get_resource_manager()
