class_name CharacterArt
extends RefCounted
## Side-profile adaptation of the uploaded adventurers. Separate 32×36 layers, body then head.
## Originals remain available for reference through use_original=true.
const FRAME_SIZE := Vector2i(32, 36)
const SELECTED_NUMBERS := [1, 2, 3, 4]
const SOURCE_FRAMES := {"idle": [0, 1], "walk": [0, 1, 2, 3]}
const ORIGINAL_FRAMES := {"idle": [0, 2], "walk": [1, 3, 5, 7]}
static var sheet_cache: Dictionary = {}

static func layer_texture(gender: int, number: int, animation: String, frame: int, part: String, use_original := false) -> AtlasTexture:
	assert(gender in [0, 1] and number >= 1 and number <= 32)
	assert(part in ["body", "head"] and SOURCE_FRAMES.has(animation))
	var directory := "adventurers" if use_original else "adventurers_side"
	var path := "res://assets/%s/%s/%02d/%s_%s_sheet.png" % [directory,"male" if gender == 0 else "female", number, animation, part]
	if not sheet_cache.has(path):
		sheet_cache[path] = load(path)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet_cache[path]
	var mapping: Dictionary = ORIGINAL_FRAMES if use_original else SOURCE_FRAMES
	var column: int = mapping[animation][frame]
	atlas.region = Rect2(column * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
	atlas.filter_clip = true
	return atlas

static func texture(gender: int, look: int, animation := "idle", frame := 0, use_original := false) -> Texture2D:
	var number: int = SELECTED_NUMBERS[look]
	var body := layer_texture(gender, number, animation, frame, "body", use_original).get_image()
	var head := layer_texture(gender, number, animation, frame, "head", use_original).get_image()
	# Compose once for each animation frame; keep the original separate layers available for equipment.
	body.convert(Image.FORMAT_RGBA8)
	head.convert(Image.FORMAT_RGBA8)
	body.blend_rect(head, Rect2i(Vector2i.ZERO, FRAME_SIZE), Vector2i.ZERO)
	return ImageTexture.create_from_image(body)

static func animations(gender: int, look: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation in ["idle", "walk"]:
		frames.add_animation(animation)
		frames.set_animation_loop(animation, true)
		# Keep the original cycle duration after reducing frames: 4×330 ms and 8×105 ms.
		frames.set_animation_speed(animation, 1.0 / 0.66 if animation == "idle" else 1.0 / 0.21)
		for i in range(SOURCE_FRAMES[animation].size()):
			frames.add_frame(animation, texture(gender, look, animation, i))
	return frames
