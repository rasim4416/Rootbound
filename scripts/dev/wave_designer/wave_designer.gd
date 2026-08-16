## F2 Wave Designer. Debug/editor builds only. Shares EditorMapData with DevEditor.
class_name WaveDesigner
extends Node

@export var wave_manager: WaveManager
@export var ui: WaveDesignerUI

var is_active: bool = false
var is_testing: bool = false

var _map: EditorMapData
var _history: WaveDesignerHistory = WaveDesignerHistory.new()
var _active_wave: int = 0
var _active_group: int = 0
var _dev_was_active: bool = false
var _test_elapsed: float = 0.0


func _ready() -> void:
	add_to_group("wave_designer")
	set_process(false)
	set_process_unhandled_input(true)
	if not _is_allowed():
		set_process_unhandled_input(false)
		return
	if ui != null:
		ui.set_active(false)
		_connect_ui()


func _is_allowed() -> bool:
	return OS.is_debug_build() or OS.has_feature("editor")


func _close_research_designer() -> void:
	if get_tree() == null:
		return
	for n: Node in get_tree().get_nodes_in_group("research_designer"):
		if n.has_method("set_active"):
			n.call("set_active", false)


func _connect_ui() -> void:
	ui.new_wave_pressed.connect(add_wave)
	ui.duplicate_wave_pressed.connect(duplicate_wave)
	ui.delete_wave_pressed.connect(delete_wave)
	ui.add_ten_pressed.connect(add_ten_waves)
	ui.move_wave_up_pressed.connect(func() -> void: move_wave(-1))
	ui.move_wave_down_pressed.connect(func() -> void: move_wave(1))
	ui.add_group_pressed.connect(add_group)
	ui.duplicate_group_pressed.connect(duplicate_group)
	ui.delete_group_pressed.connect(delete_group)
	ui.move_group_up_pressed.connect(func() -> void: move_group(-1))
	ui.move_group_down_pressed.connect(func() -> void: move_group(1))
	ui.undo_pressed.connect(undo)
	ui.redo_pressed.connect(redo)
	ui.test_pressed.connect(test_selected_wave)
	ui.test_from_here_pressed.connect(test_from_here)
	ui.stop_pressed.connect(stop_test)
	ui.save_pressed.connect(save_map)
	ui.scale_selected_requested.connect(scale_selected)
	ui.scale_waves_requested.connect(scale_waves_range)
	ui.add_event_pressed.connect(add_special_event)
	ui.delete_event_pressed.connect(delete_special_event)
	ui.wave_index_selected.connect(func(i: int) -> void:
		if i == _active_wave:
			return
		_active_wave = i
		_active_group = 0
		_refresh()
	)
	ui.group_index_selected.connect(func(i: int) -> void:
		if i == _active_group:
			return
		_active_group = i
		_refresh()
	)
	ui.inspector_changed.connect(func() -> void:
		_push_history("inspector")
		_refresh_light()
	)
	ui.inspector_live_changed.connect(_refresh_light)
	ui.timeline_changed.connect(_refresh_light)
	ui.rename_wave_requested.connect(func(i: int) -> void:
		_active_wave = i
		_active_group = 0
		_refresh()
		var w: WaveData = _current_wave()
		if w != null and ui != null:
			ui.prompt_rename(w.display_name if not w.display_name.is_empty() else "Wave %d" % w.wave_number)
	)
	ui.context_test_requested.connect(func(i: int) -> void:
		_active_wave = i
		test_selected_wave()
	)


