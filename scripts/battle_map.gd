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
const INFANTRY_COLUMNS := 4
const INFANTRY_ROWS := 5
const FORMATION_SPACING := Vector2(22, 15)
const DEPLOYMENT_OFFSET := 440.0
const CONTACT_SIZE := Vector2(5, 5)
const BODY_CENTER_FROM_FEET := Vector2(0, -13)
const HUD_LAYER := 10

class BattleUnit extends AnimatedSprite2D:
	var target := Vector2.ZERO

	func contact_box() -> Rect2:
		return Rect2(position + BODY_CENTER_FROM_FEET - CONTACT_SIZE * 0.5, CONTACT_SIZE)

var friendlies: Array[BattleUnit] = []
var infantry: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var hero_group: Array[BattleUnit] = []
var selection: Array[BattleUnit] = []
var joint_order := false
var standard: AnimatedSprite2D
var order_marker := Vector2.ZERO
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
	var units := Node2D.new()
	units.name = "Units"
	units.y_sort_enabled = true
	add_child(units)
	var hero := BattleUnit.new()
	player_sprite = hero
	player_sprite.sprite_frames = character_frames
	player_sprite.centered = false
	player_sprite.scale = Vector2.ONE
	units.add_child(player_sprite)
	friendlies.append(hero)
	hero_group.append(hero)
	deploy_infantry(units, true)
	deploy_infantry(units, false)
	create_standard()
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
	unit_position = map_size * 0.5 + Vector2(-DEPLOYMENT_OFFSET + 84, 0)
	destination = unit_position
	hero.position = unit_position
	hero.target = unit_position
	hero.flip_h = true
	hero.offset = -sprite_anchor(true)
	player_sprite.play("idle")
	get_viewport().size_changed.connect(resize_map)

func deploy_infantry(units: Node2D, allied: bool) -> void:
	var group: StringName = &"allied_infantry" if allied else &"enemy_infantry"
	var variants: Array[SpriteFrames] = []
	for i in range(5):
		variants.append(CharacterArt.infantry_frames(CharacterArt.infantry_appearance(allied, i), allied))
	for row in range(INFANTRY_ROWS):
		for column in range(INFANTRY_COLUMNS):
			var sprite := BattleUnit.new()
			sprite.centered = false
			sprite.flip_h = allied
			sprite.sprite_frames = variants[(row + 2 * column) % variants.size()]
			var side := -1 if allied else 1
			var slot := Vector2(column - (INFANTRY_COLUMNS - 1) * 0.5, row - (INFANTRY_ROWS - 1) * 0.5)
			sprite.position = map_size * 0.5 + Vector2(side * DEPLOYMENT_OFFSET, 0) + slot * FORMATION_SPACING
			sprite.target = sprite.position
			sprite.offset = -sprite_anchor(sprite.flip_h)
			if allied:
				infantry.append(sprite)
				friendlies.append(sprite)
			else:
				enemies.append(sprite)
			units.add_child(sprite)
			sprite.add_to_group(group)
			sprite.play("idle")
			sprite.frame = (row + column) % CharacterArt.FRAME_COUNTS.idle

func create_standard() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = HUD_LAYER + 1
	overlay.follow_viewport_enabled = true
	add_child(overlay)
	standard = AnimatedSprite2D.new()
	standard.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames := SpriteFrames.new()
	for i in range(1, 9):
		frames.add_frame(&"default", load("res://assets/battle/flag/flag_%02d.png" % i))
	frames.set_animation_speed(&"default", 8.0)
	frames.set_animation_loop(&"default", true)
	standard.sprite_frames = frames
	standard.hide()
	overlay.add_child(standard)

func place_standard() -> void:
	if standard.visible:
		if selection.has(infantry[0]):
			var first := infantry[0].contact_box().get_center()
			var last := infantry[-1].contact_box().get_center()
			standard.position = first.lerp(last, 0.5)
		else:
			standard.position = hero_group[0].contact_box().get_center()

func playable_rect() -> Rect2:
	return Rect2(Vector2(18,96), Vector2(maxf(1,map_size.x-36),maxf(1,map_size.y-168)))

func resize_map() -> void:
	if not is_inside_tree(): return
	viewport_size = get_viewport_rect().size
	if is_instance_valid(camera): clamp_camera()
	dragging = false
	queue_redraw()

func screen_playable_rect() -> Rect2:
	return Rect2(Vector2(0,96),Vector2(viewport_size.x,maxf(1,viewport_size.y-96)))

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

func selection_rect() -> Rect2:
	return Rect2(screen_to_world(drag_origin),screen_to_world(drag_end)-screen_to_world(drag_origin)).abs()

