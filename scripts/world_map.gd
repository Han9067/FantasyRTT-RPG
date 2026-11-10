class_name WorldMap
extends BattleMap
## Native-pixel campaign prototype; shared camera/movement, always-selected party.
const WORLD_SIZE := Vector2(5120,3840)
const SPAWN := Vector2(2560,1920)
const TERRAIN = preload("res://assets/world/imperial_world.png")
const WORLD_CAMERA_SPEED := 840.0
const PartyMarker = preload("res://scripts/world_party_marker.gd")
var party_marker: WorldPartyMarker
var character_appearance: Dictionary = CharacterArt.defaults()
var terrain: Node2D
var cities: Array = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_size = WORLD_SIZE
	selected = true
	terrain = Node2D.new()
	terrain.show_behind_parent = true
	add_child(terrain)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/world_layout.json"))
	for chunk in layout.chunks:
		var tile := Sprite2D.new()
		tile.texture = load("res://assets/world/" + chunk.file)
		tile.centered = false
		tile.position = Vector2(chunk.position[0],chunk.position[1])
		terrain.add_child(tile)
	cities = layout.cities
	for city in cities:
		var title := Label.new()
		title.name = "CityLabel_" + city.name
		title.text = city.name
		var half_height: float = city["size"][1] * 0.5
		var label_y: float = city.position[1]+half_height+3
		if label_y+24 > map_size.y: label_y = city.position[1]-half_height-26
		title.position = Vector2(clampf(city.position[0]-32,0,map_size.x-64),label_y)
		title.size = Vector2(64,24)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_theme_font_override("font",load("res://assets/fonts/NotoSansCJK-Regular.ttc"))
		title.add_theme_font_size_override("font_size",16)
		title.add_theme_color_override("font_color",Color("f2e3ba"))
		title.add_theme_color_override("font_outline_color",Color("283a2b"))
		title.add_theme_constant_override("outline_size",4)
		add_child(title)
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
	camera.position = SPAWN
	add_child(camera)
	camera.make_current()
	resize_map()
	unit_position = SPAWN
	destination = unit_position
	update_sprite()
	get_viewport().size_changed.connect(resize_map)

func playable_rect() -> Rect2:
	return Rect2(Vector2(18,32),map_size-Vector2(36,50))

func update_sprite() -> void:
	party_marker.place(unit_position)

func set_moving(value: bool) -> void:
	moving = value
	party_marker.freeze_portrait()
	status_changed.emit()

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

func set_selected(_value: bool) -> void:
	selected = true
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			pan_keys[code] = event.pressed
			get_viewport().set_input_as_handled()
			return
	# Left click never deselects or starts a battle-style selection rectangle.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: return
	super._unhandled_input(event)

func restore_travel(position_in_world: Vector2, camera_position: Vector2, zoom: float) -> void:
	unit_position = clamp_point(position_in_world)
	destination = unit_position
	zoom_level = clampf(zoom,MIN_ZOOM,MAX_ZOOM)
	camera.position = camera_position
	clamp_camera()
	update_sprite()
