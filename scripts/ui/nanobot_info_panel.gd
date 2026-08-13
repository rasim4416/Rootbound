## Compact selected-Nanobot XP / stats panel.
class_name NanobotInfoPanel
extends Control

@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_label: Label = %XpLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _stats_label: Label = %StatsLabel

var _nanobot: Plant = null
var _upgrade_button: Button = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("%UpgradeButton"):
		_upgrade_button = %UpgradeButton as Button
		_upgrade_button.pressed.connect(_on_upgrade_pressed)
		_upgrade_button.visible = false


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

	var display: String = "NANOBOT"
	if _nanobot.data != null:
		display = _nanobot.data.display_name
	_name_label.text = display
	var pending: int = _nanobot.get_pending_level_up_count()
	if pending > 0:
		_level_label.text = "Level %d — %d upgrade(s) ready" % [_nanobot.level, pending]
	else:
		_level_label.text = "Level %d" % _nanobot.level
	if _upgrade_button != null:
		_upgrade_button.visible = pending > 0
		_upgrade_button.text = "Choose upgrade" if pending == 1 else "Choose upgrades (%d)" % pending

	var to_next: float = _nanobot.get_xp_to_next_level()
	if is_inf(to_next):
		_xp_label.text = "XP MAX"
		_xp_bar.max_value = 1.0
		_xp_bar.value = 1.0
	else:
		_xp_label.text = "XP %.0f / %.0f" % [_nanobot.current_xp, to_next]
		_xp_bar.max_value = maxf(to_next, 1.0)
		_xp_bar.value = _nanobot.current_xp

	var damage: float = 0.0
	var range_v: float = 0.0
	var atk_speed: float = 1.0
	var rot: float = _nanobot.get_effective_rotation_speed()
	if _nanobot.data != null:
		damage = _nanobot.get_effective_stat(StatIds.DAMAGE, _nanobot.data.damage)
		range_v = _nanobot.get_effective_stat(StatIds.ATTACK_RANGE, _nanobot.data.attack_range)
		atk_speed = _nanobot.get_effective_stat(StatIds.ATTACK_SPEED, 1.0)

	var shots_per_sec: float = 0.0
	if _nanobot.data != null and _nanobot.data.attack_cooldown > 0.0:
		shots_per_sec = atk_speed / _nanobot.data.attack_cooldown

	_stats_label.text = (
		"Damage: %.0f\nAttack Speed: %.2f/s\nRange: %.0f\nRotation: %.1f rad/s"
		% [damage, shots_per_sec, range_v, rot]
	)

	if _nanobot.is_support_nanobot():
		var support_range: float = _nanobot.get_effective_support_range()
		var bonus: float = _nanobot.get_effective_support_attack_speed_bonus()
		_stats_label.text = (
			"Role: Support\nAura Range: %.0f\nAS Bonus: +%.0f%%\nAssist XP: %.0f"
			% [support_range, bonus * 100.0, _nanobot.get_effective_assist_xp_reward()]
		)

	var protein_lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in _nanobot.get_protein_summary():
		protein_lines.append("%s ×%d" % [entry.get("display_name", "Protein"), int(entry.get("count", 0))])
	if protein_lines.is_empty():
		_stats_label.text += "\n\nPROTEINS:\nNone"
	else:
		_stats_label.text += "\n\nPROTEINS:\n" + "\n".join(protein_lines)
