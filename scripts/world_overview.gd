extends Control
## A read-only atlas inset: terrain, viewport footprint and the party's position.
var world: WorldMap
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(world): return
	var bounds := Rect2(Vector2(6,6),size-Vector2(12,12))
	draw_rect(Rect2(Vector2.ZERO,size),Color("26352be8"))
	draw_texture_rect(WorldMap.TERRAIN,bounds,false)
	var factor := bounds.size / world.map_size
	var a := world.screen_to_world(Vector2.ZERO) * factor + bounds.position
	var b := world.screen_to_world(world.viewport_size) * factor + bounds.position
	draw_rect(Rect2(a,b-a).intersection(bounds),Color("f0dfac"),false,1)
	var p := bounds.position + world.unit_position * factor
	draw_circle(p,3,Color("283c2b"))
	draw_rect(Rect2(p-Vector2(1,1),Vector2(3,3)),Color("fff2b7"))
	draw_rect(bounds,Color("ab9868"),false,1)
