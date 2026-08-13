## Window mode + stretch scaling. Persists to user://display.cfg
extends Node

const CONFIG_PATH: String = "user://display.cfg"
const DESIGN_SIZE: Vector2i = Vector2i(1152, 648)

signal settings_changed

var fullscreen: bool = true


func _ready() -> void:
	load_settings()
	apply_settings()


func load_settings() -> void:
	fullscreen = true
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed as Dictionary
	fullscreen = bool(data.get("fullscreen", true))


func save_settings() -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("DisplaySettings: could not write %s" % CONFIG_PATH)
		return
	file.store_string(JSON.stringify({"fullscreen": fullscreen}))
	file.close()


func apply_settings() -> void:
	var window: Window = get_window()
	if window == null:
		return
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.size = DESIGN_SIZE
		var screen_id: int = window.current_screen
		var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
		window.position = Vector2i(
			(screen_size.x - DESIGN_SIZE.x) / 2,
			(screen_size.y - DESIGN_SIZE.y) / 2
		)
	settings_changed.emit()


func set_fullscreen(enabled: bool) -> void:
	if fullscreen == enabled:
		return
	fullscreen = enabled
	apply_settings()
	save_settings()


func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)


func is_fullscreen() -> bool:
	return fullscreen


func get_design_size() -> Vector2i:
	return DESIGN_SIZE
