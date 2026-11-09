extends SceneTree
const Art = preload("res://scripts/character_art.gd")
func _initialize() -> void:
	call_deferred("run")
func click(map: WorldMap, point: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = true
	map._unhandled_input(event)
func advance(map: WorldMap, seconds: float) -> void:
	for i in range(int(seconds*60)): map._physics_process(1.0/60.0)
func inside(map: WorldMap) -> void:
	var a := map.screen_to_world(Vector2.ZERO)
	var b := map.screen_to_world(map.viewport_size)
	assert(a.x >= -0.01 and a.y >= -0.01)
	assert(b.x <= map.map_size.x+0.01 and b.y <= map.map_size.y+0.01)
func run() -> void:
	root.size = Vector2i(1280,800)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.show_creation()
	game.name_input.text = "제국의 여행자"
	game.name_input.text_changed.emit(game.name_input.text)
	game.create_button.pressed.emit()
	await process_frame
	await process_frame
	var map: WorldMap = game.world
	map.set_physics_process(false)
	assert(game.current_screen == "world" and not is_instance_valid(game.battle))
	assert(map.map_size == Vector2(5120,3840) and map.cities.size() == 42)
	assert(map.TERRAIN.get_size() == Vector2(1024,768))
	assert(map.terrain.get_child_count() == 6)
	for tile in map.terrain.get_children():
		assert(tile.texture.get_width() <= 2048 and tile.texture.get_height() <= 2048)
	assert(map.world_to_screen(map.unit_position).is_equal_approx(Vector2(640,400)))
	assert(map.character_frames == game.character_frames and map.character_name == "제국의 여행자")
	assert(map.selected and not map.moving and map.player_sprite.scale == Vector2.ONE)
	assert(map.player_sprite.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE))
	assert(game.battle_button.get_global_rect().get_center().x == 640, "Battle link must be centered")
	assert(game.world_status.get_theme_font("font") == game.theme.default_font)
	for city in map.cities:
		assert(city["size"] == [96.0,96.0])
		assert(Rect2(Vector2.ZERO,map.map_size).encloses(Rect2(Vector2(city.position[0]-48,city.position[1]-48),Vector2(96,96))))
	for i in range(map.cities.size()):
		var city: Dictionary = map.cities[i]
		assert(city.name == str(i+1), "City names must be consecutive numbers")
		var reference: Array = city.reference_position
		var expected := Vector2(roundf(reference[0]*5120.0/1824.0),roundf(reference[1]*3840.0/1368.0))
		assert(absf(city.position[0]-expected.x) <= 16 and absf(city.position[1]-expected.y) <= 16, "Tiled city moved beyond nearest grid cell")
		assert(Vector2(city.position[0],city.position[1]) == Vector2(city.tile_position[0]*32+48,city.tile_position[1]*32+48))
		var label: Label = map.get_node("CityLabel_"+city.name)
		assert(label.text == str(i+1))
		assert(Rect2(Vector2.ZERO,map.map_size).encloses(Rect2(label.position,label.size)), "Edge city label clipped")
	# No prerequisite click: first right click immediately walks, left click never deselects.
	click(map,Vector2(800,400),MOUSE_BUTTON_RIGHT)
	assert(map.moving and map.player_sprite.animation == "walk")
	advance(map,1)
	assert(map.unit_position.is_equal_approx(WorldMap.SPAWN+Vector2(76,0)))
	click(map,Vector2(120,200),MOUSE_BUTTON_LEFT)
	assert(map.selected and not map.dragging)
	advance(map,2)
	assert(not map.moving and map.player_sprite.animation == "idle")
	var point := map.unit_position
	click(map,Vector2(640,42),MOUSE_BUTTON_RIGHT)
	assert(not map.moving)
	# Cursor zoom and camera panning preserve the chosen character / move target transform.
	var anchor := Vector2(730,450)
	var before := map.screen_to_world(anchor)
	click(map,anchor,MOUSE_BUTTON_WHEEL_UP)
	assert(map.zoom_level == 1.25 and map.screen_to_world(anchor).is_equal_approx(before))
	map.pan_camera(Vector2.RIGHT,0.5)
	assert(map.unit_position == point)
	var target := map.screen_to_world(Vector2(700,500))
	click(map,Vector2(700,500),MOUSE_BUTTON_RIGHT)
	assert(map.destination.is_equal_approx(target))
	advance(map,6)
	assert(map.unit_position.is_equal_approx(target) and not map.moving)
	var texture: Texture2D = map.terrain.get_child(0).texture
	for zoom in [1.0,1.5,3.0]:
		map.zoom_level = zoom
		for direction in [Vector2(-1,-1),Vector2(1,1),Vector2(-1,1),Vector2(1,-1)]:
			map.pan_camera(direction,100)
			inside(map)
	assert(map.terrain.get_child(0).texture == texture)
	root.size = Vector2i(960,720)
	await process_frame
	await process_frame
	inside(map)
	assert(map.terrain.get_child(0).texture == texture and map.map_size == WorldMap.WORLD_SIZE)
	assert(absf(game.battle_button.get_global_rect().get_center().x-480)<1)
	map.zoom_level = 1.0
	root.size = Vector2i(6400,4320)
	await process_frame
	await process_frame
	inside(map)
	assert(map.zoom_level >= 1.25, "Oversized viewport exposed terrain boundary")
	assert(game.world_status.text.ends_with("125%"), "Fit zoom must also update the HUD")
	root.size = Vector2i(960,720)
	await process_frame
	await process_frame
	inside(map)
	# New camera controls: arrow and WASD keys are both 2x the battlefield speed.
	map.zoom_level = 1
	map.camera.position = map.map_size*0.5
	map.clamp_camera()
	for code in [KEY_RIGHT,KEY_D]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = true
		map._unhandled_input(event)
		var initial := map.camera.position
		advance(map,0.5)
		event.pressed = false
		map._unhandled_input(event)
		assert(is_equal_approx(map.camera.position.x-initial.x,420))
	# Grab offset prevents a snap. Zoomed dragging maps mini pixels to world distance.
	var mini = game.world_overview
	for zoom in [1.0,3.0]:
		map.zoom_level = zoom
		map.camera.position = map.map_size*0.5
		map.clamp_camera()
		var party := map.unit_position
		var destination := map.destination
		var initial := map.camera.position
		var start: Vector2 = mini.camera_rect().get_center()+Vector2(2,1)
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.position = start
		press.pressed = true
		mini._gui_input(press)
		assert(mini.camera_dragging and map.camera.position == initial)
		var motion := InputEventMouseMotion.new()
		motion.position = start+Vector2(18,12)
		mini._gui_input(motion)
		assert(map.camera.position.is_equal_approx(initial+Vector2(18,12)/mini.map_bounds().size*map.map_size))
		assert(map.unit_position == party and map.destination == destination and map.selected)
		for corner in [Vector2(-100,-100),Vector2(600,500)]:
			motion.position = corner
			mini._gui_input(motion)
			inside(map)
		press.pressed = false
		mini._gui_input(press)
		assert(not mini.camera_dragging)
		initial = map.camera.position
		motion.position = start
		mini._gui_input(motion)
		assert(map.camera.position == initial)
	# Outside rectangle clicks do not move camera or character; focus loss cancels drag.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(10,10)
	mini._gui_input(press)
	assert(not mini.camera_dragging)
	press.position = mini.camera_rect().get_center()
	mini._gui_input(press)
	assert(mini.camera_dragging)
	mini._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert(not mini.camera_dragging)
	var saved_position := map.unit_position
	var saved_camera := map.camera.position
	var saved_zoom := map.zoom_level
	game.battle_button.pressed.emit()
	await process_frame
	assert(game.current_screen == "battle" and not is_instance_valid(game.world))
	assert(game.battle.character_frames == game.character_frames and game.battle.character_name == "제국의 여행자")
	assert(not game.battle.selected and game.battle.map_size == BattleMap.MAP_SIZE)
	game.show_world()
	await process_frame
	assert(game.world.unit_position == saved_position and game.world.camera.position == saved_camera and game.world.zoom_level == saved_zoom)
	assert(game.world.selected and not game.world.moving)
	game.show_creation()
	await process_frame
	assert(not is_instance_valid(game.world) and not is_instance_valid(game.battle_hud))
	assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	game.create_button.pressed.emit()
	await process_frame
	assert(game.world.unit_position == WorldMap.SPAWN and game.world.zoom_level == 1)
	print("PASS: creation -> world, 42 numbered native 96px Tiled cities, persistent selection, first right-click walk/idle, camera bounds/zoom/resize, centered battle button, world/battle continuity and return state")
	quit()
