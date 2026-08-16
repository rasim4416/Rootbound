## Zoomable / pannable research graph. Connections write ResearchData.prerequisite_ids.
class_name ResearchGraph
extends Control

signal node_selected(research_id: StringName)
signal catalog_mutated()
signal history_commit()
signal status_message(text: String, ok: bool)
signal add_node_at(graph_position: Vector2)
signal duplicate_requested(research_id: StringName)
signal delete_requested(research_id: StringName)

var catalog: Array[ResearchData] = []
var selected_id: StringName = &""
var invalid_ids: Dictionary = {}

var _area: Control
var _nodes: Dictionary = {} ## StringName → ResearchGraphNode
var _zoom: float = 1.0
var _panning: bool = false
var _left_panning: bool = false
var _link_from: StringName = &""
var _link_mouse: Vector2 = Vector2.ZERO
var _selected_edge: Vector2i = Vector2i(-1, -1) ## packed as unused; use strings instead
var _edge_parent: StringName = &""
var _edge_child: StringName = &""
var _context: PopupMenu
var _context_node: StringName = &""
var _context_is_edge: bool = false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	_area = Control.new()
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_area)
	_context = PopupMenu.new()
	_context.id_pressed.connect(_on_context)
	add_child(_context)
	resized.connect(queue_redraw)
	set_process(true)
	set_process_input(true)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _link_from != &"":
		_link_mouse = get_local_mouse_position()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var over: bool = get_global_rect().has_point(get_global_mouse_position())
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed and over:
			_zoom_at(get_local_mouse_position(), 1.1)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed and over:
			_zoom_at(get_local_mouse_position(), 0.9)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed and not over:
				return
			_panning = mb.pressed
			if not mb.pressed and not _left_panning:
				mouse_default_cursor_shape = Control.CURSOR_MOVE
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _left_panning:
				_left_panning = false
				_panning = false
				mouse_default_cursor_shape = Control.CURSOR_MOVE
			if _link_from != &"":
				var hit: StringName = _hit_input(_to_graph(get_local_mouse_position()))
				if hit != &"":
					_try_connect(_link_from, hit)
				_link_from = &""
				queue_redraw()
	elif event is InputEventMouseMotion and _panning:
		var mm := event as InputEventMouseMotion
		_area.position += mm.relative
		get_viewport().set_input_as_handled()


func set_catalog(entries: Array[ResearchData], selected: StringName, issues: Dictionary) -> void:
	catalog = entries
	selected_id = selected
	invalid_ids = issues
	if _ids_match():
		_update_nodes()
	else:
		_rebuild_nodes()
	queue_redraw()


func _ids_match() -> bool:
	if _nodes.size() != _count_valid():
		return false
	for data: ResearchData in catalog:
		if data == null or data.research_id == &"":
			continue
		if not _nodes.has(data.research_id):
			return false
	return true


func _count_valid() -> int:
	var n: int = 0
	for data: ResearchData in catalog:
		if data != null and data.research_id != &"":
			n += 1
	return n


func _update_nodes() -> void:
	for data: ResearchData in catalog:
		if data == null or data.research_id == &"":
			continue
		var node: ResearchGraphNode = _nodes.get(data.research_id, null) as ResearchGraphNode
		if node == null:
			continue
		if node.is_dragging():
			continue
		node.setup(data, invalid_ids.has(data.research_id), data.research_id == selected_id)


func focus_node(research_id: StringName) -> void:
	var node: ResearchGraphNode = _nodes.get(research_id, null) as ResearchGraphNode
	if node == null:
		return
	selected_id = research_id
	var center: Vector2 = node.position + node.size * 0.5
	var target: Vector2 = size * 0.5 - center * _zoom
	_area.position = target
	_area.scale = Vector2(_zoom, _zoom)
	_refresh_selected_visual()
	queue_redraw()


func fit_tree() -> void:
	if catalog.is_empty():
		_zoom = 1.0
		_area.position = Vector2.ZERO
		_area.scale = Vector2.ONE
		return
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for data: ResearchData in catalog:
		if data == null:
			continue
		min_p = min_p.min(data.editor_position)
		max_p = max_p.max(data.editor_position + ResearchGraphNode.SIZE)
	var bounds: Vector2 = (max_p - min_p).max(Vector2(160, 80))
	var view: Vector2 = size.max(Vector2(80, 80))
	_zoom = clampf(minf((view.x - 40.0) / bounds.x, (view.y - 40.0) / bounds.y), 0.35, 1.4)
	_area.scale = Vector2(_zoom, _zoom)
	var mid: Vector2 = (min_p + max_p) * 0.5
	_area.position = view * 0.5 - mid * _zoom
	queue_redraw()


