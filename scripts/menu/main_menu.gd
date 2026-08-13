## Rootbound title screen — navigation only.
extends Control

@onready var _play_button: Button = %PlayButton
@onready var _research_button: Button = %ResearchButton
@onready var _level_select_button: Button = %LevelSelectButton
@onready var _settings_button: Button = %SettingsButton


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_research_button.pressed.connect(_on_research_pressed)
	_level_select_button.pressed.connect(_on_level_select_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	if GameManager != null:
		GameManager.return_to_menu()
	_ensure_element_display()


func _ensure_element_display() -> void:
	if has_node("ElementInventoryDisplay"):
		return
	var display := ElementInventoryDisplay.new()
	display.name = "ElementInventoryDisplay"
	display.show_header = true
	display.header_text = "META MATERIALS"
	display.compact = true
	display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	display.offset_left = 16.0
	display.offset_top = 16.0
	display.offset_right = 136.0
	display.grow_horizontal = Control.GROW_DIRECTION_END
	display.custom_minimum_size = Vector2(120, 0)
	add_child(display)


func _on_play_pressed() -> void:
	SceneRouter.to_level_select(get_tree())


func _on_research_pressed() -> void:
	SceneRouter.to_research_lab(get_tree())


func _on_level_select_pressed() -> void:
	SceneRouter.to_level_select(get_tree())


func _on_settings_pressed() -> void:
	SceneRouter.to_settings(get_tree())
