class_name WorldPartyMarker
extends Node2D
## World-only portrait token. Original artwork and character frames stay untouched.
const FRAME = preload("res://assets/world/party/wObj1.png")
const BACKGROUND = preload("res://assets/world/party/wObj2.png")
const SIZE := Vector2i(32,32)
const CENTER := Vector2(16,16)
const PORTRAIT_FEET := Vector2(16,32)
const BACKGROUND_COLOR := Color("5f553c")
var portrait: AnimatedSprite2D
var portrait_mask: Sprite2D

static func interior_mask(frame: Image) -> Image:
	# Find the enclosed center first. Then extend underneath the entire border,
	# retaining its outer alpha silhouette so the character cannot spill outside.
	var result := Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8)
	var pending: Array[Vector2i] = [Vector2i(CENTER)]
	result.set_pixelv(pending[0],Color.WHITE)
	var index := 0
	while index < pending.size():
		var point := pending[index]
		index += 1
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = point+step
			if not Rect2i(Vector2i.ZERO,SIZE).has_point(next): continue
			if result.get_pixelv(next).a > 0 or frame.get_pixelv(next).a > 0: continue
			result.set_pixelv(next,Color.WHITE)
			pending.append(next)
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			if frame.get_pixel(x,y).a > 0:
				result.set_pixel(x,y,Color(1,1,1,frame.get_pixel(x,y).a))
	return result

func setup(frames: SpriteFrames) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background := Sprite2D.new()
	background.name = "wObj2"
	background.texture = BACKGROUND
	# Preserve the supplied PNG; tint its white fill to match the border at runtime.
	background.self_modulate = BACKGROUND_COLOR
	background.centered = false
	add_child(background)
	portrait_mask = Sprite2D.new()
	portrait_mask.name = "PortraitMask"
	portrait_mask.texture = ImageTexture.create_from_image(interior_mask(FRAME.get_image()))
	portrait_mask.centered = false
	portrait_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(portrait_mask)
	portrait = AnimatedSprite2D.new()
	portrait.name = "Character"
	# Own a single-frame resource; never change the battle/creator animations.
	var still := SpriteFrames.new()
	still.remove_animation("default")
	still.add_animation("idle")
	still.set_animation_loop("idle",false)
	still.add_frame("idle",frames.get_frame_texture("idle",0))
	portrait.sprite_frames = still
	portrait.animation = "idle"
	portrait.centered = false
	portrait_mask.add_child(portrait)
	var border := Sprite2D.new()
	border.name = "wObj1"
	border.texture = FRAME
	border.centered = false
	add_child(border)
	freeze_portrait()

func freeze_portrait() -> void:
	portrait.stop()
	portrait.animation = "idle"
	portrait.frame = 0
	portrait.flip_h = false

func place(world_position: Vector2) -> void:
	position = world_position.round()-CENTER
	freeze_portrait()
	var anchor_x := CharacterArt.BODY_ORIGIN.x+16
	portrait.position = PORTRAIT_FEET-Vector2(anchor_x,CharacterArt.FEET_Y)
