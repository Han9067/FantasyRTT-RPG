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

func run() -> void:
	root.size = Vector2i(1280,800)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.show_creation()
	game.name_input.text = "전장 테스트"
	game.name_input.text_changed.emit(game.name_input.text)
	game.create_button.pressed.emit()
	await process_frame
	var map: BattleMap = game.battle
	map.set_physics_process(false)
	assert(game.current_screen == "battle" and not is_instance_valid(game.world))
	assert(map.unit_position == Vector2(640,400))
	assert(map.character_frames == game.character_frames and map.character_name == "전장 테스트")
	assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED)
	assert(map.player_sprite.scale == Vector2.ONE and map.scale == Vector2.ONE)
	assert(map.player_sprite.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE))
	assert(map.player_sprite.animation == "idle" and not map.selected)
	assert(map.ground.ground.get_size() == Vector2(1280,800))
	var original_position := map.unit_position
	click(map,Vector2(900,500),MOUSE_BUTTON_RIGHT)
	advance(map,1)
	assert(map.unit_position == original_position, "Unselected unit must ignore movement orders")
	select_click(map,map.unit_position-Vector2(0,15))
	assert(map.selected)
	select_click(map,Vector2(120,200))
	assert(not map.selected)
	# All four drag directions, with the actual body rather than its padded image.
	for start in [Vector2(610,355),Vector2(670,355),Vector2(610,425),Vector2(670,425)]:
		drag(map,start,Vector2(1280,780)-start)
		assert(map.selected)
		drag(map,Vector2(180,180),Vector2(230,230))
		assert(not map.selected)
	select_click(map,map.unit_position+Vector2(-65,-60))
	assert(not map.selected, "Transparent texture padding is not a selectable unit")
	select_click(map,map.unit_position-Vector2(0,15))
	click(map,Vector2(800,400),MOUSE_BUTTON_RIGHT)
	assert(map.moving and map.player_sprite.animation == "walk")
	advance(map,1)
	assert(map.unit_position.is_equal_approx(Vector2(716,400)))
	assert(map.player_sprite.flip_h)
	assert(map.player_sprite.position.x + Art.FRAME_SIZE.x - Battle.BODY_CENTER_X == roundf(map.unit_position.x))
	# Replace an active command; go left without changing native sprite scale.
	click(map,Vector2(500,450),MOUSE_BUTTON_RIGHT)
	advance(map,4)
	assert(map.unit_position == Vector2(500,450) and not map.moving)
	assert(map.player_sprite.animation == "idle" and not map.player_sprite.flip_h)
	assert(map.player_sprite.position.x + Battle.BODY_CENTER_X == map.unit_position.x)
	assert(map.player_sprite.position.y + Art.FEET_Y == map.unit_position.y)
	click(map,map.unit_position,MOUSE_BUTTON_RIGHT)
	assert(not map.moving and map.player_sprite.animation == "idle")
	# The HUD is not a destination and cannot start box selection.
	click(map,Vector2(1100,35),MOUSE_BUTTON_RIGHT)
	assert(not map.moving)
	click(map,Vector2(1100,35))
	assert(not map.dragging)
	click(map,Vector2(400,200))
	map._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert(not map.dragging)
	# Native scale survives viewport resizing; existing unit/target stay in bounds.
	root.size = Vector2i(960,720)
	await process_frame
	await process_frame
	assert(map.map_size == Vector2(960,720))
	assert(map.player_sprite.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE))
	assert(map.ground.ground.get_size() == Vector2(960,720))
	map.issue_move(Vector2(2000,2000))
	assert(map.destination == map.playable_rect().end)
	advance(map,12)
	assert(not map.moving)
	game.show_creation()
	await process_frame
	assert(not is_instance_valid(game.battle))
	assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	assert(game.player_name == "전장 테스트")
	game.create_button.pressed.emit()
	await process_frame
	assert(game.battle.unit_position == game.battle.map_size*0.5)
	assert(not game.battle.selected and not game.battle.moving)
	print("PASS: battle entry, native scale at two viewport sizes, click/four-way drag selection, empty/padding deselection, selection-gated orders, speed, retargeting, arrival idle, facing anchor, HUD exclusion, focus loss and creation return")
	quit()