func clear_edge_selection() -> void:
	_edge_parent = &""
	_edge_child = &""
	queue_redraw()


func has_edge_selection() -> bool:
	return _edge_parent != &"" and _edge_child != &""


func remove_selected_edge() -> bool:
	if not has_edge_selection():
		return false
	var child: ResearchData = _find(_edge_child)
	if child == null:
		return false
	var idx: int = child.prerequisite_ids.find(_edge_parent)
	if idx < 0:
		return false
	child.prerequisite_ids.remove_at(idx)
	clear_edge_selection()
	catalog_mutated.emit()
	history_commit.emit()
	return true


func _rebuild_nodes() -> void:
	if _area == null:
		return
	for id: Variant in _nodes.keys():
		var n: ResearchGraphNode = _nodes[id] as ResearchGraphNode
		if n != null:
			_area.remove_child(n)
			n.queue_free()
	_nodes.clear()
	for data: ResearchData in catalog:
		if data == null or data.research_id == &"":
			continue
		var node := ResearchGraphNode.new()
		var is_invalid: bool = invalid_ids.has(data.research_id)
		node.setup(data, is_invalid, data.research_id == selected_id)
		node.selected.connect(_on_node_selected)
		node.moved.connect(_on_node_moved)
		node.move_ended.connect(func() -> void: history_commit.emit())
		node.output_drag_started.connect(_on_output_drag)
		node.input_released.connect(_on_input_released)
		node.context_requested.connect(_on_node_context)
		_area.add_child(node)
		_nodes[data.research_id] = node


func _refresh_selected_visual() -> void:
	for id: Variant in _nodes.keys():
		var n: ResearchGraphNode = _nodes[id] as ResearchGraphNode
		if n == null:
			continue
		var data: ResearchData = _find(id as StringName)
		n.setup(data, invalid_ids.has(id), id == selected_id)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _try_select_edge(mb.position):
					accept_event()
					return
				clear_edge_selection()
				_left_panning = true
				_panning = true
				mouse_default_cursor_shape = Control.CURSOR_DRAG
				accept_event()
			else:
				if _left_panning:
					_left_panning = false
					_panning = false
					mouse_default_cursor_shape = Control.CURSOR_MOVE
				if _link_from != &"":
					var hit: StringName = _hit_input(_to_graph(mb.position))
					if hit != &"":
						_try_connect(_link_from, hit)
					_link_from = &""
					queue_redraw()
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _try_select_edge(mb.position):
				_open_edge_context(mb.global_position)
			else:
				_open_empty_context(mb.global_position, _to_graph(mb.position))
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _link_from != &"":
			_link_mouse = mm.position
			queue_redraw()


func _zoom_at(cursor: Vector2, factor: float) -> void:
	var old: float = _zoom
	_zoom = clampf(_zoom * factor, 0.35, 2.4)
	var graph_pt: Vector2 = (cursor - _area.position) / maxf(old, 0.001)
	_area.scale = Vector2(_zoom, _zoom)
	_area.position = cursor - graph_pt * _zoom
	queue_redraw()


func _to_graph(local: Vector2) -> Vector2:
	return (local - _area.position) / maxf(_zoom, 0.001)


func _on_node_selected(research_id: StringName) -> void:
	selected_id = research_id
	clear_edge_selection()
	_refresh_selected_visual()
	node_selected.emit(research_id)


func _on_node_moved(research_id: StringName, pos: Vector2) -> void:
	var data: ResearchData = _find(research_id)
	if data != null:
		data.editor_position = pos
	catalog_mutated.emit()


func _on_output_drag(research_id: StringName) -> void:
	_link_from = research_id
	_link_mouse = _area.position + (_nodes[research_id] as ResearchGraphNode).position * _zoom + (_nodes[research_id] as ResearchGraphNode).output_pos() * _zoom


func _on_input_released(research_id: StringName) -> void:
	if _link_from == &"":
		return
	_try_connect(_link_from, research_id)
	_link_from = &""
	queue_redraw()


func _try_connect(parent_id: StringName, child_id: StringName) -> void:
	if parent_id == &"" or child_id == &"":
		return
	if parent_id == child_id:
		status_message.emit("Invalid connection", false)
		return
	var child: ResearchData = _find(child_id)
	if child == null or _find(parent_id) == null:
		status_message.emit("Invalid connection", false)
		return
	if child.prerequisite_ids.has(parent_id):
		status_message.emit("Invalid connection", false)
		return
	if ResearchValidation.would_cycle(catalog, parent_id, child_id):
		status_message.emit("Invalid circular dependency", false)
		return
	child.prerequisite_ids.append(parent_id)
	catalog_mutated.emit()
	history_commit.emit()


