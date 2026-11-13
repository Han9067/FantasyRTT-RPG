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

func check_infantry(map: BattleMap) -> void:
	for allied in [true, false]:
		var soldiers := get_nodes_in_group("allied_infantry" if allied else "enemy_infantry")
		assert(soldiers.size() == 20)
		var columns := {}
		var rows := {}
		for soldier: AnimatedSprite2D in soldiers:
			assert(map.is_ancestor_of(soldier) and soldier != map.player_sprite)
			assert(soldier.flip_h == allied and soldier.animation == &"idle" and soldier.is_playing())
			var feet := soldier.position
			assert((feet.x < map.unit_position.x) == allied)
			columns[feet.x] = columns.get(feet.x, 0) + 1
			rows[feet.y] = rows.get(feet.y, 0) + 1
		assert(columns.size() == 4 and rows.size() == 5)
		for total in columns.values(): assert(total == 5)
		for total in rows.values(): assert(total == 4)
		var config := Art.infantry_appearance(allied, 0)
		assert(Art.BODY_LABELS[config.body] == ("파랑" if allied else "빨강"))
		assert(Art.data().sheets[config.helmet].slots[0].name == "metal_20")
		assert(config.hair == 0 and Art.equipped_weapon(config).id == "sword_01")
		assert(Art.equipped_offhand(config).id == "shield_31")
		var helmeted := Art.compose(config)
		config.hair = 7
		assert(Art.compose(config).get_data() == helmeted.get_data())
		config.erase("helmet")
		assert(Art.compose(config).get_data() != helmeted.get_data())

