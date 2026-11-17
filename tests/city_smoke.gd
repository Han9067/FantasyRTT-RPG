extends SceneTree
var game: Control

func _initialize() -> void:
	call_deferred("run")

func mouse(map: WorldMap, point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = true
	map._unhandled_input(event)

func walk_to_city(map: WorldMap) -> void:
	for i in range(3600):
		var before := map.unit_position
		map._physics_process(1.0/60.0)
		assert(map.navigation.segment_clear(before,map.unit_position), "City orders must follow walkable terrain")
		if not map.current_city.is_empty(): return
		assert(map.party_marker.visible and not map.city_panel.visible, "Do not enter before arrival")
	assert(false, "City order failed to arrive")

func run() -> void:
	root.size = Vector2i(1280,800)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.show_world()
	await process_frame
	var map: WorldMap = game.world
	map.set_physics_process(false)
	map.set_process(false)
	assert(not map.city_panel.visible and map.current_city.is_empty())
	# The drawn frame has exactly three extra native pixels, not a scaled texture.
	var frame := GameUITheme.panel_style().texture.get_image()
	for y in range(5): assert(frame.get_pixel(16,y) == GameUITheme.BORDER)
	assert(frame.get_pixel(16,5) != GameUITheme.BORDER)
	for zoom in [1.0,3.0]:
		for city: Dictionary in map.cities:
			var center := Vector2(city.position[0],city.position[1])
			map.restore_travel(map.spawn_position,center,zoom)
			var point := map.world_to_screen(center)
			map.update_city_hover(point)
			map.update_world_cursor(point)
			assert(map.entrance_cursor_active and not map.blocked_cursor)
			assert(map.city_popup.visible)
			var motion := InputEventMouseMotion.new()
			motion.position = point
			map._unhandled_input(motion)
			assert(map.entrance_cursor_active and not map.attack_cursor_active, "World motion must preserve entrance hover; actual cursor is checked in Chromium")
			mouse(map,point)
			assert(map.pending_city.id == city.id and map.moving and map.party_marker.visible)
			assert(map.city_bounds(city).has_point(map.destination))
			walk_to_city(map)
			assert(map.current_city.id == city.id and not map.party_marker.visible and map.city_panel.visible)
			assert(not map.moving and map.pending_city.is_empty() and not map.city_popup.visible)
			assert(map.city_panel.size == Vector2(400,764) and map.city_panel.position == Vector2(18,18))
			assert(map.city_panel_title.text == map.display_city_name(city))
			map.update_city_hover(point)
			map.update_world_cursor(point)
			assert(not map.city_popup.visible and not map.entrance_cursor_active)
	print("PASS: all four cities at 1x/3x, entrance cursor, walkable routes, arrival-only entry and 400px panel")
	await process_frame
	var original := map.unit_position
	var current := map.current_city
	for i in range(3):
		assert(map.city_actions[i].text == ["내성","길드","시장"][i])
		if i>0: assert(map.city_actions[i].position.y > map.city_actions[i-1].position.y)
		map.city_actions[i].pressed.emit()
		assert(map.current_city == current and map.unit_position == original and not map.party_marker.visible)
	mouse(map,Vector2(200,400),MOUSE_BUTTON_RIGHT)
	assert(map.current_city == current and map.unit_position == original, "Panel clicks cannot issue map orders")
	map.update_world_cursor(Vector2(200,400))
	assert(not map.entrance_cursor_active and not map.blocked_cursor)
	root.size = Vector2i(960,720)
	await process_frame
	await process_frame
	assert(map.city_panel.size == Vector2(400,684))
	# A battle round trip preserves the occupied city and hidden party.
	game.enter_battle_from_world()
	await process_frame
	game.show_world()
	await process_frame
	map = game.world
	map.set_process(false)
	map.set_physics_process(false)
	assert(map.current_city.id == current.id and map.city_panel.visible and not map.party_marker.visible)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	map._unhandled_input(escape)
	assert(map.current_city.is_empty() and map.party_marker.visible and not map.city_panel.visible)
	print("PASS: placeholder button order/no effects, UI input isolation, panel resize, battle return and Escape exit")
	# A new valid travel order cancels entry; invalid terrain preserves the valid order.
	map.restore_travel(map.spawn_position,map.spawn_position,3)
	map.issue_city_entry(map.cities[1])
	var pending := map.pending_city
	var destination := map.destination
	map.issue_move(Vector2(1264,624)) # River.
	assert(map.pending_city == pending and map.destination == destination)
	var field := map.spawn_position+Vector2(80,0)
	map.issue_move(field)
	assert(map.pending_city.is_empty())
	for i in range(180): map._physics_process(1.0/60.0)
	assert(map.unit_position.is_equal_approx(field) and map.current_city.is_empty() and map.party_marker.visible)
	map.issue_city_entry(map.cities[1])
	walk_to_city(map)
	map.issue_move(field)
	assert(map.current_city.is_empty() and not map.city_panel.visible and map.party_marker.visible and map.moving)
	# A city already at the current position opens immediately; ordinary travel through it does not.
	map.restore_travel(map.city_entry_point(map.cities[1]),map.spawn_position,3)
	map.issue_city_entry(map.cities[1])
	assert(not map.current_city.is_empty() and not map.moving)
	map.update_world_cursor(Vector2(640,42),true)
	assert(not map.entrance_cursor_active)
	game.show_creation()
	await process_frame
	print("PASS: replacement/cancelled entry orders, no premature entry, immediate same-position entry and cursor cleanup")
	quit()
