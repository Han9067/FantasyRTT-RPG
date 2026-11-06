class_name BattleMap
extends Node2D
signal status_changed
const Ground = preload("res://scripts/battle_ground.gd")
const MOVE_SPEED := 76.0
const DRAG_THRESHOLD := 4.0
const MAP_SIZE := Vector2(2560,1600)
const CAMERA_SPEED := 420.0
const MIN_ZOOM := 1.0
const MAX_ZOOM := 3.0
const ZOOM_STEP := 0.25
const BODY_CENTER_X := CharacterArt.BODY_ORIGIN.x + 16
var character_frames: SpriteFrames
var character_name := "여행자"
var player_sprite: AnimatedSprite2D
var ground: BattleGround
var unit_position := Vector2.ZERO
var destination := Vector2.ZERO
var selected := false
var moving := false
var dragging := false
var drag_origin := Vector2.ZERO
var drag_end := Vector2.ZERO
var marker_time := 0.0
var map_size := MAP_SIZE
var viewport_size := Vector2.ZERO
var camera: Camera2D
var zoom_level := MIN_ZOOM
var pan_keys: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground = Ground.new()
	ground.show_behind_parent = true
	add_child(ground)
	player_sprite = AnimatedSprite2D.new()
	player_sprite.sprite_frames = character_frames
	player_sprite.centered = false
	player_sprite.scale = Vector2.ONE
	add_child(player_sprite)
	ground.generate(Vector2i(map_size))
	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	camera.limit_smoothed = false
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y)
	camera.position = map_size * 0.5
	add_child(camera)
	camera.make_current()
	resize_map()
	unit_position = map_size * 0.5
	destination = unit_position
	update_sprite()
	player_sprite.play("idle")
	get_viewport().size_changed.connect(resize_map)

func playable_rect() -> Rect2:
	return Rect2(Vector2(18,96), Vector2(maxf(1,map_size.x-36),maxf(1,map_size.y-168)))

func resize_map() -> void:
	if not is_inside_tree(): return
	viewport_size = get_viewport_rect().size
	if is_instance_valid(camera): clamp_camera()
	dragging = false
	queue_redraw()

func screen_playable_rect() -> Rect2:
	return Rect2(Vector2(0,96),Vector2(viewport_size.x,maxf(1,viewport_size.y-168)))

func screen_to_world(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func world_to_screen(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * point

func clamp_camera() -> void:
	var half := (viewport_size / zoom_level).min(map_size) * 0.5
	camera.position = camera.position.clamp(half,map_size-half)
	camera.zoom = Vector2.ONE * zoom_level
	camera.force_update_scroll()
	queue_redraw()

func pan_camera(direction: Vector2, delta: float) -> void:
	# Equal screen-space travel speed at every zoom; diagonals are normalized.
	if direction == Vector2.ZERO: return
	camera.position += direction.normalized() * CAMERA_SPEED * delta / zoom_level
	clamp_camera()

func change_zoom(step: float, screen_anchor: Vector2) -> void:
	var next := clampf(zoom_level + step,MIN_ZOOM,MAX_ZOOM)
	if is_equal_approx(next,zoom_level): return
	var anchor := screen_to_world(screen_anchor)
	zoom_level = next
	camera.zoom = Vector2.ONE * zoom_level
	camera.force_update_scroll()
	camera.position += anchor - screen_to_world(screen_anchor)
	clamp_camera()
	status_changed.emit()

func clamp_point(point: Vector2) -> Vector2:
	var bounds := playable_rect()
	return point.clamp(bounds.position, bounds.end)

func unit_bounds() -> Rect2:
	# Select visible body/weapon, not the 128x96 transparent composition canvas.
	return Rect2(unit_position + Vector2(-14,-29),Vector2(28,32))

func selection_rect() -> Rect2:
	return Rect2(screen_to_world(drag_origin),screen_to_world(drag_end)-screen_to_world(drag_origin)).abs()

func set_selected(value: bool) -> void:
	selected = value
	status_changed.emit()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in [KEY_W,KEY_A,KEY_S,KEY_D]:
			pan_keys[key] = event.pressed
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var point := screen_to_world(event.position)
		var over_field := screen_playable_rect().has_point(event.position)
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed and over_field:
				change_zoom(ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else -ZOOM_STEP,event.position)
				get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and over_field:
				dragging = true
				drag_origin = event.position
				drag_end = event.position
			elif not event.pressed and dragging:
				drag_end = event.position
				if drag_origin.distance_to(drag_end) >= DRAG_THRESHOLD:
					set_selected(selection_rect().intersects(unit_bounds()))
				else:
					set_selected(unit_bounds().has_point(point))
				dragging = false
			else: return
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and over_field:
			issue_move(point)
		else: return
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif event is InputEventMouseMotion and dragging:
		drag_end = event.position
		get_viewport().set_input_as_handled()
		queue_redraw()

func issue_move(point: Vector2) -> void:
	if not selected: return
	destination = clamp_point(point)
	marker_time = 0.8
	set_moving(unit_position.distance_to(destination) > 0.25)
	queue_redraw()

func set_moving(value: bool) -> void:
	moving = value
	player_sprite.play("walk" if moving else "idle")
	status_changed.emit()

func _physics_process(delta: float) -> void:
	var direction := Vector2(int(pan_keys.get(KEY_D,false))-int(pan_keys.get(KEY_A,false)),int(pan_keys.get(KEY_S,false))-int(pan_keys.get(KEY_W,false)))
	pan_camera(direction,delta)
	if moving:
		var difference := destination - unit_position
		if absf(difference.x) > 0.1: player_sprite.flip_h = difference.x > 0
		unit_position = unit_position.move_toward(destination, MOVE_SPEED * delta)
		if unit_position.is_equal_approx(destination): set_moving(false)
		update_sprite()
		queue_redraw()
	if marker_time > 0:
		marker_time = maxf(0,marker_time-delta)
		queue_redraw()

func update_sprite() -> void:
	# Flipping a padded image needs an anchor correction, not scaling the unit.
	var anchor_x := CharacterArt.FRAME_SIZE.x - BODY_CENTER_X if player_sprite.flip_h else BODY_CENTER_X
	player_sprite.position = unit_position.round() - Vector2(anchor_x,CharacterArt.FEET_Y)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		dragging = false
		pan_keys.clear()
		queue_redraw()

func ellipse_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(25):
		var a := TAU * i / 24.0
		points.append((center + Vector2(cos(a)*radius,sin(a)*radius*0.4)).round())
	return points

func _draw() -> void:
	# Ground shadow and selection feedback remain at native resolution.
	draw_colored_polygon(ellipse_points(unit_position+Vector2(1,1),10),Color(0.25,0.27,0.18,0.30))
	if selected:
		draw_polyline(ellipse_points(unit_position+Vector2(0,1),13),Color("def1a5"),1,false)
		draw_line(unit_position+Vector2(-9,5),unit_position+Vector2(9,5),Color("a9c573"),1,false)
	if marker_time > 0:
		var color := Color("f0dfaa")
		color.a = minf(1,marker_time*3)
		var p := destination.round()
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			draw_line(p+direction*3,p+direction*8,color,1,false)
	if dragging and drag_origin.distance_to(drag_end) >= DRAG_THRESHOLD:
		var rect := selection_rect()
		draw_rect(rect,Color(0.78,0.90,0.61,0.10))
		draw_rect(rect,Color("e0ecae"),false,1.0/zoom_level)
