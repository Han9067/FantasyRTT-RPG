extends SceneTree
const Art = preload("res://scripts/character_art.gd")
const Battle = preload("res://scripts/battle_map.gd")

func _initialize() -> void:
	call_deferred("run")

func click(map: BattleMap, point: Vector2, button := MOUSE_BUTTON_LEFT, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	map._unhandled_input(event)

func select_click(map: BattleMap, point: Vector2) -> void:
	click(map,point)
	click(map,point,MOUSE_BUTTON_LEFT,false)

func key(map: BattleMap, code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	map._unhandled_input(event)

func drag(map: BattleMap, start: Vector2, finish: Vector2) -> void:
	click(map,start)
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	map._unhandled_input(motion)
	assert(map.dragging)
	click(map,finish,MOUSE_BUTTON_LEFT,false)
	assert(not map.dragging)

func advance(map: BattleMap, seconds: float) -> void:
	for i in range(int(seconds*60)):
		map._physics_process(1.0/60.0)

func assert_camera_inside(map: BattleMap) -> void:
	var a := map.screen_to_world(Vector2.ZERO)
	var b := map.screen_to_world(map.viewport_size)
	assert(a.x >= -0.01 and a.y >= -0.01, "Camera escaped top/left boundary")
	assert(b.x <= map.map_size.x+0.01 and b.y <= map.map_size.y+0.01, "Camera escaped bottom/right boundary")

func run() -> void:
	root.size = Vector2i(1280,800)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.show_creation()
	game.name_input.text = "전장 테스트"
	game.name_input.text_changed.emit(game.name_input.text)
	game.show_battle()
	await process_frame
	var map: BattleMap = game.battle
	map.set_physics_process(false)
	assert(game.current_screen == "battle" and not is_instance_valid(game.world))
	assert(map.unit_position == Battle.MAP_SIZE*0.5)
	assert(map.world_to_screen(map.unit_position).is_equal_approx(Vector2(640,400)))
	assert(map.character_frames == game.character_frames and map.character_name == "전장 테스트")
	assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED)
	assert(map.player_sprite.scale == Vector2.ONE and map.scale == Vector2.ONE)
	assert(map.player_sprite.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE))
	assert(map.player_sprite.animation == "idle" and not map.selected)
	assert(map.ground.ground.get_size() == Battle.MAP_SIZE)
	var terrain := map.ground.ground
	var original_position := map.unit_position
	click(map,Vector2(900,500),MOUSE_BUTTON_RIGHT)
	advance(map,1)
	assert(map.unit_position == original_position)
	select_click(map,Vector2(640,385))
	assert(map.selected)
	select_click(map,Vector2(120,200))
	assert(not map.selected)
	for start in [Vector2(610,355),Vector2(670,355),Vector2(610,425),Vector2(670,425)]:
		drag(map,start,Vector2(1280,780)-start)
		assert(map.selected)
		drag(map,Vector2(180,180),Vector2(230,230))
		assert(not map.selected)
	select_click(map,map.world_to_screen(map.unit_position+Vector2(-65,-60)))
	assert(not map.selected, "Transparent padding is not a selectable unit")
	select_click(map,Vector2(640,385))
	click(map,Vector2(800,400),MOUSE_BUTTON_RIGHT)
	assert(map.moving and map.player_sprite.animation == "walk")
	advance(map,1)
	assert(map.unit_position.is_equal_approx(original_position+Vector2(76,0)))
	assert(map.player_sprite.flip_h)
	assert(map.player_sprite.position.x + Art.FRAME_SIZE.x - Battle.BODY_CENTER_X == roundf(map.unit_position.x))
	var target := map.screen_to_world(Vector2(500,450))
	click(map,Vector2(500,450),MOUSE_BUTTON_RIGHT)
	advance(map,4)
	assert(map.unit_position == target and not map.moving)
	assert(map.player_sprite.animation == "idle" and not map.player_sprite.flip_h)
	assert(map.player_sprite.position.x + Battle.BODY_CENTER_X == map.unit_position.x)
	assert(map.player_sprite.position.y + Art.FEET_Y == map.unit_position.y)
	# Real WASD key events pan the camera, never the unit; diagonal speed is normalized.
	var center := map.camera.position
	key(map,KEY_D,true)
	advance(map,0.5)
	key(map,KEY_D,false)
	assert(map.camera.position.is_equal_approx(center+Vector2(210,0)))
	assert(map.unit_position == target)
	center = map.camera.position
	key(map,KEY_A,true)
	key(map,KEY_W,true)
	advance(map,0.5)
	key(map,KEY_A,false)
	key(map,KEY_W,false)
	assert(is_equal_approx(center.distance_to(map.camera.position),210))
	assert(game.battle_status.get_theme_font("font") == game.theme.default_font, "HUD lost Korean font across CanvasLayer")
	var hud_position: Vector2 = game.battle_status.get_global_transform_with_canvas().origin
	# Zoom about the cursor, with absolute 1x and 3x bounds.
	var anchor := Vector2(700,420)
	var anchor_world := map.screen_to_world(anchor)
	click(map,anchor,MOUSE_BUTTON_WHEEL_UP)
	assert(map.zoom_level == 1.25)
	assert(map.screen_to_world(anchor).is_equal_approx(anchor_world))
	for i in range(20): click(map,Vector2(640,400),MOUSE_BUTTON_WHEEL_UP)
	assert(map.zoom_level == 3.0)
	assert(map.player_sprite.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2(3,3)))
	assert(game.battle_status.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE))
	assert(game.battle_status.get_global_transform_with_canvas().origin == hud_position)
	# At maximum zoom and a panned camera, click, drag and move still use world coordinates.
	map.camera.position = map.unit_position
	map.clamp_camera()
	select_click(map,Vector2(100,150))
	assert(not map.selected)
	drag(map,Vector2(700,430),Vector2(580,300))
	assert(map.selected)
	var zoom_target := map.screen_to_world(Vector2(820,460))
	click(map,Vector2(820,460),MOUSE_BUTTON_RIGHT)
	assert(map.destination.is_equal_approx(zoom_target))
	advance(map,2)
	assert(map.unit_position.is_equal_approx(zoom_target) and not map.moving)
	# All edges remain closed at both zoom limits and intermediate scales.
	for zoom in [1.0,1.25,2.0,3.0]:
		map.zoom_level = zoom
		for direction in [Vector2(-1,-1),Vector2(1,1),Vector2(-1,1),Vector2(1,-1)]:
			map.pan_camera(direction,100)
			assert_camera_inside(map)
		map.change_zoom(-0.25,Vector2(1240,700))
		assert_camera_inside(map)
	for i in range(20): click(map,Vector2(640,400),MOUSE_BUTTON_WHEEL_DOWN)
	assert(map.zoom_level == 1.0)
	map.camera.position = map.map_size*0.5
	map.clamp_camera()
	# HUD cannot issue orders or zoom; focus loss clears camera keys and drag.
	click(map,Vector2(1100,35),MOUSE_BUTTON_RIGHT)
	assert(not map.moving)
	click(map,Vector2(1100,35),MOUSE_BUTTON_WHEEL_UP)
	assert(map.zoom_level == 1.0)
	click(map,Vector2(400,200))
	key(map,KEY_W,true)
	map._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert(not map.dragging and map.pan_keys.is_empty())
	root.size = Vector2i(960,720)
	await process_frame
	await process_frame
	assert(map.map_size == Battle.MAP_SIZE and map.viewport_size == Vector2(960,720))
	assert(map.ground.ground == terrain, "Camera/resize must not rebuild terrain")
	assert_camera_inside(map)
	assert(map.player_sprite.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE))
	map.issue_move(Vector2(5000,5000))
	assert(map.destination == map.playable_rect().end)
	advance(map,30)
	assert(not map.moving)
	map.change_zoom(2,Vector2(480,360))
	game.show_creation()
	await process_frame
	assert(not is_instance_valid(game.battle) and not is_instance_valid(game.battle_hud))
	assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	assert(game.player_name == "전장 테스트")
	game.show_battle()
	await process_frame
	assert(game.battle.unit_position == game.battle.map_size*0.5)
	assert(game.battle.zoom_level == 1 and not game.battle.selected and not game.battle.moving)
	print("PASS: fixed terrain, camera WASD/diagonal speed, cursor zoom 1x..3x, every map edge, fixed HUD, zoomed selection/orders, original movement, resize without rebaking, focus loss, creation return")
	quit()
