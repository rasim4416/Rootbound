## Side panel for a selected research node. Shows name + effects on click.
## Purchase logic stays on ResearchManager.
class_name ResearchDetailPanel
extends PanelContainer

signal unlock_requested(node_id: StringName)
signal closed

@onready var _title: Label = %TitleLabel
@onready var _state: Label = %StateLabel
@onready var _description: Label = %DescriptionLabel
@onready var _effects: Label = %EffectsLabel
@onready var _costs: Label = %CostsLabel
@onready var _portrait: TextureRect = %PortraitTexture
@onready var _unlock_button: Button = %UnlockButton
@onready var _close_button: Button = %CloseButton

var _node_id: StringName = &""
var _parents_unlocked: bool = true


func _ready() -> void:
	visible = false
	_unlock_button.pressed.connect(_on_unlock_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	if GameManager != null:
		var research: ResearchManager = GameManager.get_research_manager()
		if research != null and not research.research_unlocked.is_connected(_on_research_unlocked):
			research.research_unlocked.connect(_on_research_unlocked)
		var inventory: ElementInventory = GameManager.get_element_inventory()
		if inventory != null and not inventory.inventory_changed.is_connected(_on_inventory_changed):
			inventory.inventory_changed.connect(_on_inventory_changed)


func show_research(node_id: StringName, parents_unlocked: bool = true) -> void:
	_node_id = node_id
	_parents_unlocked = parents_unlocked
	visible = true
	_refresh()


func hide_panel() -> void:
	_node_id = &""
	visible = false


func _on_unlock_pressed() -> void:
	if _node_id != &"":
		unlock_requested.emit(_node_id)


func _on_close_pressed() -> void:
	hide_panel()
	closed.emit()


func _on_research_unlocked(_id: StringName) -> void:
	if visible:
		_refresh()


func _on_inventory_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	if _node_id == &"":
		return
	var research: ResearchManager = null
	if GameManager != null:
		research = GameManager.get_research_manager()
	if research == null:
		_title.text = String(_node_id)
		_state.text = "ResearchManager unavailable"
		_description.text = ""
		if _effects != null:
			_effects.text = ""
		_costs.text = ""
		_unlock_button.disabled = true
		return

	var data: ResearchData = research.get_research(_node_id)
	if data == null:
		_title.text = String(_node_id)
		_state.text = "NO RESEARCH DATA"
		_description.text = "This node has no ResearchData entry yet."
		if _effects != null:
			_effects.text = "Effect: —"
		_costs.text = "Cost: —"
		_unlock_button.disabled = true
		_unlock_button.text = "Unavailable"
		return

	_title.text = data.display_name
	_description.text = data.description if data.description != "" else "No description."
	_set_portrait(_node_id)
	if _effects != null:
		_effects.text = _format_effects(data)

	if research.is_unlocked(_node_id):
		_state.text = "State: UNLOCKED"
		_unlock_button.text = "Unlocked"
		_unlock_button.disabled = true
	elif not data.unlockable:
		_state.text = "State: LOCKED (coming later)"
		_unlock_button.text = "Not Unlockable Yet"
		_unlock_button.disabled = true
	elif not _parents_unlocked:
		_state.text = "State: LOCKED (requires parent research)"
		_unlock_button.text = "Cannot Unlock"
		_unlock_button.disabled = true
	elif research.can_unlock(_node_id):
		_state.text = "State: AVAILABLE"
		_unlock_button.text = "Unlock"
		_unlock_button.disabled = false
	else:
		_state.text = "State: LOCKED"
		_unlock_button.text = "Cannot Unlock"
		_unlock_button.disabled = true

	_costs.text = _format_costs(data)


func _set_portrait(node_id: StringName) -> void:
	if _portrait == null:
		return
	var tex: Texture2D = ResearchPortraits.get_portrait(node_id)
	_portrait.texture = tex
	_portrait.visible = tex != null
	if tex == null:
		return
	var research: ResearchManager = GameManager.get_research_manager() if GameManager != null else null
	if research != null and research.is_unlocked(node_id):
		_portrait.modulate = Color(1.0, 1.0, 1.0, 1.0)
	elif research != null and research.can_unlock(node_id):
		_portrait.modulate = Color(0.9, 0.94, 1.0, 0.96)
	else:
		_portrait.modulate = Color(0.45, 0.5, 0.58, 0.85)


func _format_effects(data: ResearchData) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for mod: StatModifier in data.permanent_modifiers:
		if mod == null or mod.stat_id == &"":
			continue
		var stat_name: String = String(mod.stat_id).replace("_", " ").capitalize()
		if mod.modifier_type == StatModifier.ModifierType.MULTIPLICATIVE:
			parts.append("%s %+d%%" % [stat_name, int(round(mod.value * 100.0))])
		else:
			parts.append("%s %+g" % [stat_name, mod.value])
	if data.protein != null:
		var protein_name: String = data.protein.display_name
		if protein_name == "":
			protein_name = String(data.protein.protein_id)
		parts.append("Enables %s" % protein_name)
	if parts.is_empty():
		return "Effect: Structure unlock (no direct combat modifier)"
	return "Effect: " + ", ".join(parts)


func _format_costs(data: ResearchData) -> String:
	if data.costs.is_empty():
		return "Cost: Free"
	var parts: PackedStringArray = PackedStringArray()
	for cost: ResearchCost in data.costs:
		if cost == null or not cost.is_valid():
			continue
		var symbol: String = cost.element.symbol if cost.element != null else "?"
		parts.append("%s ×%d" % [symbol, cost.amount])
	if parts.is_empty():
		return "Cost: Free"
	return "Cost: " + ", ".join(parts)