func _on_node_context(research_id: StringName) -> void:
	_context_node = research_id
	_context_is_edge = false
	_context.clear()
	_context.add_item("Add Research Node", 0)
	_context.add_item("Duplicate", 1)
	_context.add_item("Delete", 2)
	_context.position = Vector2i(get_viewport().get_mouse_position())
	_context.popup()


func _open_empty_context(global_pos: Vector2, graph_pos: Vector2) -> void:
	_context_node = &""
	_context_is_edge = false
	_context.set_meta("graph_pos", graph_pos)
	_context.clear()
	_context.add_item("Add Research Node", 0)
	_context.position = Vector2i(global_pos)
	_context.popup()


func _open_edge_context(global_pos: Vector2) -> void:
	_context_is_edge = true
	_context.clear()
	_context.add_item("Remove Connection", 10)
	_context.position = Vector2i(global_pos)
	_context.popup()


func _on_context(id: int) -> void:
	match id:
		0:
			var pos: Vector2 = _context.get_meta("graph_pos", Vector2(80, 80)) as Vector2
			if _context_node != &"":
				var n: ResearchGraphNode = _nodes.get(_context_node, null) as ResearchGraphNode
				if n != null:
					pos = n.position + Vector2(40, 90)
			add_node_at.emit(pos)
		1:
			if _context_node != &"":
				duplicate_requested.emit(_context_node)
		2:
			if _context_node != &"":
				delete_requested.emit(_context_node)
		10:
			remove_selected_edge()


func _try_select_edge(local: Vector2) -> bool:
	var graph_pt: Vector2 = _to_graph(local)
	var best_d: float = 12.0
	var best_p: StringName = &""
	var best_c: StringName = &""
	for data: ResearchData in catalog:
		if data == null:
			continue
		var child_n: ResearchGraphNode = _nodes.get(data.research_id, null) as ResearchGraphNode
		if child_n == null:
			continue
		for parent_id: StringName in data.prerequisite_ids:
			var parent_n: ResearchGraphNode = _nodes.get(parent_id, null) as ResearchGraphNode
			if parent_n == null:
				continue
			var a: Vector2 = parent_n.position + parent_n.output_pos()
			var b: Vector2 = child_n.position + child_n.input_pos()
			var d: float = _dist_to_segment(graph_pt, a, b)
			if d < best_d:
				best_d = d
				best_p = parent_id
				best_c = data.research_id
	if best_p == &"":
		return false
	_edge_parent = best_p
	_edge_child = best_c
	queue_redraw()
	return true


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = 0.0 if ab.length_squared() < 0.001 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.10, 1.0), true)
	var xform: Transform2D = get_global_transform_with_canvas().affine_inverse() * _area.get_global_transform_with_canvas()
	for data: ResearchData in catalog:
		if data == null:
			continue
		var child_n: ResearchGraphNode = _nodes.get(data.research_id, null) as ResearchGraphNode
		if child_n == null:
			continue
		for parent_id: StringName in data.prerequisite_ids:
			var parent_n: ResearchGraphNode = _nodes.get(parent_id, null) as ResearchGraphNode
			if parent_n == null:
				continue
			var from_pt: Vector2 = xform * (parent_n.position + parent_n.output_pos())
			var to_pt: Vector2 = xform * (child_n.position + child_n.input_pos())
			var col := Color(0.55, 0.8, 0.95, 0.85)
			if parent_id == _edge_parent and data.research_id == _edge_child:
				col = Color(1.0, 0.55, 0.35, 1.0)
			draw_line(from_pt, to_pt, col, 2.5, true)
	if _link_from != &"" and _nodes.has(_link_from):
		var src: ResearchGraphNode = _nodes[_link_from] as ResearchGraphNode
		var from_pt2: Vector2 = xform * (src.position + src.output_pos())
		draw_line(from_pt2, _link_mouse, Color(1.0, 0.85, 0.35, 0.9), 2.0, true)


func _hit_input(graph_pt: Vector2) -> StringName:
	for id: Variant in _nodes.keys():
		var node: ResearchGraphNode = _nodes[id] as ResearchGraphNode
		if node == null:
			continue
		var local: Vector2 = graph_pt - node.position
		if local.x >= -8.0 and local.x <= 24.0 and local.y >= 0.0 and local.y <= node.size.y:
			return id as StringName
	return &""


func _find(research_id: StringName) -> ResearchData:
	for data: ResearchData in catalog:
		if data != null and data.research_id == research_id:
			return data
	return null
