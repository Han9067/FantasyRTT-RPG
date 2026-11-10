class_name WorldNavigation
extends RefCounted
## Static tile navigation. Build once; only query A* when a move order is issued.
var grid := AStarGrid2D.new()
var grid_size := Vector2i.ZERO
var cell_size := Vector2(32,32)
var components := PackedInt32Array()

func configure(data: Dictionary) -> void:
	grid = AStarGrid2D.new()
	grid_size = Vector2i(data.grid_size[0],data.grid_size[1])
	cell_size = Vector2(data.cell_size[0],data.cell_size[1])
	grid.region = Rect2i(Vector2i.ZERO,grid_size)
	grid.cell_size = cell_size
	grid.offset = cell_size*0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for cell in data.blocked: grid.set_point_solid(Vector2i(cell[0],cell[1]))
	# Four-neighbour components have the same connectivity as no-corner-cut diagonals.
	# This makes hover/reachability checks constant-time, with no per-frame path search.
	components.resize(grid_size.x*grid_size.y)
	components.fill(-1)
	var component := 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var start := Vector2i(x,y)
			if not open_cell(start) or components[index(start)] != -1: continue
			var pending: Array[Vector2i] = [start]
			components[index(start)] = component
			var i := 0
			while i < pending.size():
				var cell := pending[i]
				i += 1
				for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next: Vector2i = cell+step
					if not open_cell(next) or components[index(next)] != -1: continue
					components[index(next)] = component
					pending.append(next)
			component += 1

func index(cell: Vector2i) -> int:
	return cell.y*grid_size.x+cell.x

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i((point/cell_size).floor())

func open_cell(cell: Vector2i) -> bool:
	return grid.region.has_point(cell) and not grid.is_point_solid(cell)

func reachable(from: Vector2, target: Vector2) -> bool:
	var a := cell_at(from)
	var b := cell_at(target)
	return open_cell(a) and open_cell(b) and components[index(a)] == components[index(b)]

func segment_clear(from: Vector2, target: Vector2) -> bool:
	# Grid DDA visits every crossed tile; simultaneous boundary crossings also check
	# both adjacent tiles. Shortcuts cannot cut through blocked corners or thin cells.
	var cell := cell_at(from)
	var end := cell_at(target)
	if not open_cell(cell) or not open_cell(end): return false
	var start := from/cell_size
	var delta := (target-from)/cell_size
	var step := Vector2i(int(signf(delta.x)),int(signf(delta.y)))
	var tx := INF if delta.x == 0 else ((cell.x+1-start.x)/delta.x if delta.x>0 else (start.x-cell.x)/-delta.x)
	var ty := INF if delta.y == 0 else ((cell.y+1-start.y)/delta.y if delta.y>0 else (start.y-cell.y)/-delta.y)
	var dx := INF if delta.x == 0 else 1.0/absf(delta.x)
	var dy := INF if delta.y == 0 else 1.0/absf(delta.y)
	for _i in range(grid_size.x+grid_size.y+4):
		if cell == end: return true
		if absf(tx-ty)<0.000001:
			if not open_cell(cell+Vector2i(step.x,0)) or not open_cell(cell+Vector2i(0,step.y)): return false
			cell += step
			tx += dx
			ty += dy
		elif tx<ty:
			cell.x += step.x
			tx += dx
		else:
			cell.y += step.y
			ty += dy
		if not open_cell(cell): return false
	return false

func route(from: Vector2, target: Vector2) -> PackedVector2Array:
	if not reachable(from,target): return PackedVector2Array()
	if segment_clear(from,target): return PackedVector2Array([target])
	var raw := grid.get_point_path(cell_at(from),cell_at(target))
	if raw.is_empty(): return raw
	raw.append(target)
	var result := PackedVector2Array()
	var anchor := from
	var next := 0
	while next < raw.size():
		var furthest := next
		for i in range(raw.size()-1,next-1,-1):
			if segment_clear(anchor,raw[i]):
				furthest = i
				break
		if not segment_clear(anchor,raw[furthest]): return PackedVector2Array()
		if not anchor.is_equal_approx(raw[furthest]): result.append(raw[furthest])
		anchor = raw[furthest]
		next = furthest+1
	return result
