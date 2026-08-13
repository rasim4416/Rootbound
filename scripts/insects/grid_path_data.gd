## Ordered sequence of grid cells for pathogen movement.
##
## Create .tres files under data/paths/. GridPathFollower walks cell centers;
## Path2D / PathFollower are legacy and unused for normal gameplay.
class_name GridPathData
extends Resource

@export var path_id: StringName = &""

## Ordered cells from membrane entry to Nucleus.
@export var cells: Array[Vector2i] = []


func get_cell_count() -> int:
	return cells.size()


func get_cell(index: int) -> Vector2i:
	if index < 0 or index >= cells.size():
		return Vector2i(-1, -1)
	return cells[index]


## Validates bounds, no consecutive duplicates, and orthogonal adjacency.
## Returns true when valid; otherwise pushes errors and returns false.
func validate(grid: GridManager) -> bool:
	if grid == null:
		push_error("GridPathData '%s': GridManager is null." % path_id)
		return false
	if cells.size() < 2:
		push_error("GridPathData '%s': needs at least 2 cells." % path_id)
		return false

	for i: int in range(cells.size()):
		var cell: Vector2i = cells[i]
		if not grid.is_in_bounds(cell):
			push_error(
				"GridPathData '%s': cell %s at index %d is out of bounds."
				% [path_id, str(cell), i]
			)
			return false
		if i == 0:
			continue
		var prev: Vector2i = cells[i - 1]
		if prev == cell:
			push_error(
				"GridPathData '%s': consecutive duplicate cell %s at index %d."
				% [path_id, str(cell), i]
			)
			return false
		var delta: Vector2i = cell - prev
		var manhattan: int = absi(delta.x) + absi(delta.y)
		if manhattan != 1:
			push_error(
				"GridPathData '%s': cells %s → %s are not orthogonally adjacent."
				% [path_id, str(prev), str(cell)]
			)
			return false

	return true


## Snapshot of path cells for visuals (copy — safe to mutate).
func get_cells_copy() -> Array[Vector2i]:
	var copy: Array[Vector2i] = []
	for cell: Vector2i in cells:
		copy.append(cell)
	return copy