func _process(delta: float) -> void:
	if not is_testing or wave_manager == null or ui == null:
		return
	_test_elapsed += delta
	var stats: Dictionary = wave_manager.get_dev_spawn_stats()
	ui.set_live_hud(
		"Spawned %d  ·  Alive %d  ·  Killed %d  ·  Remaining %d  ·  Time %.1fs"
		% [
			int(stats.get("spawned", 0)),
			int(stats.get("alive", 0)),
			int(stats.get("killed", 0)),
			int(stats.get("remaining", 0)),
			_test_elapsed,
		],
		true
	)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_allowed() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_F2:
		set_active(not is_active)
		get_viewport().set_input_as_handled()
		return
	if not is_active:
		return
	match key.keycode:
		KEY_ESCAPE:
			set_active(false)
			get_viewport().set_input_as_handled()
		KEY_UP:
			_active_wave = maxi(_active_wave - 1, 0)
			_active_group = 0
			_refresh()
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			if _map != null:
				_active_wave = mini(_active_wave + 1, maxi(_map.waves.size() - 1, 0))
			_active_group = 0
			_refresh()
			get_viewport().set_input_as_handled()
		KEY_D:
			if key.ctrl_pressed:
				duplicate_wave()
				get_viewport().set_input_as_handled()
		KEY_S:
			if key.ctrl_pressed:
				save_map()
				get_viewport().set_input_as_handled()
		KEY_Z:
			if key.ctrl_pressed:
				undo()
				get_viewport().set_input_as_handled()
		KEY_Y:
			if key.ctrl_pressed:
				redo()
				get_viewport().set_input_as_handled()
		KEY_SPACE:
			test_selected_wave()
			get_viewport().set_input_as_handled()
		KEY_DELETE:
			if _has_groups() and _active_group >= 0:
				delete_group()
			else:
				delete_wave()
			get_viewport().set_input_as_handled()


func set_active(active: bool) -> void:
	if not _is_allowed():
		return
	if is_active == active:
		return
	is_active = active
	if is_active:
		_close_research_designer()
		_enter()
	else:
		_exit()


func _enter() -> void:
	_bind_map()
	_history.clear()
	_push_history("enter")
	_suspend_dev_editor(true)
	if ui != null:
		ui.set_active(true)
	_refresh()


func _exit() -> void:
	if is_testing:
		stop_test()
	if ui != null:
		ui.set_active(false)
	_suspend_dev_editor(false)


func _dev_editor() -> DevEditor:
	if get_tree() == null:
		return null
	for n: Node in get_tree().get_nodes_in_group("dev_editor"):
		if n is DevEditor:
			return n as DevEditor
	return null


func _bind_map() -> void:
	var dev: DevEditor = _dev_editor()
	if dev != null:
		_map = dev.get_or_bootstrap_map()
	if _map == null:
		_map = EditorMapData.new()
	_active_wave = clampi(_active_wave, 0, maxi(_map.waves.size() - 1, 0))
	_active_group = 0


func _suspend_dev_editor(blocked: bool) -> void:
	var dev: DevEditor = _dev_editor()
	if dev == null:
		return
	if blocked:
		_dev_was_active = dev.is_active
		dev.set_blocked_by_wave_designer(true)
	else:
		dev.set_blocked_by_wave_designer(false)
		if _dev_was_active and not dev.is_playtesting:
			dev.set_active(true)
		_dev_was_active = false


func _current_wave() -> WaveData:
	if _map == null or _active_wave < 0 or _active_wave >= _map.waves.size():
		return null
	return _map.waves[_active_wave]


func _has_groups() -> bool:
	var w: WaveData = _current_wave()
	return w != null and not w.spawn_entries.is_empty()


func _default_insect() -> InsectData:
	var ids: Array[StringName] = _map.available_enemy_ids if _map != null else []
	var id: StringName = ids[0] if not ids.is_empty() else &"ant"
	return WaveDesignerUI.load_insect(id)


func _default_path_id() -> StringName:
	if _map != null and not _map.paths.is_empty() and _map.paths[0] != null:
		return _map.paths[0].path_id
	return &""


func add_ten_waves() -> void:
	if _map == null:
		return
	for _i: int in range(10):
		_create_wave(false)
	_push_history("add_10")
	_refresh()


func _create_wave(record_history: bool) -> void:
	if _map == null:
		return
	var w := WaveData.new()
	w.wave_number = _map.waves.size() + 1
	w.display_name = "Wave %d" % w.wave_number
	w.spawn_interval = 1.0
	w.path_id = _default_path_id()
	w.insect_data = _default_insect()
	var g := WaveSpawnEntry.new()
	g.insect_data = w.insect_data
	g.count = 5
	g.start_time = 0.0
	g.spawn_interval = -1.0
	g.path_id = w.path_id
	w.spawn_entries.append(g)
	_map.waves.append(w)
	_active_wave = _map.waves.size() - 1
	_active_group = 0
	if record_history:
		_push_history("add_wave")
		_refresh()


