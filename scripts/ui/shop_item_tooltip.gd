## Floating description popup for Fabricator shop item cards.
class_name ShopItemTooltip
extends PanelContainer

@onready var _label: Label = $Margin/Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _label != null:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func show_for_item(item: ShopItem, anchor: Control) -> void:
	if item == null or anchor == null:
		hide_tooltip()
		return
	if _label != null:
		_label.text = _build_text(item)
	visible = true
	call_deferred("_position_near", anchor)


func hide_tooltip() -> void:
	visible = false


func _position_near(anchor: Control) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	var anchor_rect: Rect2 = anchor.get_global_rect()
	var viewport_size: Vector2 = get_viewport_rect().size
	size = get_combined_minimum_size()
	var pos: Vector2 = Vector2(
		anchor_rect.position.x - size.x - 12.0,
		anchor_rect.position.y
	)
	pos.x = maxf(8.0, pos.x)
	pos.y = clampf(pos.y, 8.0, viewport_size.y - size.y - 8.0)
	global_position = pos


func _build_text(item: ShopItem) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(item.get_display_name())
	lines.append("Cost: %d Bio-Energy" % item.get_effective_biomass_cost())
	var desc: String = _get_description(item)
	if desc != "":
		lines.append(desc)
	var stat_line: String = _get_stat_line(item)
	if stat_line != "":
		lines.append(stat_line)
	return "\n".join(lines)


func _get_description(item: ShopItem) -> String:
	if item.is_nanobot() and item.plant_data != null:
		return item.plant_data.description.strip_edges()
	if item.is_organelle() and item.organel_data != null:
		return item.organel_data.description.strip_edges()
	return ""


func _get_stat_line(item: ShopItem) -> String:
	if item.is_nanobot() and item.plant_data != null:
		var data: PlantData = item.plant_data
		if data.is_resource_generator():
			return "Produces %d Bio-Energy every %.0fs" % [
				data.bio_energy_production_amount,
				data.bio_energy_production_interval,
			]
		if data.damage > 0.0:
			return "Damage: %.0f | Range: %.0f" % [data.damage, data.attack_range]
		if data.support_attack_speed_bonus > 0.0:
			return "Support range: %.0f" % data.support_range
	if item.is_organelle() and item.organel_data != null:
		var org: OrganelData = item.organel_data
		if org.atp_per_second > 0.0:
			return "ATP: %.1f/s" % org.atp_per_second
		if org.protein != null:
			return "Synthesizes proteins"
	return ""
