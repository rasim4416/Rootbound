## Entry scene for an active level run.
##
## Configures Grid / Nucleus / waves / visuals from LevelManager's LevelData.
## Does not own level selection — that lives in the menu + LevelManager.
extends Node2D

@onready var background: Node2D = $Background
@onready var grid: GridManager = $Grid
@onready var paths: Node2D = $Paths
@onready var plant_layer: Node2D = $PlantLayer
@onready var organel_layer: Node2D = $OrganelLayer
@onready var plant_manager: PlantManager = $PlantManager
@onready var organel_manager: OrganelManager = $OrganelManager
@onready var seed_selection_manager: SeedSelectionManager = $SeedSelectionManager
@onready var organel_selection_manager: OrganelSelectionManager = $OrganelSelectionManager
@onready var shop_manager: ShopManager = $ShopManager
@onready var insect_layer: Node2D = $InsectLayer
@onready var projectile_layer: Node2D = $ProjectileLayer
@onready var projectile_manager: ProjectileManager = $ProjectileManager
@onready var core: Core = $Core
@onready var ui_layer: CanvasLayer = $UILayer
@onready var shop_ui: ShopUI = $UILayer/ShopUI
@onready var gameplay_hud: Control = $UILayer/GameplayHUD
@onready var wave_manager: WaveManager = $WaveManager
@onready var targeting_system: TargetingSystem = $TargetingSystem
@onready var reward_manager: RewardManager = $RewardManager
@onready var core_damage_system: CoreDamageSystem = $CoreDamageSystem
@onready var game_over_manager: Node = $GameOverManager

@onready var _path_visual: PathVisual = $Paths/PathVisual
@onready var _planting_visual: PlantingAreaVisual = $Grid/PlantingAreaVisual
@onready var _nanobot_info: NanobotInfoPanel = $UILayer/NanobotInfoPanel
@onready var _organel_info: OrganelInfoPanel = $UILayer/OrganelInfoPanel


func _ready() -> void:
	var level: LevelData = _resolve_level()
	if level == null:
		push_error("Main: no LevelData loaded. Returning to Main Menu.")
		SceneRouter.to_main_menu(get_tree())
		return

	_apply_level(level)
	if plant_manager != null:
		plant_manager.nanobot_selected.connect(_on_nanobot_selected)
		plant_manager.nanobot_deselected.connect(_on_nanobot_deselected)
		plant_manager.empty_cell_clicked.connect(_on_empty_cell_clicked)
	if organel_manager != null:
		organel_manager.organel_selected.connect(_on_organel_selected)
		organel_manager.organel_deselected.connect(_on_organel_deselected)


func _on_empty_cell_clicked(cell: Vector2i) -> void:
	if shop_ui != null:
		shop_ui.open_panel_for_cell(cell)


func _resolve_level() -> LevelData:
	if GameManager == null:
		return null
	var levels: LevelManager = GameManager.get_level_manager()
	if levels == null or not levels.has_level_loaded():
		return null
	return levels.get_current_level()


func _apply_level(level: LevelData) -> void:
	_configure_grid(level)
	_configure_core(level)
	_configure_path_visuals(level)
	if not wave_manager.apply_level(level):
		push_error("Main: WaveManager failed to apply LevelData '%s'." % level.level_id)


func _configure_grid(level: LevelData) -> void:
	grid.cell_size = level.cell_size
	grid.columns = level.grid_columns
	grid.rows = level.grid_rows
	grid.clear_all_occupancy()
	grid.queue_redraw()


func _configure_core(level: LevelData) -> void:
	var core_data := CoreData.new()
	core_data.core_id = &"level_nucleus"
	core_data.display_name = "Nucleus"
	core_data.max_health = level.nucleus_max_health
	core.initialize(core_data)

	var primary: GridPathData = level.get_primary_path()
	var visual := core.get_node_or_null("Visual") as Node2D
	if visual != null and primary != null and not primary.cells.is_empty():
		var end_cell: Vector2i = primary.cells[primary.cells.size() - 1]
		visual.global_position = grid.grid_to_world_center(end_cell)


func _configure_path_visuals(level: LevelData) -> void:
	var paths: Array[GridPathData] = level.get_all_paths()
	if grid != null:
		grid.apply_grid_paths(paths)
	if _path_visual != null:
		_path_visual.apply_grid_paths(paths)
	if _planting_visual != null:
		_planting_visual.apply_grid_paths(paths)


func _on_nanobot_selected(nanobot: Plant) -> void:
	if shop_ui != null:
		shop_ui.close_panel()
	if _organel_info != null:
		_organel_info.hide_panel()
	_set_support_aura_selection(nanobot)
	_set_attack_range_selection(nanobot)
	if _nanobot_info != null:
		_nanobot_info.show_nanobot(nanobot)


func _on_nanobot_deselected() -> void:
	_set_support_aura_selection(null)
	_set_attack_range_selection(null)
	if _nanobot_info != null:
		_nanobot_info.hide_panel()


func _on_organel_selected(organel: Organel) -> void:
	if shop_ui != null:
		shop_ui.close_panel()
	_set_support_aura_selection(null)
	_set_attack_range_selection(null)
	if _nanobot_info != null:
		_nanobot_info.hide_panel()
	if _organel_info != null:
		_organel_info.show_organel(organel)


func _on_organel_deselected() -> void:
	if _organel_info != null:
		_organel_info.hide_panel()


func _set_support_aura_selection(selected: Plant) -> void:
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group("support_components"):
		var support := node as SupportComponent
		if support == null:
			continue
		var plant: Plant = support.get_plant()
		support.set_aura_visible(selected != null and plant == selected)


func _set_attack_range_selection(selected: Plant) -> void:
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group("attack_range_indicators"):
		var indicator := node as AttackRangeIndicator
		if indicator == null:
			continue
		var plant: Plant = indicator.get_plant()
		indicator.set_range_visible(selected != null and plant == selected)
