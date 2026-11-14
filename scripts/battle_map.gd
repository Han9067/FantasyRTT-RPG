class_name BattleMap
extends Node2D
signal status_changed
signal pause_changed(paused: bool)
const Ground = preload("res://scripts/battle_ground.gd")
const Combat = preload("res://scripts/battle_combat.gd")
const Outline = preload("res://scripts/selection_outline.gdshader")
const ATTACK_CURSOR = preload("res://assets/ui/attack_cursor.svg")
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
const FORMATION_SPACING := Vector2(23, 16)
const DEPLOYMENT_OFFSET := 440.0
const CONTACT_SIZE := Vector2(5, 5)
const BODY_CENTER_FROM_FEET := Vector2(0, -13)
const HUD_LAYER := 10
const ALLIED_ROUTE_COLOR := Color("58a6ff")
const ENEMY_ROUTE_COLOR := Color("ff625f")

var friendlies: Array[BattleUnit] = []
var infantry: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var hero_group: Array[BattleUnit] = []
var selection: Array[BattleUnit] = []
var joint_order := false
var battle_paused := false
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
var combat: RefCounted
var outline_material: ShaderMaterial
var pointer_screen := Vector2(-1, -1)
var attack_cursor_active := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground = Ground.new()
	ground.show_behind_parent = true
	add_child(ground)
	var units := Node2D.new()
	units.name = "Units"
	units.y_sort_enabled = true
	add_child(units)
	combat = Combat.new(self)
	outline_material = ShaderMaterial.new()
	outline_material.shader = Outline
	Input.set_custom_mouse_cursor(ATTACK_CURSOR, Input.CURSOR_CROSS, Vector2(27, 5))
	var hero := BattleUnit.new()
	hero.max_hp = 100
	hero.hp = 100
	hero.attack_damage = 6
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
	hero.enter_idle()
	get_viewport().size_changed.connect(resize_map)

func deploy_infantry(units: Node2D, allied: bool) -> void:
	var group: StringName = &"allied_infantry" if allied else &"enemy_infantry"
	var variants: Array[SpriteFrames] = []
	for i in range(5):
		variants.append(CharacterArt.infantry_frames(CharacterArt.infantry_appearance(allied, i), true))
	for row in range(INFANTRY_ROWS):
		for column in range(INFANTRY_COLUMNS):
			var sprite := BattleUnit.new()
			sprite.allied = allied
			sprite.avoid_side = -1.0 if row < INFANTRY_ROWS / 2 else 1.0
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
			sprite.enter_idle()

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
	standard.centered = false
	# Visible bottom-left pivot: 7px left and 4px up from the formation center.
	standard.offset = -Vector2(18, 56) + Vector2(-7, -4)
	standard.hide()
	overlay.add_child(standard)

func place_standard() -> void:
	if not standard.visible: return
	var marked: Array[BattleUnit] = []
	for unit in selection:
		if unit.alive() and infantry.has(unit): marked.append(unit)
	if marked.is_empty(): marked.assign(Combat.living(selection))
	if marked.is_empty():
		standard.hide()
	else:
		standard.position = Combat.center(marked) + BODY_CENTER_FROM_FEET

func refresh_selection() -> void:
	selection.assign(Combat.living(selection))
	selected = selection.has(player_sprite)
	player_sprite.material = outline_material if selected else null
	standard.visible = not selection.is_empty()
	if standard.visible:
		place_standard()
		standard.play()
	else:
		standard.stop()
	refresh_attack_cursor()
	status_changed.emit()
	queue_redraw()

func enemy_at(point: Vector2) -> BattleUnit:
	var front: BattleUnit
	for enemy in enemies:
		if not enemy.alive(): continue
		if Rect2(enemy.position + Vector2(-14, -29), Vector2(28, 32)).has_point(point):
			if front == null or enemy.position.y >= front.position.y: front = enemy
	return front

func refresh_attack_cursor() -> void:
	attack_cursor_active = not selection.is_empty() and screen_playable_rect().has_point(pointer_screen) and enemy_at(screen_to_world(pointer_screen)) != null
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if attack_cursor_active else Input.CURSOR_ARROW)

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)

func issue_attack(enemy: BattleUnit) -> void:
	if enemy == null or not enemy.alive() or selection.is_empty(): return
	combat.cancel_for(selection)
	combat.command(selection)
	joint_order = false
	for key: String in ["hero", "infantry"]:
		if combat.orders.has(key): order_formation(Combat.living(combat.group(key)), Combat.center(Combat.living(enemies)))
	order_marker = enemy.position
	marker_time = 0.8
	status_changed.emit()
	queue_redraw()

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
		if not unit.alive(): continue
		var bounds := Rect2(unit.position + Vector2(-14,-29), Vector2(28,32))
		if is_box and box.intersects(bounds):
			selection.append(unit)
		elif not is_box and bounds.has_point(point) and (front == null or unit.position.y >= front.position.y):
			front = unit
	if front != null: selection.append(front)
	selected = selection.has(player_sprite)
	if selection.size() > int(selected):
		selection.assign(Combat.living(infantry))
		if selected: selection.append(hero_group[0])
	refresh_selection()

