class_name WorldMap
extends BattleMap
## Native-pixel campaign prototype; shared camera/movement, always-selected party.
const TERRAIN = preload("res://assets/world/imperial_world.png")
const WORLD_CAMERA_SPEED := 840.0
const PartyMarker = preload("res://scripts/world_party_marker.gd")
var party_marker: WorldPartyMarker
var character_appearance: Dictionary = CharacterArt.defaults()
var terrain: Node2D
var cities: Array = []
var spawn_position := Vector2.ZERO
var navigation := WorldNavigation.new()
var route_points := PackedVector2Array()
var route_index := 0
var blocked_cursor := false
var pointer_inside := true
var hud_controls: Array[Control] = []
var city_popup: PanelContainer
var city_title: Label
var hovered_city: Dictionary = {}
var pending_city: Dictionary = {}
var current_city: Dictionary = {}
var entrance_cursor_active := false
var city_entry_cache: Dictionary = {}
var city_panel: PanelContainer
var city_panel_title: Label
var city_actions: Array[Button] = []
var inventory := preload("res://scripts/world_inventory.gd").new()
var menu_bar := HBoxContainer.new()
var clock := preload("res://scripts/world_clock.gd").new()
var city_overlay: CanvasLayer

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/world_layout.json"))
	map_size = Vector2(layout.size[0],layout.size[1])
	spawn_position = Vector2(layout.spawn[0],layout.spawn[1])
	navigation.configure(layout.navigation)
	zoom_level = 3.0
	selected = true
	terrain = Node2D.new()
	terrain.show_behind_parent = true
	add_child(terrain)
	for chunk in layout.chunks:
		var tile := Sprite2D.new()
		tile.texture = load("res://assets/world/" + chunk.file)
		tile.centered = false
		tile.position = Vector2(chunk.position[0],chunk.position[1])
		terrain.add_child(tile)
	cities = layout.cities
	create_city_popup()
	party_marker = PartyMarker.new()
	party_marker.name = "PartyMarker"
	party_marker.setup(character_appearance)
	add_child(party_marker)
	player_sprite = party_marker.portrait
	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	camera.limit_smoothed = false
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.position = spawn_position
	add_child(camera)
	camera.make_current()
	resize_map()
	unit_position = spawn_position
	destination = unit_position
	update_sprite()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(make_entrance_cursor(),Input.CURSOR_CROSS,Vector2(24,16))
	city_overlay.add_child(clock)
	create_city_panel()
	create_world_menu()
	Input.set_custom_mouse_cursor(make_blocked_cursor(),Input.CURSOR_FORBIDDEN,Vector2(12,12))
	get_viewport().size_changed.connect(resize_map)
	get_viewport().size_changed.connect(layout_city_panel)

func create_world_menu() -> void:
	menu_bar.theme = GameUITheme.build()
	city_overlay.add_child(menu_bar)
	for title in ["캐릭터", "인벤토리", "부대", "저널"]:
		var action := Button.new()
		action.text = title
		action.custom_minimum_size = Vector2(116, 48)
		action.focus_mode = Control.FOCUS_NONE
		menu_bar.add_child(action)
		if title == "인벤토리": action.pressed.connect(open_inventory)
	menu_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	city_overlay.add_child(inventory)
	inventory.setup(character_appearance)

func open_inventory() -> void:
	pan_keys.clear()
	city_popup.hide()
	inventory.open()

func playable_rect() -> Rect2:
	return Rect2(Vector2(18,32),map_size-Vector2(36,50))

func screen_playable_rect() -> Rect2:
	return Rect2(Vector2.ZERO,viewport_size)

func update_sprite() -> void:
	party_marker.place(unit_position)

func set_moving(value: bool) -> void:
	moving = value
	party_marker.freeze_portrait()
	status_changed.emit()

func can_move_to(point: Vector2) -> bool:
	return playable_rect().has_point(point) and navigation.reachable(unit_position,point)

