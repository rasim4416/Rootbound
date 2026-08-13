## Inspection panel for selected Organelles (Ribosome / Mitochondrion).
class_name OrganelInfoPanel
extends Control

@onready var _name_label: Label = %NameLabel
@onready var _status_label: Label = %StatusLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _progress_bar: ProgressBar = %ProgressBar

var _organel: Organel = null
var _producer: ProteinProducerComponent = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func show_organel(organel: Organel) -> void:
	_unbind()
	_organel = organel
	if _organel == null or not is_instance_valid(_organel):
		hide_panel()
		return
	_producer = _organel.get_node_or_null("ProteinProducer") as ProteinProducerComponent
	_organel.died.connect(_on_organel_died)
	_organel.tree_exiting.connect(_on_organel_died)
	_organel.install_completed.connect(_on_install_completed)
	visible = true
	set_process(true)
	_refresh()


func hide_panel() -> void:
	_unbind()
	visible = false
	set_process(false)


func _unbind() -> void:
	if _organel != null and is_instance_valid(_organel):
		if _organel.died.is_connected(_on_organel_died):
			_organel.died.disconnect(_on_organel_died)
		if _organel.tree_exiting.is_connected(_on_organel_died):
			_organel.tree_exiting.disconnect(_on_organel_died)
		if _organel.install_completed.is_connected(_on_install_completed):
			_organel.install_completed.disconnect(_on_install_completed)
	_organel = null
	_producer = null


func _on_organel_died() -> void:
	hide_panel()


func _on_install_completed() -> void:
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _organel == null or not is_instance_valid(_organel):
		hide_panel()
		return

	var display: String = "ORGANELLE"
	if _organel.data != null:
		display = _organel.data.display_name
	_name_label.text = display

	if not _organel.is_mature():
		_status_label.text = "Assembling… %.0f%%" % (_organel.get_install_progress() * 100.0)
		_detail_label.text = ""
		_progress_bar.visible = true
		_progress_bar.value = _organel.get_install_progress() * 100.0
		return

	if _organel.data != null and _organel.data.is_producer():
		_status_label.text = "Producing ATP"
		_detail_label.text = "+%.1f ATP / sec" % _organel.data.atp_per_second
		_progress_bar.visible = false
		return

	if _producer != null:
		var protein: ProteinData = _producer.get_active_protein()
		var protein_name: String = protein.display_name if protein != null else "None"
		var cost: int = _organel.data.protein_atp_cost if _organel.data != null else 0
		var target: Plant = _producer.preview_target()
		var target_text: String = "None"
		if target != null:
			var tname: String = target.data.display_name if target.data != null else "Nanobot"
			target_text = "%s #%d" % [tname, target.debug_id]

		_status_label.text = "Synthesizing"
		_detail_label.text = (
			"Target: %s\nProtein: %s\nCost: %d ATP\nNext: %.1fs"
			% [target_text, protein_name, cost, _producer.get_time_remaining()]
		)
		_progress_bar.visible = true
		_progress_bar.value = _producer.get_production_progress() * 100.0
		return

	_status_label.text = "Active"
	_detail_label.text = ""
	_progress_bar.visible = false
