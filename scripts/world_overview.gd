extends Control
## Drag the viewport rectangle with a stable grab offset; never orders the party.
var world: WorldMap
var camera_dragging := false
var grab_offset := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = "사각형 내부를 잡아 끌면 카메라가 이동합니다."

func map_bounds() -> Rect2:
	var available := (size-Vector2(12,12)).max(Vector2.ONE)
	if not is_instance_valid(world): return Rect2(Vector2(6,6),available)
	# Preserve the uploaded map's aspect ratio instead of stretching it to the panel.
	var factor := minf(available.x/world.map_size.x,available.y/world.map_size.y)
	var fitted := world.map_size*factor
	return Rect2((size-fitted)*0.5,fitted)

func camera_rect() -> Rect2:
	var bounds := map_bounds()
	var factor := bounds.size / world.map_size
	var a := world.screen_to_world(Vector2.ZERO) * factor + bounds.position
	var b := world.screen_to_world(world.viewport_size) * factor + bounds.position
	return Rect2(a,b-a).intersection(bounds)

func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(world): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and camera_rect().has_point(event.position):
			camera_dragging = true
			grab_offset = event.position - camera_rect().get_center()
			world.pan_keys.clear()
		elif not event.pressed:
			camera_dragging = false
		accept_event()
	elif event is InputEventMouseMotion:
		if camera_dragging:
			var bounds := map_bounds()
			world.camera.position = (event.position - grab_offset - bounds.position) / bounds.size * world.map_size
			world.clamp_camera()
			accept_event()
		mouse_default_cursor_shape = Control.CURSOR_MOVE if camera_dragging or camera_rect().has_point(event.position) else Control.CURSOR_ARROW

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_RESIZED]:
		camera_dragging = false
		mouse_default_cursor_shape = Control.CURSOR_ARROW

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world): return
	var bounds := map_bounds()
	draw_rect(Rect2(Vector2.ZERO,size),Color("26352be8"))
	draw_texture_rect(WorldMap.TERRAIN,bounds,false)
	var view := camera_rect()
	draw_rect(view,Color(1,0.9,0.6,0.12))
	draw_rect(view,Color("fff1be") if camera_dragging else Color("f0dfac"),false,1)
	var p := bounds.position + world.unit_position / world.map_size * bounds.size
	draw_circle(p,3,Color("283c2b"))
	draw_rect(Rect2(p-Vector2(1,1),Vector2(3,3)),Color("fff2b7"))
	draw_rect(bounds,Color("ab9868"),false,1)
