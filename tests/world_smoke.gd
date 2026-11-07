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
	assert(map.map_size == Vector2(3072,2304) and map.cities.size() == 12)
	assert(map.TERRAIN.get_size() == map.map_size)
	assert(map.world_to_screen(map.unit_position).is_equal_approx(Vector2(640,400)))
	assert(map.character_frames == game.character_frames and map.character_name == "제국의 여행자")
	assert(map.selected and not map.moving and map.player_sprite.scale == Vector2.ONE)
	assert(map.player_sprite.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE))
	assert(game.battle_button.get_global_rect().get_center().x == 640, "Battle link must be centered")
	assert(game.world_status.get_theme_font("font") == game.theme.default_font)
	for city in map.cities:
		assert(city["size"] == [128.0,128.0])
		assert(Rect2(Vector2.ZERO,map.map_size).encloses(Rect2(Vector2(city.position[0]-64,city.position[1]-64),Vector2(128,128))))
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
	var texture := map.terrain.texture
	for zoom in [1.0,1.5,3.0]:
		map.zoom_level = zoom
		for direction in [Vector2(-1,-1),Vector2(1,1),Vector2(-1,1),Vector2(1,-1)]:
			map.pan_camera(direction,100)
			inside(map)
	assert(map.terrain.texture == texture)
	root.size = Vector2i(960,720)
	await process_frame
	await process_frame
	inside(map)
	assert(map.terrain.texture == texture and map.map_size == WorldMap.WORLD_SIZE)
	assert(absf(game.battle_button.get_global_rect().get_center().x-480)<1)
	map.zoom_level = 1.0
	root.size = Vector2i(3840,2160)
	await process_frame
	await process_frame
	inside(map)
	assert(map.zoom_level >= 1.25, "Oversized viewport exposed terrain boundary")
	assert(game.world_status.text.ends_with("125%"), "Fit zoom must also update the HUD")
	root.size = Vector2i(960,720)
	await process_frame
	await process_frame
	inside(map)
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
	print("PASS: creation -> world, 12 native 128px cities, persistent selection, first right-click walk/idle, camera bounds/zoom/resize, centered battle button, world/battle continuity and return state")
	quit()