func add_wave() -> void:
	_create_wave(true)


func duplicate_wave() -> void:
	var src: WaveData = _current_wave()
	if src == null:
		return
	var copy: WaveData = src.duplicate(true) as WaveData
	copy.wave_number = _map.waves.size() + 1
	if copy.display_name.is_empty():
		copy.display_name = "Wave %d" % copy.wave_number
	else:
		copy.display_name = copy.display_name + " Copy"
	_map.waves.append(copy)
	_active_wave = _map.waves.size() - 1
	_push_history("dup_wave")
	_refresh()


func delete_wave() -> void:
	if _map == null or _map.waves.is_empty():
		return
	_map.waves.remove_at(_active_wave)
	_active_wave = clampi(_active_wave, 0, maxi(_map.waves.size() - 1, 0))
	_active_group = 0
	_push_history("del_wave")
	_refresh()


func move_wave(delta: int) -> void:
	if _map == null:
		return
	var dest: int = _active_wave + delta
	if dest < 0 or dest >= _map.waves.size():
		return
	var tmp: WaveData = _map.waves[_active_wave]
	_map.waves[_active_wave] = _map.waves[dest]
	_map.waves[dest] = tmp
	_active_wave = dest
	_renumber()
	_push_history("move_wave")
	_refresh()


func _renumber() -> void:
	if _map == null:
		return
	for i: int in range(_map.waves.size()):
		if _map.waves[i] != null:
			_map.waves[i].wave_number = i + 1


func add_group() -> void:
	var w: WaveData = _current_wave()
	if w == null:
		add_wave()
		w = _current_wave()
	if w == null:
		return
	var g := WaveSpawnEntry.new()
	g.insect_data = _default_insect()
	g.count = 5
	g.start_time = 0.0
	g.spawn_interval = -1.0
	g.path_id = w.path_id
	w.spawn_entries.append(g)
	_active_group = w.spawn_entries.size() - 1
	_push_history("add_group")
	_refresh()


func duplicate_group() -> void:
	var w: WaveData = _current_wave()
	if w == null or _active_group < 0 or _active_group >= w.spawn_entries.size():
		return
	var copy: WaveSpawnEntry = w.spawn_entries[_active_group].duplicate(true) as WaveSpawnEntry
	w.spawn_entries.append(copy)
	_active_group = w.spawn_entries.size() - 1
	_push_history("dup_group")
	_refresh()


func delete_group() -> void:
	var w: WaveData = _current_wave()
	if w == null or w.spawn_entries.is_empty():
		return
	w.spawn_entries.remove_at(_active_group)
	_active_group = clampi(_active_group, 0, maxi(w.spawn_entries.size() - 1, 0))
	_push_history("del_group")
	_refresh()


func move_group(delta: int) -> void:
	var w: WaveData = _current_wave()
	if w == null:
		return
	var dest: int = _active_group + delta
	if dest < 0 or dest >= w.spawn_entries.size():
		return
	var tmp: WaveSpawnEntry = w.spawn_entries[_active_group]
	w.spawn_entries[_active_group] = w.spawn_entries[dest]
	w.spawn_entries[dest] = tmp
	_active_group = dest
	_push_history("move_group")
	_refresh()


func add_special_event() -> void:
	var w: WaveData = _current_wave()
	if w == null:
		return
	var ev := WaveSpecialEvent.new()
	ev.kind = WaveSpecialEvent.Kind.BOSS_SPAWN
	ev.time = 0.0
	if _active_group >= 0 and _active_group < w.spawn_entries.size() and w.spawn_entries[_active_group] != null:
		ev.time = maxf(w.spawn_entries[_active_group].start_time, 0.0)
	ev.label = ""
	w.special_events.append(ev)
	if ui != null:
		ui.set_active_event(w.special_events.size() - 1)
	_push_history("add_event")
	_refresh()


