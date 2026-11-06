class_name BattleMap
extends Node2D
signal status_changed
const Ground = preload("res://scripts/battle_ground.gd")
const MOVE_SPEED := 76.0
const DRAG_THRESHOLD := 4.0
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
var map_size := Vector2.ZERO

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
	map_size = get_viewport_rect().size
	if map_size.x < 160 or map_size.y < 200: return
	ground.generate(Vector2i(map_size))
	if unit_position != Vector2.ZERO:
		unit_position = clamp_point(unit_position)
		destination = clamp_point(destination)
		update_sprite()
	dragging = false
	queue_redraw()

func clamp_point(point: Vector2) -> Vector2:
	var bounds := playable_rect()
	return point.clamp(bounds.position, bounds.end)

func unit_bounds() -> Rect2:
	# Select visible body/weapon, not the 128x96 transparent composition canvas.
	return Rect2(unit_position + Vector2(-14,-29),Vector2(28,32))

func selection_rect() -> Rect2:
	return Rect2(drag_origin,drag_end-drag_origin).abs()

func set_selected(value: bool) -> void:
	selected = value
	status_changed.emit()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var point: Vector2 = get_global_transform().affine_inverse() * event.position
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and playable_rect().has_point(point):
				dragging = true
				drag_origin = point
				drag_end = point
			elif not event.pressed and dragging:
				drag_end = point
				if drag_origin.distance_to(drag_end) >= DRAG_THRESHOLD:
					set_selected(selection_rect().intersects(unit_bounds()))
				else:
					set_selected(unit_bounds().has_point(point))
				dragging = false
			else: return
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and playable_rect().has_point(point):
			issue_move(point)
		else: return
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif event is InputEventMouseMotion and dragging:
		drag_end = get_global_transform().affine_inverse() * event.position
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
		draw_rect(rect,Color("e0ecae"),false,1)
