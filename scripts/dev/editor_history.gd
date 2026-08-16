## Simple command stack for Dev Editor undo / redo.
class_name EditorHistory
extends RefCounted

signal changed()

const MAX_STACK: int = 64

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []


func clear() -> void:
	_undo.clear()
	_redo.clear()
	changed.emit()


func push_snapshot(label: String, map: EditorMapData) -> void:
	if map == null:
		return
	_undo.append({"label": label, "map": map.clone_deep()})
	if _undo.size() > MAX_STACK:
		_undo.pop_front()
	_redo.clear()
	changed.emit()


func can_undo() -> bool:
	return _undo.size() > 1


func can_redo() -> bool:
	return not _redo.is_empty()


## Restores previous snapshot; current must already be pushed.
func undo(current: EditorMapData) -> EditorMapData:
	if not can_undo():
		return current
	_redo.append({"label": "redo", "map": current.clone_deep()})
	_undo.pop_back()
	var entry: Dictionary = _undo[_undo.size() - 1]
	changed.emit()
	return (entry["map"] as EditorMapData).clone_deep()


func redo(current: EditorMapData) -> EditorMapData:
	if not can_redo():
		return current
	_undo.append({"label": "undo", "map": current.clone_deep()})
	var entry: Dictionary = _redo.pop_back()
	changed.emit()
	return (entry["map"] as EditorMapData).clone_deep()