func issue_move(point: Vector2) -> void:
	# Reject blocked/unreachable orders without cancelling an existing valid route.
	if not can_move_to(point): return
	var path := navigation.route(unit_position,point)
	if path.is_empty(): return
	pending_city = {}
	exit_city()
	destination = point
	route_points = path
	route_index = 0
	marker_time = 0.8
	set_moving(unit_position.distance_to(destination)>0.25)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var direction := Vector2(int(pan_keys.get(KEY_D,false))-int(pan_keys.get(KEY_A,false)),int(pan_keys.get(KEY_S,false))-int(pan_keys.get(KEY_W,false)))
	pan_camera(direction,delta)
	var simulation_delta := delta * clock.speed
	if simulation_delta <= 0: return
	clock.advance(simulation_delta)
	var remaining := MOVE_SPEED * simulation_delta
	while moving and remaining>0:
		var target := route_points[route_index]
		var distance := unit_position.distance_to(target)
		if distance<=remaining:
			unit_position = target
			remaining -= distance
			route_index += 1
			if route_index>=route_points.size(): set_moving(false)
		else:
			unit_position = unit_position.move_toward(target,remaining)
			remaining = 0
		update_sprite()
		queue_redraw()
	finish_city_arrival()
	if marker_time>0:
		marker_time = maxf(0,marker_time-simulation_delta)
		queue_redraw()

static func make_blocked_cursor() -> ImageTexture:
	var image := Image.create(24,24,false,Image.FORMAT_RGBA8)
	for y in range(3,21):
		for x in range(3,21):
			var distance := mini(absi(x-y),absi(x+y-23))
			if distance<=3: image.set_pixel(x,y,Color("4c1820") if distance==3 else Color("f04444"))
	return ImageTexture.create_from_image(image)

func cursor_blocked_at(screen_point: Vector2) -> bool:
	return can_interact_at(screen_point) and not can_move_to(screen_to_world(screen_point))

func _process(_delta: float) -> void:
	var point := get_viewport().get_mouse_position()
	var hovered := get_viewport().gui_get_hovered_control()
	var over_ui := is_instance_valid(hovered) and hovered.mouse_filter!=Control.MOUSE_FILTER_IGNORE
	update_city_hover(point,over_ui)
	update_world_cursor(point,over_ui)

