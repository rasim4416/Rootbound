## F4 Research Designer. Debug/editor builds only. Edits ResearchData catalog.
class_name ResearchDesigner
extends Node

@export var ui: ResearchDesignerUI

var is_active: bool = false

var _catalog: Array[ResearchData] = []
var _selected_id: StringName = &""
var _history: ResearchDesignerHistory = ResearchDesignerHistory.new()


func _ready() -> void:
	add_to_group("research_designer")
	set_process_unhandled_input(true)
	if not _is_allowed():
		set_process_unhandled_input(false)
		return
	if ui != null:
		ui.set_active(false)
		_connect_ui()


func _is_allowed() -> bool:
	return OS.is_debug_build() or OS.has_feature("editor")


func _connect_ui() -> void:
	ui.undo_pressed.connect(undo)
	ui.redo_pressed.connect(redo)
	ui.save_pressed.connect(save_catalog)
	ui.save_as_path_chosen.connect(save_as)
	ui.node_selected.connect(func(id: StringName) -> void:
		_selected_id = id
		_refresh()
		if ui != null:
			ui.focus_selected()
	)
	ui.catalog_changed.connect(_refresh_light)
	ui.history_commit.connect(func() -> void:
		_push_history("edit")
		_sync_manager()
		_refresh_light()
	)
	ui.add_node_requested.connect(add_node)
	ui.duplicate_requested.connect(duplicate_node)
	ui.delete_requested.connect(delete_node)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_allowed() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_F4:
		set_active(not is_active)
		get_viewport().set_input_as_handled()
		return
	if not is_active:
		return
	match key.keycode:
		KEY_ESCAPE:
			set_active(false)
			get_viewport().set_input_as_handled()
		KEY_F:
			if not key.ctrl_pressed and ui != null:
				ui.fit_tree()
				get_viewport().set_input_as_handled()
		KEY_S:
			if key.ctrl_pressed:
				if key.shift_pressed:
					if ui != null:
						ui.popup_save_as()
				else:
					save_catalog()
				get_viewport().set_input_as_handled()
		KEY_Z:
			if key.ctrl_pressed:
				undo()
				get_viewport().set_input_as_handled()
		KEY_Y:
			if key.ctrl_pressed:
				redo()
				get_viewport().set_input_as_handled()
		KEY_D:
			if key.ctrl_pressed:
				duplicate_node(_selected_id)
				get_viewport().set_input_as_handled()
		KEY_DELETE:
			if ui != null and ui.try_delete_edge():
				_refresh()
			else:
				delete_node(_selected_id)
			get_viewport().set_input_as_handled()


func set_active(active: bool) -> void:
	if not _is_allowed():
		return
	if is_active == active:
		return
	is_active = active
	if is_active:
		_enter()
	else:
		_exit()


func _enter() -> void:
	_close_other_tools()
	_bind_catalog()
	_history.clear()
	_push_history("enter")
	if ui != null:
		ui.set_active(true)
	_refresh()
	if ui != null:
		ui.fit_tree()


func _exit() -> void:
	if ui != null:
		ui.set_active(false)


func _close_other_tools() -> void:
	if get_tree() == null:
		return
	for n: Node in get_tree().get_nodes_in_group("dev_editor"):
		if n != self and n.has_method("set_active"):
			n.call("set_active", false)
	for n2: Node in get_tree().get_nodes_in_group("wave_designer"):
		if n2.has_method("set_active"):
			n2.call("set_active", false)
	for n3: Node in get_tree().get_nodes_in_group("path_dev_mode"):
		if n3 != self and n3.get("is_active") == true and n3.has_method("set_active"):
			n3.call("set_active", false)


func _research_manager() -> ResearchManager:
	if GameManager == null:
		return null
	return GameManager.get_research_manager()


func _bind_catalog() -> void:
	var rm: ResearchManager = _research_manager()
	if rm != null:
		if rm.research_catalog.is_empty():
			rm.reload_catalog_from_disk()
		_catalog = rm.research_catalog
	if _catalog.is_empty():
		_catalog = []
	if _selected_id == &"" and not _catalog.is_empty() and _catalog[0] != null:
		_selected_id = _catalog[0].research_id
	_sync_manager()


func _sync_manager() -> void:
	var rm: ResearchManager = _research_manager()
	if rm != null:
		rm.replace_catalog(_catalog)


func add_node(graph_position: Vector2) -> void:
	var data := ResearchData.new()
	data.research_id = _unique_id(&"research")
	data.display_name = String(data.research_id)
	data.editor_position = graph_position
	data.tier = 1
	data.unlockable = true
	_catalog.append(data)
	_selected_id = data.research_id
	_sync_manager()
	_push_history("add_node")
	_refresh()


