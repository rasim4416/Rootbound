## Selected-Nanobot stats panel: XP, combat stats, targeting mode, proteins.
class_name NanobotInfoPanel
extends Control

@onready var _panel: PanelContainer = %Panel
@onready var _name_label: Label = %NameLabel
@onready var _level_badge: PanelContainer = %LevelBadge
@onready var _level_label: Label = %LevelLabel
@onready var _role_label: Label = %RoleLabel
@onready var _xp_label: Label = %XpLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _stats_section: VBoxContainer = %StatsSection
@onready var _stats_grid: GridContainer = %StatsGrid
@onready var _targeting_section: VBoxContainer = %TargetingSection
@onready var _targeting_grid: GridContainer = %TargetingGrid
@onready var _targeting_hint: Label = %TargetingHint
@onready var _proteins_section: VBoxContainer = %ProteinsSection
@onready var _proteins_label: Label = %ProteinsLabel
@onready var _upgrade_button: Button = %UpgradeButton

var _nanobot: Plant = null
var _mode_buttons: Dictionary = {} ## TargetingModes.Mode value → Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_theme()
	_build_targeting_buttons()
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_upgrade_button.visible = false
	var research: ResearchManager = null
	if GameManager != null:
		research = GameManager.get_research_manager()
	if research != null:
		research.research_unlocked.connect(_on_research_unlocked)


func _apply_theme() -> void:
	_panel.add_theme_stylebox_override("panel", BioPanelTheme.panel())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_name_label.add_theme_color_override("font_color", BioPanelTheme.ACCENT)
	_level_badge.add_theme_stylebox_override("panel", BioPanelTheme.badge())
	_level_label.add_theme_color_override("font_color", BioPanelTheme.TEXT)
	_role_label.add_theme_color_override("font_color", BioPanelTheme.TEXT_DIM)
	_xp_label.add_theme_color_override("font_color", BioPanelTheme.TEXT_DIM)
	_proteins_label.add_theme_color_override("font_color", BioPanelTheme.TEXT)
	_targeting_hint.add_theme_color_override("font_color", BioPanelTheme.HIGHLIGHT)
	BioPanelTheme.style_progress(_xp_bar)
	BioPanelTheme.style_button(_upgrade_button, true)
	for section: VBoxContainer in [_stats_section, _targeting_section, _proteins_section]:
		var title := section.get_child(0) as Label
		if title != null:
			title.add_theme_color_override("font_color", BioPanelTheme.ACCENT_DIM)


func _build_targeting_buttons() -> void:
	for mode: int in TargetingModes.ORDER:
		var button := Button.new()
		button.text = TargetingModes.label(mode)
		button.tooltip_text = TargetingModes.description(mode)
		button.custom_minimum_size = Vector2(0, 26)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(_on_mode_pressed.bind(mode))
		_targeting_grid.add_child(button)
		_mode_buttons[mode] = button


func show_nanobot(nanobot: Plant) -> void:
	_unbind()
	_nanobot = nanobot
	if _nanobot == null or not is_instance_valid(_nanobot):
		hide_panel()
		return
	_nanobot.xp_changed.connect(_on_xp_changed)
	_nanobot.leveled_up.connect(_on_leveled_up)
	_nanobot.level_up_available.connect(_on_level_up_available)
	_nanobot.proteins_changed.connect(_on_proteins_changed)
	_nanobot.target_mode_changed.connect(_on_target_mode_changed)
	_nanobot.tree_exiting.connect(_on_nanobot_exiting)
	visible = true
	_refresh()


func hide_panel() -> void:
	_unbind()
	_nanobot = null
	visible = false


func _unbind() -> void:
	if _nanobot == null or not is_instance_valid(_nanobot):
		_nanobot = null
		return
	if _nanobot.xp_changed.is_connected(_on_xp_changed):
		_nanobot.xp_changed.disconnect(_on_xp_changed)
	if _nanobot.leveled_up.is_connected(_on_leveled_up):
		_nanobot.leveled_up.disconnect(_on_leveled_up)
	if _nanobot.level_up_available.is_connected(_on_level_up_available):
		_nanobot.level_up_available.disconnect(_on_level_up_available)
	if _nanobot.proteins_changed.is_connected(_on_proteins_changed):
		_nanobot.proteins_changed.disconnect(_on_proteins_changed)
	if _nanobot.target_mode_changed.is_connected(_on_target_mode_changed):
		_nanobot.target_mode_changed.disconnect(_on_target_mode_changed)
	if _nanobot.tree_exiting.is_connected(_on_nanobot_exiting):
		_nanobot.tree_exiting.disconnect(_on_nanobot_exiting)
	_nanobot = null


func _on_nanobot_exiting() -> void:
	hide_panel()


func _on_xp_changed(_current: float, _to_next: float, _level: int) -> void:
	_refresh()


func _on_leveled_up(_level: int, _upgrade: NanobotUpgradeData) -> void:
	_refresh()


func _on_level_up_available(_nanobot: Plant) -> void:
	_refresh()


func _on_proteins_changed() -> void:
	_refresh()


func _on_target_mode_changed(_mode: int) -> void:
	_refresh_targeting()


func _on_research_unlocked(research_id: StringName) -> void:
	if not TargetingModes.is_research_id(research_id):
		return
	if _nanobot != null and is_instance_valid(_nanobot):
		_refresh_targeting()


func _on_mode_pressed(mode: int) -> void:
	if _nanobot == null or not is_instance_valid(_nanobot):
		return
	_nanobot.set_target_mode(mode)
	_refresh_targeting()


