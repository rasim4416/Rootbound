## Settings — display / window options.
extends Control

@onready var _back_button: Button = %BackButton
@onready var _fullscreen_check: CheckButton = %FullscreenCheck


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	if _fullscreen_check != null:
		_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
		_sync_from_display_settings()
	if DisplaySettings != null:
		DisplaySettings.settings_changed.connect(_sync_from_display_settings)


func _sync_from_display_settings() -> void:
	if _fullscreen_check == null or DisplaySettings == null:
		return
	_fullscreen_check.set_block_signals(true)
	_fullscreen_check.button_pressed = DisplaySettings.is_fullscreen()
	_fullscreen_check.set_block_signals(false)


func _on_fullscreen_toggled(enabled: bool) -> void:
	if DisplaySettings == null:
		return
	DisplaySettings.set_fullscreen(enabled)


func _on_back_pressed() -> void:
	SceneRouter.to_main_menu(get_tree())
