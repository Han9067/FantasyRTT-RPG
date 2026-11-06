class_name CharacterArt
extends RefCounted
## User-supplied char.zip is the visual source of truth. No redrawing or recolouring.
const FRAME_SIZE := Vector2i(64, 64)
const LOOK_COUNT := 1
const FRAME_COUNTS := {"idle": 1, "walk": 4}
# Same union crop for every portrait frame; the original 64x64 files stay untouched.
const PREVIEW_REGION := Rect2(20, 14, 22, 36)
const WORLD_SCALE := 1.0
static var texture_cache: Dictionary = {}
static var preview_cache: Dictionary = {}

static func source_path(gender: int, animation: String, frame: int) -> String:
	assert(gender in [0, 1] and FRAME_COUNTS.has(animation))
	assert(frame >= 0 and frame < FRAME_COUNTS[animation])
	var filename := "idle.png" if animation == "idle" else "walk_%02d.png" % (frame + 1)
	return "res://assets/characters/%s/01/%s" % ["male" if gender == 0 else "female", filename]

static func texture(gender: int, look := 0, animation := "idle", frame := 0) -> Texture2D:
	assert(look == 0, "Only appearance 01 is available for each gender")
	var path := source_path(gender, animation, frame)
	if not texture_cache.has(path):
		texture_cache[path] = load(path)
	return texture_cache[path]

static func preview_texture(source: Texture2D) -> AtlasTexture:
	var key := source.get_instance_id()
	if not preview_cache.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = PREVIEW_REGION
		atlas.filter_clip = true
		preview_cache[key] = atlas
	return preview_cache[key]

static func animations(gender: int, look := 0) -> SpriteFrames:
	assert(look == 0)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation in ["idle", "walk"]:
		frames.add_animation(animation)
		frames.set_animation_loop(animation, true)
		# Preserve the 0.84-second walking cycle; use the uploaded order 1, 2, 3, 4.
		frames.set_animation_speed(animation, 1.0 if animation == "idle" else 1.0 / 0.21)
		for i in range(FRAME_COUNTS[animation]):
			frames.add_frame(animation, texture(gender, look, animation, i))
	return frames