func delete_special_event() -> void:
	var w: WaveData = _current_wave()
	if w == null or w.special_events.is_empty():
		return
	var idx: int = ui.get_active_event() if ui != null else -1
	if idx < 0 or idx >= w.special_events.size():
		idx = w.special_events.size() - 1
	w.special_events.remove_at(idx)
	var next: int = clampi(idx, 0, maxi(w.special_events.size() - 1, 0))
	if w.special_events.is_empty():
		next = -1
	if ui != null:
		ui.set_active_event(next)
	_push_history("del_event")
	_refresh()


func scale_selected(percent: float) -> void:
	if _map == null or ui == null:
		return
	var factor: float = 1.0 + percent / 100.0
	var indices: PackedInt32Array = ui.get_selected_wave_indices()
	if indices.is_empty():
		return
	for i: int in indices:
		if i < 0 or i >= _map.waves.size() or _map.waves[i] == null:
			continue
		var w: WaveData = _map.waves[i]
		w.hp_multiplier = maxf(w.hp_multiplier * factor, 0.01)
		w.speed_multiplier = maxf(w.speed_multiplier * factor, 0.01)
		w.core_damage_multiplier = maxf(w.core_damage_multiplier * factor, 0.01)
		w.reward_bonus = maxi(int(round(float(w.reward_bonus) * factor)), 0)
	_push_history("scale_selected")
	_refresh()


func scale_waves_range(index_a: int, index_b: int, start_mult: float, end_mult: float) -> void:
	if _map == null or _map.waves.is_empty():
		return
	var a: int = clampi(mini(index_a, index_b), 0, _map.waves.size() - 1)
	var b: int = clampi(maxi(index_a, index_b), 0, _map.waves.size() - 1)
	var wa: WaveData = _map.waves[a]
	var wb: WaveData = _map.waves[b]
	var reward_a: float = float(wa.reward_bonus) if wa != null else 0.0
	var reward_b: float = float(wb.reward_bonus) if wb != null else 0.0
	var span: int = maxi(b - a, 1)
	for i: int in range(a, b + 1):
		var w: WaveData = _map.waves[i]
		if w == null:
			continue
		var t: float = 0.0 if a == b else float(i - a) / float(span)
		var m: float = lerpf(start_mult, end_mult, t)
		w.hp_multiplier = maxf(m, 0.01)
		w.speed_multiplier = maxf(m, 0.01)
		w.core_damage_multiplier = maxf(m, 0.01)
		w.reward_bonus = maxi(int(round(lerpf(reward_a, reward_b, t))), 0)
	_push_history("scale_waves")
	_refresh()


func test_selected_wave() -> void:
	var w: WaveData = _current_wave()
	if w == null or wave_manager == null:
		_flash("No wave to test.", false)
		return
	if WaveDesignerStats.enemy_count(w) <= 0:
		_flash("Wave has no enemies.", false)
		return
	var main: Node = get_parent()
	if not EditorMapApplier.apply(_map, main):
		_flash("Apply map failed (need a valid path).", false)
		return
	_begin_test(w.wave_number, "Testing wave %d." % w.wave_number)


