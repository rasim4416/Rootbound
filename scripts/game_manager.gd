## Autoload singleton that owns global game state and core systems.
##
## Other scenes and scripts should use GameManager as the entry point for
## high-level coordination instead of reaching into individual systems directly.
extends Node

enum GameState {
	BOOT,
	PLAYING,
	PAUSED,
	GAME_OVER,
}

signal game_state_changed(new_state: GameState)

## TEMPORARY: set true in the Inspector / debugger to run the modifier math self-test once.
@export var debug_stat_modifier_test: bool = false

var state: GameState = GameState.BOOT

var _resource_manager: ResourceManager
var _permanent_progression: PermanentProgressionManager
var _run_progression: RunProgressionManager
var _level_manager: LevelManager
var _element_inventory: ElementInventory
var _research_manager: ResearchManager
var _save_manager: SaveManager
var _passive_atp_accumulator: float = 0.0


func _ready() -> void:
	_bootstrap_systems()
	_set_state(GameState.BOOT)
	set_process(true)
	if debug_stat_modifier_test:
		_run_debug_stat_modifier_test()


func _process(delta: float) -> void:
	_tick_passive_atp(delta)


func _tick_passive_atp(delta: float) -> void:
	if state != GameState.PLAYING:
		return
	if not is_infection_wave_active():
		return
	if _resource_manager == null:
		return
	var rate: float = get_effective_stat(StatIds.ATP_GENERATION, 0.0)
	if rate <= 0.0:
		return
	_passive_atp_accumulator += rate * delta
	var whole: int = int(floor(_passive_atp_accumulator))
	if whole <= 0:
		return
	_passive_atp_accumulator -= float(whole)
	_resource_manager.add_atp(whole)


## True during SPAWNING / ACTIVE wave states. Between waves economy production pauses.
func is_infection_wave_active() -> bool:
	if get_tree() == null:
		return false
	var nodes: Array[Node] = get_tree().get_nodes_in_group("wave_manager")
	if nodes.is_empty():
		return false
	var wm := nodes[0] as WaveManager
	return wm != null and wm.is_wave_active()


func get_resource_manager() -> ResourceManager:
	return _resource_manager


func get_permanent_progression() -> PermanentProgressionManager:
	return _permanent_progression


func get_run_progression() -> RunProgressionManager:
	return _run_progression


func get_level_manager() -> LevelManager:
	return _level_manager


func get_element_inventory() -> ElementInventory:
	return _element_inventory


func get_research_manager() -> ResearchManager:
	return _research_manager


func get_save_manager() -> SaveManager:
	return _save_manager


## Combines PlantData/InsectData base with permanent then run modifiers.
## Prefer Plant.get_effective_stat for Nanobots (includes instance upgrades).
func get_effective_stat(stat_id: StringName, base_value: float) -> float:
	var permanent_mods: Array[StatModifier] = []
	var run_mods: Array[StatModifier] = []
	if _permanent_progression != null:
		permanent_mods = _permanent_progression.get_modifiers_for_stat(stat_id)
	if _run_progression != null:
		run_mods = _run_progression.get_modifiers_for_stat(stat_id)
	return StatCalculator.calculate(base_value, permanent_mods, run_mods)


func is_game_over() -> bool:
	return state == GameState.GAME_OVER


func is_playing() -> bool:
	return state == GameState.PLAYING


## True when combat/path movement should freeze (soft pause or game over).
func is_gameplay_frozen() -> bool:
	return state == GameState.PAUSED or state == GameState.GAME_OVER


func is_upgrade_paused() -> bool:
	return state == GameState.PAUSED


## Pauses pathogens / combat without stopping the SceneTree (UI stays live).
func pause_for_upgrade() -> void:
	if state == GameState.GAME_OVER:
		return
	_set_state(GameState.PAUSED)


func resume_from_upgrade() -> void:
	if state != GameState.PAUSED:
		return
	_set_state(GameState.PLAYING)


## Enters GAME_OVER once. Safe to call repeatedly.
func enter_game_over() -> void:
	if state == GameState.GAME_OVER:
		return
	_set_state(GameState.GAME_OVER)


## Selects a level and prepares run resources for a fresh attempt.
## Wave counter always starts at Wave 1 for the new run (infinite waves per level).
func begin_level_run(level_data: LevelData) -> void:
	if _level_manager == null:
		push_error("GameManager.begin_level_run: LevelManager missing.")
		return
	if not _level_manager.is_level_unlocked(level_data):
		push_warning("GameManager.begin_level_run: level '%s' is locked." % level_data.level_id)
		return
	_level_manager.load_level(level_data)
	_prepare_run_resources(level_data)
	_set_state(GameState.PLAYING)


## Resets run state for restarting the CURRENT level (permanent progression kept).
## Does NOT reset ElementInventory or ResearchManager unlocks.
func reset_game_state() -> void:
	var level: LevelData = null
	if _level_manager != null:
		level = _level_manager.get_current_level()
	_prepare_run_resources(level)
	_set_state(GameState.PLAYING)


## Leaves gameplay for menu screens. Does not clear permanent progression or LevelData.
func return_to_menu() -> void:
	_set_state(GameState.BOOT)


func _prepare_run_resources(level: LevelData) -> void:
	var starting: int = 100
	if level != null:
		starting = int(round(level.starting_bio_energy))
	if _resource_manager != null:
		_resource_manager.reset_run(starting, 0)
	if _run_progression != null:
		_run_progression.reset()


func _set_state(new_state: GameState) -> void:
	if state == new_state:
		return
	state = new_state
	game_state_changed.emit(state)


func _bootstrap_systems() -> void:
	_resource_manager = ResourceManager.new()
	_resource_manager.name = "ResourceManager"
	add_child(_resource_manager)

	_permanent_progression = PermanentProgressionManager.new()
	_permanent_progression.name = "PermanentProgressionManager"
	add_child(_permanent_progression)

	_run_progression = RunProgressionManager.new()
	_run_progression.name = "RunProgressionManager"
	add_child(_run_progression)

	_level_manager = LevelManager.new()
	_level_manager.name = "LevelManager"
	add_child(_level_manager)

	_element_inventory = ElementInventory.new()
	_element_inventory.name = "ElementInventory"
	add_child(_element_inventory)

	_research_manager = ResearchManager.new()
	_research_manager.name = "ResearchManager"
	add_child(_research_manager)

	_save_manager = SaveManager.new()
	_save_manager.name = "SaveManager"
	add_child(_save_manager)


## TEMPORARY DEBUG — remove when Research Lab / run upgrade UI exist.
## Enable via debug_stat_modifier_test on the GameManager autoload.
func _run_debug_stat_modifier_test() -> void:
	var base_damage: float = 20.0
	var perm := StatModifier.make(StatIds.DAMAGE, StatModifier.ModifierType.MULTIPLICATIVE, 0.10)
	var run := StatModifier.make(StatIds.DAMAGE, StatModifier.ModifierType.MULTIPLICATIVE, 0.25)
	_permanent_progression.add_modifier(perm)
	_run_progression.add_modifier(run)
	var boosted: float = get_effective_stat(StatIds.DAMAGE, base_damage)
	print("StatModifier debug: base=20 permanent=+10%% run=+25%% → effective=%.1f (expect 27.5)" % boosted)
	_permanent_progression.remove_modifier(perm)
	_run_progression.remove_modifier(run)
	var restored: float = get_effective_stat(StatIds.DAMAGE, base_damage)
	print("StatModifier debug: after remove → effective=%.1f (expect 20.0)" % restored)
