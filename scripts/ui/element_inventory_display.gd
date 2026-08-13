## Reusable CHONS element totals display (meta materials, not run resources).
class_name ElementInventoryDisplay
extends VBoxContainer

const _SYMBOLS: Dictionary = {
	ElementIds.HYDROGEN: "H",
	ElementIds.CARBON: "C",
	ElementIds.OXYGEN: "O",
	ElementIds.NITROGEN: "N",
	ElementIds.SULFUR: "S",
}

@export var show_header: bool = true
@export var header_text: String = "META MATERIALS"
@export var compact: bool = true

var _header: Label = null
var _labels: Dictionary = {} ## element_id → Label


func _ready() -> void:
	_build_ui()
	_bind_inventory()
	_refresh_all()


func _build_ui() -> void:
	for child: Node in get_children():
		child.queue_free()
	_labels.clear()

	add_theme_constant_override("separation", 2)

	if show_header:
		_header = Label.new()
		_header.text = header_text
		_header.add_theme_font_size_override("font_size", 14)
		_header.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95, 0.95))
		add_child(_header)

	for element_id: StringName in ElementIds.ALL:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 13 if compact else 16)
		label.add_theme_color_override("font_color", Color(0.70, 0.78, 0.92, 0.9))
		add_child(label)
		_labels[element_id] = label


func _bind_inventory() -> void:
	var inventory: ElementInventory = _get_inventory()
	if inventory == null:
		return
	if not inventory.element_changed.is_connected(_on_element_changed):
		inventory.element_changed.connect(_on_element_changed)
	if not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)


func _on_element_changed(element_id: StringName, new_amount: int) -> void:
	_set_label(element_id, new_amount)


func _on_inventory_changed() -> void:
	_refresh_all()


func _refresh_all() -> void:
	var inventory: ElementInventory = _get_inventory()
	for element_id: StringName in ElementIds.ALL:
		var amount: int = inventory.get_amount(element_id) if inventory != null else 0
		_set_label(element_id, amount)


func _set_label(element_id: StringName, amount: int) -> void:
	var label: Label = _labels.get(element_id, null) as Label
	if label == null:
		return
	var symbol: String = String(_SYMBOLS.get(element_id, element_id))
	if compact:
		label.text = "%s  %d" % [symbol, amount]
	else:
		label.text = "%s (%s): %d" % [symbol, element_id, amount]


func _get_inventory() -> ElementInventory:
	if GameManager == null:
		return null
	return GameManager.get_element_inventory()