func duplicate_node(research_id: StringName) -> void:
	var src: ResearchData = _find(research_id)
	if src == null:
		return
	var copy: ResearchData = src.duplicate(true) as ResearchData
	copy.research_id = _unique_id(src.research_id)
	copy.display_name = src.display_name + " Copy"
	copy.editor_position = src.editor_position + Vector2(40, 40)
	copy.resource_path = ""
	_catalog.append(copy)
	_selected_id = copy.research_id
	_sync_manager()
	_push_history("dup_node")
	_refresh()


func delete_node(research_id: StringName) -> void:
	if research_id == &"":
		return
	var idx: int = -1
	for i: int in range(_catalog.size()):
		if _catalog[i] != null and _catalog[i].research_id == research_id:
			idx = i
			break
	if idx < 0:
		return
	var removed: ResearchData = _catalog[idx]
	_catalog.remove_at(idx)
	for data: ResearchData in _catalog:
		if data == null:
			continue
		var keep: Array[StringName] = []
		for pid: StringName in data.prerequisite_ids:
			if pid != research_id:
				keep.append(pid)
		data.prerequisite_ids = keep
	if removed != null and not removed.resource_path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(removed.resource_path))
	if _catalog.is_empty():
		_selected_id = &""
	else:
		_selected_id = _catalog[mini(idx, _catalog.size() - 1)].research_id
	_sync_manager()
	_push_history("del_node")
	_refresh()


func save_catalog() -> void:
	var err: Error = ResearchDesignerIO.save_catalog(_catalog)
	if err != OK:
		_flash("Save failed: %s" % error_string(err), false)
		return
	var rm: ResearchManager = _research_manager()
	if rm != null:
		rm.reload_catalog_from_disk()
		_catalog = rm.research_catalog
	_clamp_selection()
	_refresh()
	_flash("Saved research catalog.", true)


func save_as(path: String) -> void:
	var data: ResearchData = _find(_selected_id)
	if data == null:
		_flash("No node selected.", false)
		return
	var err: Error = ResearchDesignerIO.save_as(data, path)
	if err != OK:
		_flash("Save As failed: %s" % error_string(err), false)
		return
	_flash("Saved %s" % path, true)


func undo() -> void:
	if not _history.can_undo():
		return
	_catalog = _history.undo(_catalog)
	ResearchDesignerHistory.restore_paths(_catalog)
	_sync_manager()
	_clamp_selection()
	_refresh()


func redo() -> void:
	if not _history.can_redo():
		return
	_catalog = _history.redo(_catalog)
	ResearchDesignerHistory.restore_paths(_catalog)
	_sync_manager()
	_clamp_selection()
	_refresh()


func _clamp_selection() -> void:
	if _find(_selected_id) != null:
		return
	_selected_id = _catalog[0].research_id if not _catalog.is_empty() and _catalog[0] != null else &""


func _push_history(label: String) -> void:
	_history.push(label, _catalog)


func _unique_id(base: StringName) -> StringName:
	var root: String = String(base)
	if root.is_empty():
		root = "research"
	var candidate: StringName = StringName(root)
	var n: int = 2
	while _find(candidate) != null:
		candidate = StringName("%s_%d" % [root, n])
		n += 1
	return candidate


func _find(research_id: StringName) -> ResearchData:
	for data: ResearchData in _catalog:
		if data != null and data.research_id == research_id:
			return data
	return null


func _status_text() -> String:
	var issues: Dictionary = ResearchValidation.issues_for_catalog(_catalog)
	if not issues.is_empty():
		var first: StringName = issues.keys()[0] as StringName
		var msgs: PackedStringArray = issues[first] as PackedStringArray
		return "%s: %s" % [String(first), msgs[0] if not msgs.is_empty() else "invalid"]
	var data: ResearchData = _find(_selected_id)
	if data == null:
		return "F4 Research Designer"
	return "%s  ·  %s" % [data.display_name, data.cost_label()]


func _status_ok() -> bool:
	return ResearchValidation.issues_for_catalog(_catalog).is_empty()


func _refresh() -> void:
	if ui == null:
		return
	ui.refresh(_catalog, _selected_id, _status_text(), _status_ok())


func _refresh_light() -> void:
	if ui == null:
		return
	ui.refresh_light(_catalog, _selected_id, _status_text(), _status_ok())


func _flash(text: String, ok: bool) -> void:
	if ui != null:
		ui.refresh_light(_catalog, _selected_id, text, ok)
