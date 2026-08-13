## Draggable icon card for one Fabricator catalog entry.
class_name ShopItemCard
extends PanelContainer

signal drag_requested(item: ShopItem)

const DRAG_THRESHOLD: float = 8.0

var shop_item: ShopItem = null

var _icon: TextureRect
var _name_label: Label
var _cost_label: Label
var _owned_label: Label
var _press_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _can_afford: bool = true


func setup(item: ShopItem) -> void:
	shop_item = item
	custom_minimum_size = Vector2(88, 108)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.22, 0.16, 0.92)
	panel_style.border_color = Color(0.42, 0.62, 0.38, 0.9)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(56, 56)
	_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture = _resolve_texture(item)
	vbox.add_child(_icon)

	_name_label = Label.new()
	_name_label.text = item.get_display_name()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_name_label)

	_cost_label = Label.new()
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_cost_label)

	_owned_label = Label.new()
	_owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_owned_label.add_theme_font_size_override("font_size", 10)
	_owned_label.add_theme_color_override("font_color", Color(0.65, 0.82, 0.68, 1))
	vbox.add_child(_owned_label)

	_refresh_cost()
	_refresh_owned(0)


func set_can_afford(can_afford: bool) -> void:
	_can_afford = can_afford
	modulate = Color(1, 1, 1, 1) if can_afford else Color(0.65, 0.65, 0.65, 0.85)


func refresh_owned(count: int) -> void:
	_refresh_owned(count)


func refresh_cost() -> void:
	_refresh_cost()


func _refresh_cost() -> void:
	if _cost_label == null or shop_item == null:
		return
	_cost_label.text = "%d BE" % shop_item.get_effective_biomass_cost()


func _refresh_owned(count: int) -> void:
	if _owned_label == null:
		return
	if count > 0:
		_owned_label.text = "Owned: %d" % count
		_owned_label.visible = true
	else:
		_owned_label.visible = false


func _resolve_texture(item: ShopItem) -> Texture2D:
	if item.is_nanobot() and item.plant_data != null:
		return UnitGameplaySprites.get_plant_sprite(item.plant_data.plant_id)
	if item.is_organelle() and item.organel_data != null:
		return UnitGameplaySprites.get_organelle_sprite(item.organel_data.organelle_id)
	return null


func _gui_input(event: InputEvent) -> void:
	if shop_item == null or not shop_item.unlocked:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_press_pos = mouse_event.global_position
				_dragging = false
			else:
				_dragging = false
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _dragging:
			return
		var motion := event as InputEventMouseMotion
		if motion.global_position.distance_to(_press_pos) >= DRAG_THRESHOLD:
			_dragging = true
			drag_requested.emit(shop_item)
			accept_event()


func _on_mouse_entered() -> void:
	if shop_item == null:
		return
	var shop_ui := _find_shop_ui()
	if shop_ui != null:
		shop_ui.show_tooltip_for_card(self, shop_item)


func _on_mouse_exited() -> void:
	var shop_ui := _find_shop_ui()
	if shop_ui != null:
		shop_ui.hide_tooltip()


func _find_shop_ui() -> ShopUI:
	var node: Node = self
	while node != null:
		if node is ShopUI:
			return node as ShopUI
		node = node.get_parent()
	return null
