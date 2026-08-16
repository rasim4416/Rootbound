## Gameplay status HUD: resources, Core HP, wave status, AutoStart toggle.
class_name GameplayHUD
extends Control

@export var wave_manager: WaveManager
@export var core: Core
@export var level_up_controller: NanobotLevelUpController
@export var plant_manager: PlantManager

@onready var _biomass_label: Label = $TopBar/LeftBox/BiomassLabel
@onready var _atp_label: Label = $TopBar/LeftBox/AtpLabel
@onready var _seeds_label: Label = $TopBar/LeftBox/SeedsLabel
@onready var _wave_label: Label = $TopBar/CenterBox/WaveLabel
@onready var _wave_state_label: Label = $TopBar/CenterBox/WaveStateLabel
@onready var _core_label: Label = $TopBar/RightBox/CoreLabel
@onready var _core_bar: ProgressBar = $TopBar/RightBox/CoreBar
@onready var _auto_start_button: Button = $BottomBar/AutoStartButton
@onready var _all_waves_label: Label = $BottomBar/AllWavesLabel
@onready var _game_over_overlay: Control = $GameOverOverlay
@onready var _restart_button: Button = $GameOverOverlay/Panel/VBox/RestartButton

var _is_game_over_ui: bool = false
var _upgrades_button: Button = null
## Best wave for this level before the current run (for NEW BEST!).
var _best_before_run: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_all_waves_label.visible = false
	_game_over_overlay.visible = false
	_auto_start_button.pressed.connect(_on_auto_start_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	if has_node("%MenuButton"):
		(%MenuButton as Button).pressed.connect(_on_menu_pressed)
	if has_node("%GameOverMenuButton"):
		(%GameOverMenuButton as Button).pressed.connect(_on_menu_pressed)
	if has_node("%UpgradesButton"):
		_upgrades_button = %UpgradesButton as Button
		# Per-bot green arrows replace the global upgrades button.
		_upgrades_button.visible = false
		_upgrades_button.pressed.connect(_on_upgrades_pressed)

	var resources: ResourceManager = _get_resources()
	if resources != null:
		resources.biomass_changed.connect(_on_biomass_changed)
		resources.atp_changed.connect(_on_atp_changed)
		resources.seeds_changed.connect(_on_seeds_changed)
		_refresh_resources(resources)
	else:
		push_warning("GameplayHUD: ResourceManager unavailable.")

	if core != null:
		core.health_changed.connect(_on_core_health_changed)
		_refresh_core(core.current_health, core.data.max_health if core.data != null else 0.0)
	else:
		push_error("GameplayHUD: core is not assigned.")

	if wave_manager != null:
		wave_manager.state_changed.connect(_on_wave_state_changed)
		wave_manager.wave_started.connect(_on_wave_started)
		wave_manager.wave_completed.connect(_on_wave_completed)
		wave_manager.all_waves_completed.connect(_on_all_waves_completed)
		wave_manager.auto_start_enabled_changed.connect(_on_auto_start_changed)
		_refresh_wave_ui()
		_refresh_auto_start_button()
	else:
		push_error("GameplayHUD: wave_manager is not assigned.")

	# Deferred: Main.apply_level runs after child _ready.
	call_deferred("_capture_best_before_run")
	_bind_level_up_controller()
	_bind_meta_materials()


func _capture_best_before_run() -> void:
	_best_before_run = 0
	if GameManager == null or wave_manager == null:
		return
	var levels: LevelManager = GameManager.get_level_manager()
	var level: LevelData = wave_manager.get_level_data()
	if levels == null or level == null:
		return
	_best_before_run = levels.get_best_wave(level.level_id)


func _bind_meta_materials() -> void:
	if not has_node("MetaMaterialsBox"):
		return
	var box: VBoxContainer = $MetaMaterialsBox as VBoxContainer
	if box == null:
		return
	var display: ElementInventoryDisplay = box.get_node_or_null("ElementInventoryDisplay") as ElementInventoryDisplay
	if display == null:
		display = ElementInventoryDisplay.new()
		display.name = "ElementInventoryDisplay"
		display.show_header = true
		display.header_text = "META MATERIALS"
		display.compact = true
		box.add_child(display)


func _bind_level_up_controller() -> void:
	if level_up_controller == null and get_tree() != null:
		var nodes: Array[Node] = get_tree().get_nodes_in_group("nanobot_level_up_controller")
		if not nodes.is_empty():
			level_up_controller = nodes[0] as NanobotLevelUpController
	if level_up_controller == null:
		return
	if not level_up_controller.pending_upgrades_changed.is_connected(_on_pending_upgrades_changed):
		level_up_controller.pending_upgrades_changed.connect(_on_pending_upgrades_changed)
	_on_pending_upgrades_changed(level_up_controller.get_pending_upgrade_count())


## Called by GameOverManager when the Core falls.
func show_game_over() -> void:
	_is_game_over_ui = true
	_game_over_overlay.visible = true
	_auto_start_button.disabled = true
	_all_waves_label.visible = false
	if _upgrades_button != null:
		_upgrades_button.visible = false
	_refresh_game_over_stats()


func _refresh_game_over_stats() -> void:
	var wave: int = 0
	var level: LevelData = null
	if wave_manager != null:
		wave = wave_manager.get_current_wave_number()
		level = wave_manager.get_level_data()

	var best: int = wave
	var level_name: String = "LEVEL ?"
	if GameManager != null and level != null:
		var levels: LevelManager = GameManager.get_level_manager()
		if levels != null:
			best = levels.get_best_wave(level.level_id)
		level_name = level.display_name.to_upper() if level.display_name != "" else String(level.level_id).to_upper()

	if has_node("%MapLabel"):
		(%MapLabel as Label).text = "CELL INTERIOR"
	if has_node("%LevelLabel"):
		(%LevelLabel as Label).text = level_name
	if has_node("%WaveReachedLabel"):
		(%WaveReachedLabel as Label).text = "WAVE %d" % wave
	if has_node("%BestWaveLabel"):
		(%BestWaveLabel as Label).text = "BEST WAVE: %d" % best
	if has_node("%NewBestLabel"):
		var new_best: Label = %NewBestLabel as Label
		new_best.visible = wave > 0 and wave > _best_before_run


func _on_auto_start_pressed() -> void:
	if _is_game_over_ui or (GameManager != null and GameManager.is_game_over()):
		return
	if wave_manager == null:
		return
	wave_manager.set_auto_start_enabled(not wave_manager.is_auto_start_enabled())


func _on_auto_start_changed(_enabled: bool) -> void:
	_refresh_auto_start_button()
	_refresh_wave_ui()


func _on_restart_pressed() -> void:
	if GameManager != null:
		GameManager.reset_game_state()
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	if GameManager != null:
		GameManager.return_to_menu()
	SceneRouter.to_main_menu(get_tree())


func _on_upgrades_pressed() -> void:
	if _is_game_over_ui or (GameManager != null and GameManager.is_game_over()):
		return
	if level_up_controller == null:
		_bind_level_up_controller()
	if level_up_controller == null:
		return
	var preferred: Plant = null
	if plant_manager != null:
		preferred = plant_manager.get_selected_nanobot()
	level_up_controller.open_upgrade_menu(preferred)


func _on_pending_upgrades_changed(_count: int) -> void:
	# Global HUD badge removed — each Nanobot shows its own upgrade arrow.
	if _upgrades_button != null:
		_upgrades_button.visible = false


func _on_biomass_changed(new_amount: int) -> void:
	_biomass_label.text = "BIO-ENERGY: %d" % new_amount


func _on_atp_changed(new_amount: int) -> void:
	_atp_label.text = "ATP: %d" % new_amount


func _on_seeds_changed(new_amount: int) -> void:
	_seeds_label.text = "NANOBOT UNITS: %d" % new_amount


func _on_core_health_changed(current_health: float, max_health: float) -> void:
	_refresh_core(current_health, max_health)


func _on_wave_state_changed(_new_state: WaveManager.WaveState) -> void:
	_refresh_wave_ui()


func _on_wave_started(_wave_number: int) -> void:
	_refresh_wave_ui()


func _on_wave_completed(_wave_number: int) -> void:
	_refresh_wave_ui()


func _on_all_waves_completed() -> void:
	_refresh_wave_ui()


func _refresh_resources(resources: ResourceManager) -> void:
	_biomass_label.text = "BIO-ENERGY: %d" % resources.biomass
	_atp_label.text = "ATP: %d" % resources.atp
	_seeds_label.text = "NANOBOT UNITS: %d" % resources.seeds


func _refresh_core(current_health: float, max_health: float) -> void:
	_core_label.text = "NUCLEUS: %.0f / %.0f" % [current_health, max_health]
	_core_bar.max_value = maxf(max_health, 1.0)
	_core_bar.value = current_health


func _refresh_wave_ui() -> void:
	if wave_manager == null:
		return

	var current: int = wave_manager.get_current_wave_number()
	_wave_label.text = "INFECTION WAVE: %d" % current
	_wave_state_label.text = wave_manager.get_state_display_name()

	# Infinite waves — never show "ALL INFECTIONS CLEARED".
	_all_waves_label.visible = false

	if _is_game_over_ui:
		_auto_start_button.disabled = true
		return

	_auto_start_button.disabled = false


func _refresh_auto_start_button() -> void:
	if _auto_start_button == null or wave_manager == null:
		return
	if wave_manager.is_auto_start_enabled():
		_auto_start_button.text = "AUTO START: ON"
	else:
		_auto_start_button.text = "AUTO START: OFF"


func _get_resources() -> ResourceManager:
	if GameManager == null:
		return null
	return GameManager.get_resource_manager()
