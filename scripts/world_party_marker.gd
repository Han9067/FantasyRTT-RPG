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

func setup(frames: SpriteFrames) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background := Sprite2D.new()
	background.name = "wObj2"
	background.texture = BACKGROUND
	background.centered = false
	add_child(background)
	portrait_mask = Sprite2D.new()
	portrait_mask.name = "PortraitMask"
	# Use every white pixel of the supplied background, including its edge alpha.
	# No inset, dilation or recolouring of either supplied image.
	portrait_mask.texture = BACKGROUND
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
