class_name WorldPartyMarker
extends Node2D
## World-only portrait token. Original artwork and character frames stay untouched.
const FRAME = preload("res://assets/world/party/wObj1.png")
const BACKGROUND = preload("res://assets/world/party/wObj2.png")
const SIZE := Vector2i(32,32)
const CENTER := Vector2(16,16)
const PORTRAIT_FEET := Vector2(16,32)
var portrait: AnimatedSprite2D
var portrait_mask: Sprite2D

static func interior_mask(frame: Image) -> Image:
	# Flood only the enclosed transparent center, never the outside of the ring.
	# Even partially opaque border pixels stop the flood, preserving its shape.
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
	return result

func setup(frames: SpriteFrames) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background := Sprite2D.new()
	background.name = "wObj2"
	background.texture = BACKGROUND
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
	portrait.sprite_frames = frames
	portrait.centered = false
	portrait_mask.add_child(portrait)
	var border := Sprite2D.new()
	border.name = "wObj1"
	border.texture = FRAME
	border.centered = false
	add_child(border)

func place(world_position: Vector2) -> void:
	position = world_position.round()-CENTER
	# Only the character flips; the two supplied images and mask keep their orientation.
	var anchor_x := CharacterArt.FRAME_SIZE.x-(CharacterArt.BODY_ORIGIN.x+16) if portrait.flip_h else CharacterArt.BODY_ORIGIN.x+16
	portrait.position = PORTRAIT_FEET-Vector2(anchor_x,CharacterArt.FEET_Y)
