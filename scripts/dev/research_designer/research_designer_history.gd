## Undo stack for Research Designer (snapshots of the ResearchData catalog).
class_name ResearchDesignerHistory
extends RefCounted

signal changed()

const MAX_STACK: int = 64

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []


func clear() -> void:
	_undo.clear()
	_redo.clear()
	changed.emit()


func push(label: String, catalog: Array[ResearchData]) -> void:
	_undo.append({"label": label, "catalog": clone_catalog(catalog)})
	if _undo.size() > MAX_STACK:
		_undo.pop_front()
	_redo.clear()
	changed.emit()


func can_undo() -> bool:
	return _undo.size() > 1


func can_redo() -> bool:
	return not _redo.is_empty()


func undo(current: Array[ResearchData]) -> Array[ResearchData]:
	if not can_undo():
		return current
	_redo.append({"label": "redo", "catalog": clone_catalog(current)})
	_undo.pop_back()
	var entry: Dictionary = _undo[_undo.size() - 1]
	changed.emit()
	return clone_catalog(entry["catalog"] as Array)


func redo(current: Array[ResearchData]) -> Array[ResearchData]:
	if not can_redo():
		return current
	_undo.append({"label": "undo", "catalog": clone_catalog(current)})
	var entry: Dictionary = _redo.pop_back()
	changed.emit()
	return clone_catalog(entry["catalog"] as Array)


static func clone_catalog(src: Array) -> Array[ResearchData]:
	var out: Array[ResearchData] = []
	for item: Variant in src:
		var data := item as ResearchData
		if data == null:
			continue
		var copy: ResearchData = data.duplicate(true) as ResearchData
		var path: String = data.resource_path
		if path.is_empty() and data.has_meta("source_path"):
			path = String(data.get_meta("source_path"))
		if not path.is_empty():
			copy.set_meta("source_path", path)
		out.append(copy)
	return out


static func restore_paths(catalog: Array[ResearchData]) -> void:
	for data: ResearchData in catalog:
		if data == null:
			continue
		var path: String = data.resource_path
		if path.is_empty() and data.has_meta("source_path"):
			path = String(data.get_meta("source_path"))
		if not path.is_empty():
			data.take_over_path(path)
