class_name WorldMap
extends BattleMap
## Native-pixel campaign prototype; shared camera/movement, always-selected party.
const WORLD_SIZE := Vector2(3072,2304)
const SPAWN := Vector2(1536,1120)
const TERRAIN = preload("res://assets/world/imperial_world.png")
var terrain: Sprite2D
var cities: Array = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_size = WORLD_SIZE
	selected = true
	terrain = Sprite2D.new()
	terrain.texture = TERRAIN
	terrain.centered = false
	terrain.show_behind_parent = true
	add_child(terrain)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/world_layout.json"))
	cities = layout.cities
	for city in cities:
		var title := Label.new()
		title.text = city.name
		title.position = Vector2(city.position[0]-90,city.position[1]+67)
		title.size = Vector2(180,25)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_theme_font_override("font",load("res://assets/fonts/NotoSansCJK-Regular.ttc"))
		title.add_theme_font_size_override("font_size",13)
		title.add_theme_color_override("font_color",Color("f2e3ba"))
		title.add_theme_color_override("font_outline_color",Color("283a2b"))
		title.add_theme_constant_override("outline_size",4)
		add_child(title)
	player_sprite = AnimatedSprite2D.new()
	player_sprite.sprite_frames = character_frames
	player_sprite.centered = false
	player_sprite.scale = Vector2.ONE
	add_child(player_sprite)
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
	player_sprite.play("idle")
	get_viewport().size_changed.connect(resize_map)

func playable_rect() -> Rect2:
	return Rect2(Vector2(18,32),map_size-Vector2(36,50))

func clamp_camera() -> void:
	# A window wider than the map (e.g. 4K) must still never expose its outside.
	var previous_zoom := zoom_level
	zoom_level = maxf(zoom_level,maxf(viewport_size.x/map_size.x,viewport_size.y/map_size.y))
	super.clamp_camera()
	if not is_equal_approx(previous_zoom,zoom_level): status_changed.emit()

func set_selected(_value: bool) -> void:
	selected = true
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
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
