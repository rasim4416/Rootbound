## Optional Nanobot level-up choice panel (does not pause gameplay).
class_name NanobotLevelUpUI
extends Control

signal upgrade_selected(upgrade: NanobotUpgradeData)
signal closed

@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _separator: HSeparator = %Separator
@onready var _choices: VBoxContainer = %ChoicesBox
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_theme()
	_close_button.pressed.connect(_on_close_pressed)


func _apply_theme() -> void:
	_panel.add_theme_stylebox_override("panel", BioPanelTheme.panel(12))
	_title.add_theme_color_override("font_color", BioPanelTheme.ACCENT)
	_subtitle.add_theme_color_override("font_color", BioPanelTheme.TEXT_DIM)
	BioPanelTheme.style_separator(_separator)
	BioPanelTheme.style_button(_close_button)


func show_for_nanobot(nanobot: Plant, upgrades: Array[NanobotUpgradeData]) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	var name_text: String = "NANOBOT"
	if nanobot != null and nanobot.data != null:
		name_text = nanobot.data.display_name
	_title.text = "%s LEVEL UP" % name_text.to_upper()
	var next_level: int = nanobot.level + 1 if nanobot != null else 2
	var pending: int = nanobot.get_pending_level_up_count() if nanobot != null else 0
	_subtitle.text = "LEVEL %d — CHOOSE ONE UPGRADE (%d AVAILABLE)" % [next_level, pending]

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
	panel.add_theme_stylebox_override("panel", BioPanelTheme.card(BioPanelTheme.ACCENT_DIM))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var labels := VBoxContainer.new()
	labels.add_theme_constant_override("separation", 2)
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(labels)

	var name_label := Label.new()
	name_label.text = upgrade.display_name.to_upper()
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", BioPanelTheme.TEXT)
	labels.add_child(name_label)

	var desc := Label.new()
	desc.text = upgrade.description
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", BioPanelTheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(desc)

	var button := Button.new()
	button.text = "SELECT"
	button.custom_minimum_size = Vector2(96, 34)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	BioPanelTheme.style_button(button, true)
	button.pressed.connect(_on_select_pressed.bind(upgrade))
	hbox.add_child(button)

	return panel


func _on_select_pressed(upgrade: NanobotUpgradeData) -> void:
	upgrade_selected.emit(upgrade)


func _on_close_pressed() -> void:
	hide_panel()
	closed.emit()