func finish_selection(screen_point: Vector2) -> void:
	drag_end = screen_point
	dragging = false
	selection.clear()
	var box := selection_rect()
	var is_box := drag_origin.distance_to(screen_point) >= DRAG_THRESHOLD
	var point := screen_to_world(screen_point)
	var front: BattleUnit
	for unit in friendlies:
		var bounds := Rect2(unit.position + Vector2(-14,-29), Vector2(28,32))
		if is_box and box.intersects(bounds):
			selection.append(unit)
		elif not is_box and bounds.has_point(point) and (front == null or unit.position.y >= front.position.y):
			front = unit
	if front != null: selection.append(front)
	selected = selection.has(player_sprite)
	if selection.size() > int(selected):
		selection.assign(infantry)
		if selected: selection.append(hero_group[0])
	standard.visible = not selection.is_empty()
	if standard.visible:
		place_standard()
		standard.play()
	else:
		standard.stop()
	status_changed.emit()
	queue_redraw()

func _input(event: InputEvent) -> void:
	# A drag begun on the field still ends if the pointer is released over the HUD.
	if dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		finish_selection(event.position)
		get_viewport().set_input_as_handled()

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
				finish_selection(event.position)
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
	if selection.is_empty(): return
	var center := Vector2.ZERO
	var formation := Rect2(selection[0].position, Vector2.ZERO)
	for unit in selection:
		center += unit.position
		formation = formation.expand(unit.position)
	center /= selection.size()
	var bounds := playable_rect()
	var offset := (point - center).clamp(bounds.position - formation.position, bounds.end - formation.end)
	for unit in selection:
		unit.target = unit.position + offset
		unit.play("idle" if unit.position.is_equal_approx(unit.target) else "walk")
	order_marker = center + offset
	joint_order = selection.size() == friendlies.size()
	var hero := hero_group[0]
	destination = hero.target
	moving = not hero.position.is_equal_approx(destination)
	marker_time = 0.8
	status_changed.emit()
	queue_redraw()

func _physics_process(delta: float) -> void:
	var direction := Vector2(int(pan_keys.get(KEY_D,false))-int(pan_keys.get(KEY_A,false)),int(pan_keys.get(KEY_S,false))-int(pan_keys.get(KEY_W,false)))
	pan_camera(direction,delta)
	if joint_order:
		advance_formation(friendlies, enemies, delta)
	else:
		advance_formation(hero_group, enemies, delta, infantry)
		advance_formation(infantry, enemies, delta, hero_group)
	unit_position = player_sprite.position
	destination = hero_group[0].target
	moving = unit_position != destination
	place_standard()
	if marker_time > 0:
		marker_time = maxf(0,marker_time-delta)
		queue_redraw()

# All members translate by the same amount. The first contact limits the
# whole formation, so the front rank cannot pass through a unit or bunch up.
func advance_formation(members: Array[BattleUnit], blockers: Array[BattleUnit], delta: float, others: Array[BattleUnit] = []) -> void:
	var leader := members[0]
	var distance := leader.target - leader.position
	if distance == Vector2.ZERO: return
	var step := distance.limit_length(MOVE_SPEED * delta)
	var fraction := 1.0
	for unit in members:
		var box := unit.contact_box()
		for obstacle in blockers:
			fraction = minf(fraction, contact_fraction(box, step, obstacle.contact_box()))
		for obstacle in others:
			fraction = minf(fraction, contact_fraction(box, step, obstacle.contact_box()))
	var arrived := distance.length() <= MOVE_SPEED * delta
	for unit in members:
		if absf(step.x) > 0.001:
			unit.flip_h = step.x > 0
			unit.offset = -sprite_anchor(unit.flip_h)
		if fraction < 1.0:
			unit.position += step * maxf(0.0, fraction - 0.0001)
			unit.target = unit.position
		elif arrived:
			unit.position = unit.target
		else:
			unit.position += step
		if fraction < 1.0 or arrived: unit.play("idle")
	queue_redraw()

# Swept AABB on both axes, including fast movement in a long physics tick.
static func contact_fraction(box: Rect2, motion: Vector2, obstacle: Rect2) -> float:
	var enter := -INF
	var leave := INF
	for axis in range(2):
		var gap := obstacle.position[axis] - box.end[axis]
		var far_gap := obstacle.end[axis] - box.position[axis]
		if is_zero_approx(motion[axis]):
			if gap >= 0 or far_gap <= 0: return 1.0
		else:
			var a := gap / motion[axis]
			var b := far_gap / motion[axis]
			enter = maxf(enter, minf(a, b))
			leave = minf(leave, maxf(a, b))
	if enter >= leave or leave <= 0.0: return 1.0
	return clampf(enter, 0.0, 1.0)

static func sprite_anchor(facing_right: bool) -> Vector2:
	var x := CharacterArt.FRAME_SIZE.x - BODY_CENTER_X if facing_right else BODY_CENTER_X
	return Vector2(x, CharacterArt.FEET_Y)

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
	if marker_time > 0:
		var color := Color("f0dfaa")
		color.a = minf(1,marker_time*3)
		var p := order_marker.round()
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			draw_line(p+direction*3,p+direction*8,color,1,false)
	if dragging and drag_origin.distance_to(drag_end) >= DRAG_THRESHOLD:
		var rect := selection_rect()
		draw_rect(rect,Color(0.78,0.90,0.61,0.10))
		draw_rect(rect,Color("e0ecae"),false,1.0/zoom_level)