func _input(event: InputEvent) -> void:
	# A drag begun on the field still ends if the pointer is released over the HUD.
	if dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		finish_selection(event.position)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		pointer_screen = event.position
		refresh_attack_cursor()
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in [KEY_W,KEY_A,KEY_S,KEY_D]:
			pan_keys[key] = event.pressed
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var point := screen_to_world(event.position)
		var over_field := screen_playable_rect().has_point(event.position)
		if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and attack_cursor_active:
			dragging = false
			issue_attack(enemy_at(point))
			get_viewport().set_input_as_handled()
			return
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
	combat.cancel_for(selection)
	order_marker = order_formation(selection, point)
	joint_order = selection.size() == Combat.living(friendlies).size()
	var hero := hero_group[0]
	destination = hero.target
	moving = not hero.position.is_equal_approx(destination)
	marker_time = 0.8
	status_changed.emit()
	queue_redraw()

func order_formation(members: Array[BattleUnit], point: Vector2) -> Vector2:
	if members.is_empty(): return point
	var center := Vector2.ZERO
	var formation := Rect2(members[0].position, Vector2.ZERO)
	for unit in members:
		center += unit.position
		formation = formation.expand(unit.position)
	center /= members.size()
	var bounds := playable_rect()
	var offset := (point - center).clamp(bounds.position - formation.position, bounds.end - formation.end)
	for unit in members:
		unit.target = unit.position + offset
		# Queued orders must not change the frozen pose while paused.
		if not battle_paused: update_unit_animation(unit)
	queue_redraw()
	return center + offset

func update_unit_animation(unit: BattleUnit) -> void:
	if not unit.alive() or unit.swing_time >= 0.0: return
	if unit.position.is_equal_approx(unit.target):
		unit.enter_idle()
	else:
		unit.play("walk")

func set_battle_paused(value: bool) -> void:
	if battle_paused == value: return
	battle_paused = value
	for group in [friendlies, enemies]:
		for unit: BattleUnit in group:
			unit.speed_scale = 0.0 if value else 1.0
			if not value: update_unit_animation(unit)
	standard.speed_scale = 0.0 if value else 1.0
	pause_changed.emit(value)
	status_changed.emit()
	queue_redraw()

func _physics_process(delta: float) -> void:
	var direction := Vector2(int(pan_keys.get(KEY_D,false))-int(pan_keys.get(KEY_A,false)),int(pan_keys.get(KEY_S,false))-int(pan_keys.get(KEY_W,false)))
	pan_camera(direction,delta)
	refresh_attack_cursor()
	# Camera and input stay live; only battlefield simulation is paused.
	if battle_paused: return
	combat.prepare(delta)
	if joint_order and not combat.orders.has("hero") and not combat.orders.has("infantry"):
		advance_formation(Combat.living(friendlies), Combat.living(enemies), delta)
	else:
		if not combat.engaged("hero"):
			advance_formation(Combat.living(hero_group), Combat.living(enemies), delta, Combat.living(infantry))
		if not combat.engaged("infantry"):
			advance_formation(Combat.living(infantry), Combat.living(enemies), delta, Combat.living(hero_group))
	if not combat.engaged("enemy"):
		advance_formation(Combat.living(enemies), Combat.living(friendlies), delta)
	combat.step(delta)
	if selection.any(func(unit: BattleUnit) -> bool: return not unit.alive()): refresh_selection()
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
	if members.is_empty(): return
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
		if fraction < 1.0 or arrived: unit.enter_idle()
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
		pointer_screen = Vector2(-1, -1)
		refresh_attack_cursor()
		queue_redraw()

func ellipse_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(25):
		var a := TAU * i / 24.0
		points.append((center + Vector2(cos(a)*radius,sin(a)*radius*0.4)).round())
	return points

func movement_guides() -> Array[Dictionary]:
	var guides: Array[Dictionary] = []
	for group in [Combat.living(hero_group), Combat.living(infantry), Combat.living(enemies)]:
		if group.is_empty(): continue
		var start := Vector2.ZERO
		var finish := Vector2.ZERO
		for unit: BattleUnit in group:
			start += unit.position
			finish += unit.target
		start /= group.size()
		finish /= group.size()
		if start.is_equal_approx(finish): continue
		guides.append({"start": start, "end": finish,
			"color": ALLIED_ROUTE_COLOR if group[0].allied else ENEMY_ROUTE_COLOR})
	return guides

func _draw() -> void:
	# One persistent route per formation/hero, including orders queued in pause.
	for guide in movement_guides():
		var start: Vector2 = guide.start
		var finish: Vector2 = guide.end
		var color: Color = guide.color
		var direction := (finish - start).normalized()
		var arrow_size := minf(8.0 / zoom_level, start.distance_to(finish) * 0.5)
		draw_line(start, finish, color, 2.0 / zoom_level)
		for side in [-1, 1]:
			var wing: Vector2 = finish - direction * arrow_size + direction.orthogonal() * arrow_size * 0.5 * side
			draw_line(finish, wing, color, 2.0 / zoom_level)
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