func _on_upgrade_pressed() -> void:
	if _nanobot == null or not is_instance_valid(_nanobot) or not _nanobot.has_pending_level_up():
		return
	var nodes: Array[Node] = get_tree().get_nodes_in_group("nanobot_level_up_controller")
	if nodes.is_empty():
		return
	var controller := nodes[0] as NanobotLevelUpController
	if controller != null:
		controller.open_upgrade_menu(_nanobot)


func _refresh() -> void:
	if _nanobot == null or not is_instance_valid(_nanobot):
		hide_panel()
		return

	_name_label.text = _nanobot.data.display_name if _nanobot.data != null else "NANOBOT"
	_level_label.text = "LV %d" % _nanobot.level
	_role_label.text = _role_text()

	var pending: int = _nanobot.get_pending_level_up_count()
	_upgrade_button.visible = pending > 0
	if pending > 0:
		_upgrade_button.text = (
			"CHOOSE UPGRADE" if pending == 1 else "CHOOSE UPGRADES (%d)" % pending
		)
		_level_label.add_theme_color_override("font_color", BioPanelTheme.HIGHLIGHT)
	else:
		_level_label.add_theme_color_override("font_color", BioPanelTheme.TEXT)

	_refresh_xp()
	_refresh_stats()
	_refresh_targeting()
	_refresh_proteins()


func _role_text() -> String:
	if _nanobot.is_support_nanobot():
		return "SUPPORT NANOBOT"
	if _nanobot.data != null and _nanobot.data.is_resource_generator():
		return "GENERATOR NANOBOT"
	return "COMBAT NANOBOT"


func _refresh_xp() -> void:
	var to_next: float = _nanobot.get_xp_to_next_level()
	if is_inf(to_next):
		_xp_label.text = "XP MAX"
		_xp_bar.max_value = 1.0
		_xp_bar.value = 1.0
		return
	_xp_label.text = "XP %.0f / %.0f" % [_nanobot.current_xp, to_next]
	_xp_bar.max_value = maxf(to_next, 1.0)
	_xp_bar.value = _nanobot.current_xp


func _refresh_stats() -> void:
	for child: Node in _stats_grid.get_children():
		_stats_grid.remove_child(child)
		child.queue_free()

	if _nanobot.is_support_nanobot():
		_add_stat("Aura Range", "%.0f" % _nanobot.get_effective_support_range())
		_add_stat(
			"AS Bonus",
			"+%.0f%%" % (_nanobot.get_effective_support_attack_speed_bonus() * 100.0)
		)
		_add_stat("Assist XP", "%.0f" % _nanobot.get_effective_assist_xp_reward())
		return

	if _nanobot.data != null and _nanobot.data.is_resource_generator():
		var amount: float = _nanobot.get_effective_stat(
			StatIds.BIO_ENERGY_PRODUCTION_AMOUNT,
			float(_nanobot.data.bio_energy_production_amount)
		)
		var interval: float = maxf(
			_nanobot.get_effective_stat(
				StatIds.BIO_ENERGY_PRODUCTION_INTERVAL,
				_nanobot.data.bio_energy_production_interval
			),
			0.05
		)
		_add_stat("Production", "%.0f BE" % amount)
		_add_stat("Interval", "%.0fs" % interval)
		_add_stat("Tick XP", "%.0f" % _nanobot.data.bio_energy_production_xp)
		return

	var damage: float = 0.0
	var range_v: float = 0.0
	var shots_per_sec: float = 0.0
	if _nanobot.data != null:
		damage = _nanobot.get_effective_stat(StatIds.DAMAGE, _nanobot.data.damage)
		range_v = _nanobot.get_effective_stat(StatIds.ATTACK_RANGE, _nanobot.data.attack_range)
		if _nanobot.data.attack_cooldown > 0.0:
			shots_per_sec = 1.0 / _nanobot.get_effective_attack_cooldown()

	_add_stat("Damage", "%.0f" % damage)
	_add_stat("Attack Speed", "%.2f /s" % shots_per_sec)
	_add_stat("Range", "%.0f" % range_v)
	_add_stat("Rotation", "%.1f rad/s" % _nanobot.get_effective_rotation_speed())
	if shots_per_sec > 0.0:
		_add_stat("DPS", "%.0f" % (damage * shots_per_sec))


func _add_stat(caption: String, value: String) -> void:
	var name_label := Label.new()
	name_label.text = caption
	name_label.add_theme_color_override("font_color", BioPanelTheme.TEXT_DIM)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_grid.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_color_override("font_color", BioPanelTheme.TEXT)
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats_grid.add_child(value_label)


func _refresh_targeting() -> void:
	var is_turret: bool = (
		not _nanobot.is_support_nanobot()
		and _nanobot.data != null
		and _nanobot.data.attack_range > 0.0
		and _nanobot.data.damage > 0.0
	)
	_targeting_section.visible = is_turret
	if not is_turret:
		return

	var unlocked: bool = TargetingModes.is_research_unlocked()
	var active: int = _nanobot.get_target_mode()
	for mode: int in TargetingModes.ORDER:
		var button: Button = _mode_buttons.get(mode, null) as Button
		if button == null:
			continue
		var enabled: bool = TargetingModes.is_available(mode)
		BioPanelTheme.style_toggle(button, mode == active, enabled)
	_targeting_hint.visible = not unlocked
	_targeting_hint.text = "Unlock the Targeting research to use First / Last / Weakest / Strongest."


func _refresh_proteins() -> void:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in _nanobot.get_protein_summary():
		lines.append(
			"%s ×%d" % [entry.get("display_name", "Protein"), int(entry.get("count", 0))]
		)
	if lines.is_empty():
		_proteins_label.text = "None"
		_proteins_label.add_theme_color_override("font_color", BioPanelTheme.TEXT_DIM)
	else:
		_proteins_label.text = "\n".join(lines)
		_proteins_label.add_theme_color_override("font_color", BioPanelTheme.TEXT)
