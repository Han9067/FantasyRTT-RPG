extends SceneTree
const Nav = preload("res://scripts/world_navigation.gd")

func assert_route(nav: WorldNavigation, start: Vector2, target: Vector2, path: PackedVector2Array) -> void:
	assert(not path.is_empty() and path[-1].is_equal_approx(target))
	var previous := start
	for point in path:
		assert(nav.segment_clear(previous,point), "Path cuts an obstacle or blocked corner")
		for i in range(101):
			assert(nav.open_cell(nav.cell_at(previous.lerp(point,i/100.0))))
		previous = point

func _initialize() -> void:
	var nav := Nav.new()
	# A wall with one bridge: all paths between the banks must pass this opening.
	var blocked: Array = []
	for y in range(7):
		if y!=5: blocked.append([3,y])
	nav.configure({"grid_size":[7,7],"cell_size":[32,32],"blocked":blocked})
	var start := Vector2(48,48)
	var target := Vector2(176,48)
	var path := nav.route(start,target)
	assert_route(nav,start,target,path)
	assert(not nav.segment_clear(start,target))
	var bridge_used := false
	var previous := start
	for point in path:
		for i in range(201):
			if nav.cell_at(previous.lerp(point,i/200.0))==Vector2i(3,5): bridge_used = true
		previous = point
	assert(bridge_used, "River crossing failed to use the bridge")
	# A blocked order and a disconnected but empty island cannot produce a partial route.
	assert(nav.route(start,Vector2(112,48)).is_empty())
	blocked.append([3,5])
	nav.configure({"grid_size":[7,7],"cell_size":[32,32],"blocked":blocked})
	assert(not nav.reachable(start,target) and nav.route(start,target).is_empty())
	nav.configure({"grid_size":[3,3],"cell_size":[32,32],"blocked":[[1,0],[0,1]]})
	assert(not nav.segment_clear(Vector2(16,16),Vector2(48,48)))
	assert(nav.route(Vector2(16,16),Vector2(48,48)).is_empty())
	# A shallow diagonal touching a thin corner must not be missed by pixel sampling.
	nav.configure({"grid_size":[3,3],"cell_size":[32,32],"blocked":[[1,0]]})
	assert(not nav.segment_clear(Vector2(31,31),Vector2(65,33)))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/world_layout.json"))
	nav.configure(layout.navigation)
	assert(layout.navigation.bridges==[[39.0,15.0],[40.0,21.0]])
	for entry in layout.navigation.blocked: assert(not nav.open_cell(Vector2i(entry[0],entry[1])))
	for entry in layout.navigation.bridges: assert(nav.open_cell(Vector2i(entry[0],entry[1])))
	# Cross the real southern river from either side, around mountain and river tiles.
	for endpoints in [[Vector2(1408,672),Vector2(1200,688)],[Vector2(1200,688),Vector2(1408,672)], [Vector2(1408,672),Vector2(1040,624)]]:
		assert_route(nav,endpoints[0],endpoints[1],nav.route(endpoints[0],endpoints[1]))
	print("PASS: A* detours, bridge crossing, blocked/disconnected goals, strict corner checks and real Tiled navigation")
	quit()