func check_group_orders(map: BattleMap) -> void:
	var unit := map.infantry[0]
	var hero := map.unit_position
	var start := unit.position
	var offsets := PackedVector2Array()
	assert(not map.standard.visible)
	for member in map.infantry:
		offsets.append(member.position - start)
		select_click(map, map.world_to_screen(member.position + Battle.BODY_CENTER_FROM_FEET))
		assert(map.selection == map.infantry and not map.selected)
	assert(map.standard.visible and map.standard.is_playing())
	assert(map.standard.sprite_frames.get_frame_count("default") == 8)
	assert(map.standard.sprite_frames.get_animation_loop("default"))
	var flag_offset := map.standard.position - start
	var center: Vector2 = (start + map.infantry.back().position) * 0.5
	assert(map.standard.centered and map.standard.offset == Vector2.ZERO)
	assert(map.standard.position.is_equal_approx(center + Battle.BODY_CENTER_FROM_FEET))
	map.issue_move(center + Vector2(-40,0))
	advance(map, 0.2)
	assert(unit.position.x < start.x and unit.animation == "walk" and map.unit_position == hero)
	assert((map.standard.position - unit.position).is_equal_approx(flag_offset))
	select_click(map, Vector2(600,200))
	assert(not map.standard.visible)
	advance(map, 1.0)
	assert(unit.position.is_equal_approx(start - Vector2(40,0)) and unit.animation == "idle")
	# March through the hero: the whole group should stop at the first 5px contact.
	select_click(map, map.world_to_screen(unit.position))
	map.issue_move(hero + Vector2(100,0))
	map._physics_process(8.0)
	var front_rank := map.infantry[11]
	assert(absf(hero.x - front_rank.position.x - 5.0) < 0.1)
	for i in range(map.infantry.size()):
		var member := map.infantry[i]
		assert((member.position - unit.position).is_equal_approx(offsets[i]))
		assert(member.animation == "idle" and not member.contact_box().intersects(map.hero_group[0].contact_box()))
	# Select hero and infantry together, pass the original hero position and meet the enemy.
	var left := map.world_to_screen(unit.position) - Vector2(20,40)
	var right := map.world_to_screen(hero) + Vector2(20,50)
	for corner in [left, right, Vector2(left.x,right.y), Vector2(right.x,left.y)]:
		drag(map, corner, left + right - corner)
		assert(map.selection.size() == 21 and map.selected)
	map.issue_move(map.enemies[0].position + Vector2(400,30))
	map._physics_process(30.0)
	assert(map.unit_position.x > map.map_size.x * 0.5 and not map.moving)
	for member in map.friendlies:
		assert(member.contact_box().size == Vector2(5,5))
		assert(member.contact_box().get_center() == member.position + Battle.BODY_CENTER_FROM_FEET)
		for enemy in map.enemies: assert(not member.contact_box().intersects(enemy.contact_box()))
	var stopped := map.unit_position
	map.issue_move(map.unit_position + Vector2(-200,0))
	advance(map, 0.25)
	assert(map.unit_position.x < stopped.x)
	assert(map.get_node("Units").y_sort_enabled)

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
	var overlay := map.standard.get_parent() as CanvasLayer
	assert(overlay.layer > game.battle_hud.layer and overlay.follow_viewport_enabled)
	map.set_physics_process(false)
	assert(game.current_screen == "battle" and not is_instance_valid(game.world))
	assert(map.unit_position.x < Battle.MAP_SIZE.x * 0.5)
	var hero_screen := map.world_to_screen(map.unit_position)
	assert(hero_screen.x < 400 and hero_screen.y == 400)
	assert(map.character_frames == game.character_frames and map.character_name == "전장 테스트")
	assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED)
	assert(map.player_sprite.scale == Vector2.ONE and map.scale == Vector2.ONE)
	assert(map.player_sprite.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE))
	assert(map.player_sprite.animation == "idle" and not map.selected)
	check_infantry(map)
	assert(map.ground.ground.get_size() == Battle.MAP_SIZE)
	var terrain := map.ground.ground
	var original_position := map.unit_position
	click(map,Vector2(900,500),MOUSE_BUTTON_RIGHT)
	advance(map,1)
	assert(map.unit_position == original_position)
	select_click(map,hero_screen + Vector2(0,-15))
	assert(map.selected)
	select_click(map,Vector2(120,200))
	assert(not map.selected)
	for start in [Vector2(610,355),Vector2(670,355),Vector2(610,425),Vector2(670,425)]:
		drag(map,hero_screen + start - Vector2(640,400),hero_screen + Vector2(640,380)-start)
		assert(map.selected)
		drag(map,Vector2(180,180),Vector2(230,230))
		assert(not map.selected)
	select_click(map,map.world_to_screen(map.unit_position+Vector2(-65,-60)))
	assert(not map.selected, "Transparent padding is not a selectable unit")
	select_click(map,hero_screen + Vector2(0,-15))
	click(map,Vector2(800,400),MOUSE_BUTTON_RIGHT)
	assert(map.moving and map.player_sprite.animation == "walk")
	advance(map,1)
	assert(map.unit_position.is_equal_approx(original_position+Vector2(76,0)))
	assert(map.player_sprite.flip_h)
	assert(map.player_sprite.position == map.unit_position and map.player_sprite.offset == -Battle.sprite_anchor(true))
	var target := map.screen_to_world(hero_screen + Vector2(20,120))
	click(map,hero_screen + Vector2(20,120),MOUSE_BUTTON_RIGHT)
	advance(map,4)
	assert(map.unit_position == target and not map.moving)
	assert(map.player_sprite.animation == "idle" and not map.player_sprite.flip_h)
	assert(map.player_sprite.position == map.unit_position)
	assert(map.player_sprite.offset == -Battle.sprite_anchor(false))
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
	var icons: HBoxContainer = game.screen.get_node("CommandIcons")
	assert(icons.get_child_count() == 3)
	for i in range(3):
		var icon := icons.get_child(i) as TextureRect
		assert(icon.texture != null and icon.accessibility_name == ["정지","사수","공격"][i])
		assert(icon.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var hud_position: Vector2 = icons.get_global_transform_with_canvas().origin
	# Zoom about the cursor, with absolute 1x and 3x bounds.
	var anchor := Vector2(700,420)
	var anchor_world := map.screen_to_world(anchor)
	click(map,anchor,MOUSE_BUTTON_WHEEL_UP)
	assert(map.zoom_level == 1.25)
	assert(map.screen_to_world(anchor).is_equal_approx(anchor_world))
	for i in range(20): click(map,Vector2(640,400),MOUSE_BUTTON_WHEEL_UP)
	assert(map.zoom_level == 3.0)
	assert(map.standard.get_global_transform_with_canvas().origin.is_equal_approx(map.world_to_screen(map.standard.position)))
	assert(map.player_sprite.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2(3,3)))
	assert(icons.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE))
	assert(icons.get_global_transform_with_canvas().origin == hud_position)
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
	assert(game.battle.unit_position == original_position)
	assert(game.battle.zoom_level == 1 and not game.battle.selected and not game.battle.moving)
	check_infantry(game.battle)
	root.size = Vector2i(1280,800)
	await process_frame
	await process_frame
	game.battle.set_physics_process(false)
	check_group_orders(game.battle)
	print("PASS: fixed terrain, camera WASD/diagonal speed, cursor zoom 1x..3x, every map edge, fixed HUD, zoomed selection/orders, original movement, resize without rebaking, focus loss, creation return")
	quit()