func test_from_here() -> void:
	var w: WaveData = _current_wave()
	if w == null or wave_manager == null:
		_flash("No wave to test.", false)
		return
	if _map == null:
		return
	if _active_group < 0 or _active_group >= w.spawn_entries.size():
		test_selected_wave()
		return
	var t0: float = maxf(w.spawn_entries[_active_group].start_time, 0.0)
	var clone: EditorMapData = _map.clone_deep()
	if _active_wave < 0 or _active_wave >= clone.waves.size() or clone.waves[_active_wave] == null:
		_flash("Clone failed.", false)
		return
	var cw: WaveData = clone.waves[_active_wave]
	cw.delay_before_wave = 0.0
	var kept: Array[WaveSpawnEntry] = []
	for e: WaveSpawnEntry in cw.spawn_entries:
		if e == null or e.insect_data == null:
			continue
		var interval: float = e.resolve_interval(cw.spawn_interval)
		var new_count: int = 0
		var new_start: float = -1.0
		for i: int in range(maxi(e.count, 0)):
			var at: float = maxf(e.start_time, 0.0) + float(i) * interval
			if at + 0.0001 < t0:
				continue
			if new_start < 0.0:
				new_start = at - t0
			new_count += 1
		if new_count <= 0:
			continue
		var copy: WaveSpawnEntry = e.duplicate(true) as WaveSpawnEntry
		copy.count = new_count
		copy.start_time = maxf(new_start, 0.0)
		copy.spawn_interval = interval
		kept.append(copy)
	cw.spawn_entries = kept
	var evs: Array[WaveSpecialEvent] = []
	for ev: WaveSpecialEvent in cw.special_events:
		if ev == null or ev.time + 0.0001 < t0:
			continue
		var ec: WaveSpecialEvent = ev.duplicate(true) as WaveSpecialEvent
		ec.time = maxf(ev.time - t0, 0.0)
		evs.append(ec)
	cw.special_events = evs
	if WaveDesignerStats.enemy_count(cw) <= 0:
		_flash("Nothing to spawn from here.", false)
		return
	var main: Node = get_parent()
	if not EditorMapApplier.apply(clone, main):
		_flash("Apply map failed (need a valid path).", false)
		return
	_begin_test(cw.wave_number, "Testing from t=%.1fs." % t0)


func _begin_test(wave_number: int, message: String) -> void:
	wave_manager.stop_test_for_dev()
	is_testing = true
	_test_elapsed = 0.0
	set_process(true)
	wave_manager.start_authored_wave_number(wave_number)
	_flash(message, true)


func stop_test() -> void:
	is_testing = false
	set_process(false)
	if wave_manager != null:
		wave_manager.stop_test_for_dev()
	if ui != null:
		ui.set_live_hud("", false)
	_flash("Test stopped.", true)


func save_map() -> void:
	if _map == null:
		return
	var err: Error = MapSerializer.save(_map, true)
	if err != OK:
		_flash("Save failed: %s" % error_string(err), false)
		return
	_flash("Saved %s" % MapSerializer.user_path(_map.map_id), true)


func _push_history(label: String) -> void:
	_history.push(label, _map)


func undo() -> void:
	if not _history.can_undo():
		return
	_map = _history.undo(_map)
	_sync_map_to_dev()
	_refresh()


func redo() -> void:
	if not _history.can_redo():
		return
	_map = _history.redo(_map)
	_sync_map_to_dev()
	_refresh()


func _sync_map_to_dev() -> void:
	var dev: DevEditor = _dev_editor()
	if dev != null:
		dev.replace_map(_map)


func _refresh() -> void:
	if ui == null:
		return
	var w: WaveData = _current_wave()
	var ok: bool = w != null and WaveDesignerStats.enemy_count(w) > 0
	var status: String = "F2 Wave Designer"
	if w != null:
		var warns: PackedStringArray = WaveDesignerStats.warnings(w, _path_ids())
		if not warns.is_empty():
			status = warns[0]
			ok = WaveDesignerStats.enemy_count(w) > 0
		else:
			status = "Wave %d  ·  %d enemies  ·  %.1fs" % [
				w.wave_number,
				WaveDesignerStats.enemy_count(w),
				WaveDesignerStats.estimated_duration(w)
			]
	ui.refresh(_map, _active_wave, _active_group, status, ok)


func _refresh_light() -> void:
	if ui == null:
		return
	var w: WaveData = _current_wave()
	var ok: bool = w != null and WaveDesignerStats.enemy_count(w) > 0
	var status: String = "Edited"
	if w != null:
		status = "Wave %d  ·  %d enemies  ·  %.1fs" % [
			w.wave_number, WaveDesignerStats.enemy_count(w), WaveDesignerStats.estimated_duration(w)
		]
	ui.refresh_light(_map, _active_wave, _active_group, status, ok)


func _path_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if _map == null:
		return ids
	for p: EditorPathData in _map.paths:
		if p != null:
			ids.append(p.path_id)
	return ids


func _flash(text: String, ok: bool) -> void:
	if ui != null:
		ui.refresh_light(_map, _active_wave, _active_group, text, ok)
