## Right-side Fabricator HUD with draggable unit icons and open/close toggle.
class_name ShopUI
extends Control

@export var shop_manager: ShopManager
@export var seed_selection: SeedSelectionManager
@export var organel_selection: OrganelSelectionManager
@export var plant_manager: PlantManager
@export var organel_manager: OrganelManager
@export var placement_drag: PlacementDragController

const _TOOLTIP_SCENE: PackedScene = preload("res://scenes/ui/shop_item_tooltip.tscn")

@onready var _shop_toggle_button: Button = $ShopToggleButton
@onready var _shop_panel: PanelContainer = $ShopPanel
@onready var _close_button: Button = $ShopPanel/Margin/VBox/CloseButton
@onready var _biomass_label: Label = $ShopPanel/Margin/VBox/BiomassLabel
@onready var _seeds_label: Label = $ShopPanel/Margin/VBox/SeedsLabel
@onready var _feedback_label: Label = $ShopPanel/Margin/VBox/FeedbackLabel
@onready var _nanobot_grid: GridContainer = $ShopPanel/Margin/VBox/NanobotGrid
@onready var _organel_grid: GridContainer = $ShopPanel/Margin/VBox/OrganelGrid

var _item_cards: Dictionary = {}
var _tooltip: ShopItemTooltip = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shop_panel != null:
		_shop_panel.visible = false
		_shop_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if _shop_toggle_button != null:
		_shop_toggle_button.visible = true
		_shop_toggle_button.pressed.connect(_on_shop_toggle_pressed)
	if _close_button != null:
		_close_button.pressed.connect(_on_close_pressed)
	_feedback_label.text = ""

	if shop_manager == null:
		push_error("ShopUI: shop_manager is not assigned.")
		return

	_tooltip = _TOOLTIP_SCENE.instantiate() as ShopItemTooltip
	if _tooltip != null:
		add_child(_tooltip)

	shop_manager.purchase_completed.connect(_on_purchase_completed)
	shop_manager.purchase_failed.connect(_on_purchase_failed)

	var resources: ResourceManager = _get_resources()
	if resources != null:
		resources.biomass_changed.connect(_on_biomass_changed)
		resources.seeds_changed.connect(_on_inventory_changed)
		resources.seed_count_changed.connect(_on_typed_inventory_changed)
		resources.organelles_changed.connect(_on_inventory_changed)
		resources.organelle_count_changed.connect(_on_typed_inventory_changed)

	_refresh_resource_labels()
	_rebuild_item_cards()
	_refresh_toggle_visibility()


func show_tooltip_for_card(card: ShopItemCard, item: ShopItem) -> void:
	if _tooltip == null or item == null or card == null:
		return
	if not is_panel_open():
		return
	if placement_drag != null and placement_drag.is_dragging():
		return
	_tooltip.show_for_item(item, card)


func hide_tooltip() -> void:
	if _tooltip != null:
		_tooltip.hide_tooltip()


func show_feedback(text: String) -> void:
	if _feedback_label != null:
		_feedback_label.text = text


func refresh_after_drag() -> void:
	_feedback_label.text = ""
	_refresh_resource_labels()
	_refresh_card_states()


func toggle_panel() -> void:
	if is_panel_open():
		close_panel()
	else:
		open_panel()


func open_panel_for_cell(_cell: Vector2i) -> void:
	open_panel()


func open_panel() -> void:
	if _shop_panel != null:
		_shop_panel.visible = true
	hide_tooltip()
	_feedback_label.text = ""
	_refresh_resource_labels()
	_refresh_card_states()
	_refresh_toggle_visibility()


func close_panel() -> void:
	if placement_drag != null and placement_drag.is_dragging():
		return
	hide_tooltip()
	_feedback_label.text = ""
	if _shop_panel != null:
		_shop_panel.visible = false
	_refresh_toggle_visibility()


func is_panel_open() -> bool:
	return _shop_panel != null and _shop_panel.visible


func _on_shop_toggle_pressed() -> void:
	open_panel()


func _on_close_pressed() -> void:
	close_panel()


func _refresh_toggle_visibility() -> void:
	if _shop_toggle_button == null:
		return
	_shop_toggle_button.visible = not is_panel_open()


func _on_purchase_completed(_item: ShopItem) -> void:
	_refresh_resource_labels()
	_refresh_card_states()


func _on_purchase_failed(_item: ShopItem) -> void:
	show_feedback("Not enough Bio-Energy")
	_refresh_resource_labels()
	_refresh_card_states()


func _on_biomass_changed(_new_amount: int) -> void:
	_refresh_resource_labels()
	_refresh_card_states()


func _on_inventory_changed(_new_amount: int) -> void:
	_refresh_resource_labels()
	_refresh_card_states()


func _on_typed_inventory_changed(_id: StringName, _new_amount: int) -> void:
	_refresh_card_states()


func _rebuild_item_cards() -> void:
	_item_cards.clear()
	for child: Node in _nanobot_grid.get_children():
		child.queue_free()
	for child: Node in _organel_grid.get_children():
		child.queue_free()

	if shop_manager == null:
		return

	for item: ShopItem in shop_manager.shop_items:
		if item == null:
			continue
		var card := ShopItemCard.new()
		card.setup(item)
		card.drag_requested.connect(_on_card_drag_requested)
		if item.is_nanobot():
			_nanobot_grid.add_child(card)
		elif item.is_organelle():
			_organel_grid.add_child(card)
		else:
			card.queue_free()
			continue
		_item_cards[item] = card

	_refresh_card_states()


func _on_card_drag_requested(item: ShopItem) -> void:
	hide_tooltip()
	if placement_drag != null:
		placement_drag.begin_drag(item)


func _refresh_resource_labels() -> void:
	var resources: ResourceManager = _get_resources()
	var biomass: int = resources.biomass if resources != null else 0
	var seeds: int = resources.seeds if resources != null else 0
	var organelle_units: int = resources.organelles if resources != null else 0
	_biomass_label.text = "Bio-Energy: %d" % biomass
	_seeds_label.text = "Nanobot Units: %d | Organelle Units: %d" % [seeds, organelle_units]


func _refresh_card_states() -> void:
	if shop_manager == null:
		return
	var resources: ResourceManager = _get_resources()
	for item: ShopItem in _item_cards.keys():
		var card: ShopItemCard = _item_cards[item] as ShopItemCard
		if card == null or item == null:
			continue
		card.set_can_afford(shop_manager.can_purchase(item))
		card.refresh_cost()
		var owned: int = 0
		if resources != null:
			if item.is_nanobot():
				owned = resources.get_seed_count(item.plant_data)
			elif item.is_organelle():
				owned = resources.get_organelle_count(item.organel_data)
		card.refresh_owned(owned)


func _get_resources() -> ResourceManager:
	if GameManager == null:
		return null
	return GameManager.get_resource_manager()
