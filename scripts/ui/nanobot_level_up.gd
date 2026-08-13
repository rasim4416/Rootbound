## Optional Nanobot level-up choice panel (does not pause gameplay).
class_name NanobotLevelUpUI
extends Control

signal upgrade_selected(upgrade: NanobotUpgradeData)
signal closed

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _choices: VBoxContainer = %ChoicesBox


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("%CloseButton"):
		(%CloseButton as Button).pressed.connect(_on_close_pressed)


func show_for_nanobot(nanobot: Plant, upgrades: Array[NanobotUpgradeData]) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	var name_text: String = "NANOBOT"
	if nanobot != null and nanobot.data != null:
		name_text = nanobot.data.display_name
	_title.text = "%s LEVEL UP" % name_text.to_upper()
	var next_level: int = nanobot.level + 1 if nanobot != null else 2
	var pending: int = nanobot.get_pending_level_up_count() if nanobot != null else 0
	_subtitle.text = "Level %d — choose one upgrade (%d available)" % [next_level, pending]

	for child: Node in _choices.get_children():
		child.queue_free()

	for upgrade: NanobotUpgradeData in upgrades:
		if upgrade == null:
			continue
		_choices.add_child(_create_choice_row(upgrade))


func hide_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _create_choice_row(upgrade: NanobotUpgradeData) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(labels)

	var name_label := Label.new()
	name_label.text = upgrade.display_name
	name_label.add_theme_font_size_override("font_size", 18)
	labels.add_child(name_label)

	var desc := Label.new()
	desc.text = upgrade.description
	labels.add_child(desc)

	var button := Button.new()
	button.text = "SELECT"
	button.custom_minimum_size = Vector2(100, 36)
	button.pressed.connect(_on_select_pressed.bind(upgrade))
	hbox.add_child(button)

	return panel


func _on_select_pressed(upgrade: NanobotUpgradeData) -> void:
	upgrade_selected.emit(upgrade)


func _on_close_pressed() -> void:
	hide_panel()
	closed.emit()