func _notification(what: int) -> void:
	super._notification(what)
	if what in [NOTIFICATION_WM_MOUSE_EXIT,NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		pointer_inside = false
		if is_instance_valid(city_popup): city_popup.hide()
		hovered_city = {}
		blocked_cursor = false
		entrance_cursor_active = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	elif what in [NOTIFICATION_WM_MOUSE_ENTER,NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		pointer_inside = true

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null,Input.CURSOR_FORBIDDEN)
	Input.set_custom_mouse_cursor(null,Input.CURSOR_CROSS)

func _draw() -> void:
	# The portrait token replaces the battlefield body, ground shadow and selection ring.
	if marker_time > 0:
		var color := Color("f0dfaa")
		color.a = minf(1,marker_time*3)
		var point := destination.round()
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			draw_line(point+direction*3,point+direction*8,color,1,false)

func clamp_camera() -> void:
	# A window wider than the map (e.g. 4K) must still never expose its outside.
	var previous_zoom := zoom_level
	zoom_level = maxf(zoom_level,maxf(viewport_size.x/map_size.x,viewport_size.y/map_size.y))
	super.clamp_camera()
	if not is_equal_approx(previous_zoom,zoom_level): status_changed.emit()

func pan_camera(direction: Vector2, delta: float) -> void:
	var arrows := Vector2(int(pan_keys.get(KEY_RIGHT,false))-int(pan_keys.get(KEY_LEFT,false)),int(pan_keys.get(KEY_DOWN,false))-int(pan_keys.get(KEY_UP,false)))
	var combined := direction + arrows
	if combined == Vector2.ZERO: return
	camera.position += combined.normalized() * WORLD_CAMERA_SPEED * delta / zoom_level
	clamp_camera()

func _unhandled_input(event: InputEvent) -> void:
	if inventory.visible:
		if event.is_action_pressed("ui_cancel"): inventory.hide()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse and not can_interact_at(event.position): return
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_ESCAPE and event.pressed and not current_city.is_empty():
			exit_city()
			get_viewport().set_input_as_handled()
			return
		if code in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			pan_keys[code] = event.pressed
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		var city := city_at(screen_to_world(event.position))
		if not city.is_empty():
			issue_city_entry(city)
			get_viewport().set_input_as_handled()
			return
	# Left click never deselects or starts a battle-style selection rectangle.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: return
	super._unhandled_input(event)

func restore_travel(position_in_world: Vector2, camera_position: Vector2, zoom: float, city_id := "") -> void:
	pending_city = {}
	exit_city()
	unit_position = clamp_point(position_in_world) if navigation.open_cell(navigation.cell_at(clamp_point(position_in_world))) else spawn_position
	destination = unit_position
	route_points.clear()
	route_index = 0
	set_moving(false)
	zoom_level = clampf(zoom,MIN_ZOOM,MAX_ZOOM)
	camera.position = camera_position
	clamp_camera()
	update_sprite()
	for city: Dictionary in cities:
		if city.id == city_id and city_bounds(city).has_point(unit_position): enter_city(city)

func can_interact_at(point: Vector2) -> bool:
	if clock.get_global_rect().has_point(point): return false
	if inventory.visible or menu_bar.get_global_rect().has_point(point): return false
	if not screen_playable_rect().has_point(point): return false
	if is_instance_valid(city_panel) and city_panel.visible and city_panel.get_global_rect().has_point(point): return false
	for control in hud_controls:
		if is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(point): return false
	return true

func create_city_popup() -> void:
	city_overlay = CanvasLayer.new()
	city_overlay.layer = 11
	add_child(city_overlay)
	city_popup = PanelContainer.new()
	city_popup.name = "CityPopup"
	city_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	city_popup.custom_minimum_size = Vector2(240,112)
	city_popup.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	city_popup.add_theme_stylebox_override("panel",GameUITheme.panel_style(14))
	city_popup.theme = GameUITheme.build()
	city_overlay.add_child(city_popup)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation",10)
	city_popup.add_child(content)
	city_title = Label.new()
	city_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	city_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	city_title.add_theme_color_override("font_color",GameUITheme.INK)
	content.add_child(city_title)
	var rule := HSeparator.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := StyleBoxLine.new()
	line.color = GameUITheme.BUTTON_BORDER
	line.thickness = 1
	rule.add_theme_stylebox_override("separator",line)
	content.add_child(rule)
	var lord := Label.new()
	lord.name = "Lord"
	lord.text = "영주 : 없음"
	lord.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lord.add_theme_color_override("font_color",GameUITheme.INK)
	content.add_child(lord)
	city_popup.hide()

func update_city_hover(screen_point: Vector2, over_ui := false) -> void:
	hovered_city = {}
	if pointer_inside and not over_ui and can_interact_at(screen_point):
		hovered_city = city_at(screen_to_world(screen_point))
	if not hovered_city.is_empty() and hovered_city.id == current_city.get("id",""): hovered_city = {}
	if hovered_city.is_empty():
		city_popup.hide()
		return
	city_title.text = display_city_name(hovered_city)
	city_popup.size = city_popup.get_combined_minimum_size()
	var position := screen_point+Vector2(18,18)
	if position.x+city_popup.size.x > viewport_size.x-8: position.x = screen_point.x-city_popup.size.x-18
	if position.y+city_popup.size.y > viewport_size.y-8: position.y = screen_point.y-city_popup.size.y-18
	city_popup.position = position.clamp(Vector2(8,8),(viewport_size-city_popup.size-Vector2(8,8)).max(Vector2(8,8)))
	city_popup.show()

static func city_bounds(city: Dictionary) -> Rect2:
	var dimensions := Vector2(city["size"][0],city["size"][1])
	return Rect2(Vector2(city.position[0],city.position[1])-dimensions*0.5,dimensions)

static func display_city_name(city: Dictionary) -> String:
	var value: String = city.name
	return "도시 "+value if value.is_valid_int() else value

func city_at(point: Vector2) -> Dictionary:
	for city: Dictionary in cities:
		if city_bounds(city).has_point(point): return city
	return {}

func city_entry_point(city: Dictionary) -> Vector2:
	var cell := navigation.cell_at(unit_position)
	if not navigation.open_cell(cell): return Vector2.INF
	var component := navigation.components[navigation.index(cell)]
	var key := str(city.id)+":"+str(component)
	if city_entry_cache.has(key): return city_entry_cache[key]
	var center := Vector2(city.position[0],city.position[1])
	var chosen := center if can_move_to(center) else Vector2.INF
	if chosen == Vector2.INF:
		# Choose an actual reachable point inside the city, never teleport across terrain.
		var bounds := city_bounds(city)
		var first := navigation.cell_at(bounds.position)
		var last := navigation.cell_at(bounds.end-Vector2.ONE)
		var best := INF
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var point := (Vector2(x,y)+Vector2.ONE*0.5)*navigation.cell_size
				if bounds.has_point(point) and can_move_to(point) and point.distance_squared_to(center)<best:
					chosen = point
					best = point.distance_squared_to(center)
	city_entry_cache[key] = chosen
	return chosen

func issue_city_entry(city: Dictionary) -> void:
	var point := city_entry_point(city)
	if point == Vector2.INF: return
	issue_move(point)
	if not destination.is_equal_approx(point): return
	pending_city = city
	finish_city_arrival()

func finish_city_arrival() -> void:
	if moving or pending_city.is_empty(): return
	var city := pending_city
	pending_city = {}
	if unit_position.distance_to(destination)<=0.25 and city_bounds(city).has_point(unit_position): enter_city(city)

func enter_city(city: Dictionary) -> void:
	current_city = city
	marker_time = 0.0
	party_marker.hide()
	city_popup.hide()
	city_panel_title.text = display_city_name(city)
	layout_city_panel()
	city_panel.show()
	queue_redraw()

func exit_city() -> void:
	current_city = {}
	if is_instance_valid(city_panel): city_panel.hide()
	if is_instance_valid(party_marker): party_marker.show()

func create_city_panel() -> void:
	city_panel = PanelContainer.new()
	city_panel.name = "CityPanel"
	city_panel.theme = GameUITheme.build()
	city_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	city_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	city_overlay.add_child(city_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",14)
	city_panel.add_child(content)
	city_panel_title = Label.new()
	city_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	city_panel_title.add_theme_font_size_override("font_size",24)
	content.add_child(city_panel_title)
	content.add_child(HSeparator.new())
	for caption in ["내성","길드","시장","나가기"]:
		var action := Button.new()
		action.text = caption
		action.custom_minimum_size.y = 52
		action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		action.focus_mode = Control.FOCUS_NONE
		action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		content.add_child(action)
		city_actions.append(action)
		if caption == "나가기": action.pressed.connect(exit_city)
	# The first three actions remain placeholders; only Exit has a callback.
	layout_city_panel()
	city_panel.hide()

func layout_city_panel() -> void:
	if not is_inside_tree() or not is_instance_valid(city_panel): return
	city_panel.position = Vector2(18,18)
	city_panel.size = Vector2(400,maxf(1,get_viewport_rect().size.y-36))
	var frame := city_panel.get_theme_stylebox("panel")
	var content_width := city_panel.size.x-frame.get_content_margin(SIDE_LEFT)-frame.get_content_margin(SIDE_RIGHT)
	for action in city_actions: action.custom_minimum_size.x = roundf(content_width*0.8)

func refresh_attack_cursor() -> void:
	# World hover owns its cursor; inherited mouse handling must not restore the arrow.
	pass

func update_world_cursor(point: Vector2, over_ui := false) -> void:
	var valid := pointer_inside and not over_ui and can_interact_at(point)
	var city := city_at(screen_to_world(point)) if valid else {}
	var entering: bool = not city.is_empty() and city.id != current_city.get("id","") and city_entry_point(city) != Vector2.INF
	var blocked: bool = valid and not entering and cursor_blocked_at(point)
	if entering != entrance_cursor_active or blocked != blocked_cursor:
		entrance_cursor_active = entering
		blocked_cursor = blocked
		Input.set_default_cursor_shape(Input.CURSOR_CROSS if entering else (Input.CURSOR_FORBIDDEN if blocked else Input.CURSOR_ARROW))

static func make_entrance_cursor() -> ImageTexture:
	var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(18,2,13,28),GameUITheme.BORDER)
	image.fill_rect(Rect2i(21,5,7,22),GameUITheme.IVORY)
	image.fill_rect(Rect2i(23,6,5,21),GameUITheme.INK)
	image.fill_rect(Rect2i(16,28,16,3),GameUITheme.BORDER)
	var arrow: Dictionary = {}
	for y in range(7,26):
		for x in range(2,25):
			if (x<16 and y>=14 and y<=18) or (x>=16 and absi(y-16)<=24-x): arrow[Vector2i(x,y)] = true
	for point: Vector2i in arrow:
		var edge := false
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if not arrow.has(point+step): edge = true
		image.set_pixelv(point,GameUITheme.BORDER if edge else GameUITheme.IVORY)
	return ImageTexture.create_from_image(image)
