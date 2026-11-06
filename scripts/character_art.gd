class_name CharacterArt
extends RefCounted
## Composite original modular sprites at integer coordinates; never resample source art.
const ROOT := "res://assets/medieval/"
const FRAME_SIZE := Vector2i(64, 64)
const PREVIEW_REGION := Rect2(8, 4, 48, 56)
const WORLD_SCALE := 1.0
const FEET_Y := 56
const FRAME_COUNTS := {"idle": 4, "walk": 8, "run": 8}
const BODY_LABELS := ["검정", "파랑", "갈색", "금색", "초록", "회색", "주황", "분홍", "보라", "빨강", "은색", "노랑"]
const PARTS := [
	["skin", "피부색"], ["face", "얼굴"], ["body", "복장 색상"],
	["hair", "머리 모양"], ["hair_color", "머리 색상"],
	["beard", "수염 모양"], ["beard_color", "수염 색상"], ["weapon", "무기"]
]
static var catalog: Dictionary = {}
static var images: Dictionary = {}

static func data() -> Dictionary:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "catalog.json"))
	return catalog

static func defaults() -> Dictionary:
	return {"skin": 0, "face": 0, "body": 4, "hair": 1, "hair_color": 1,
		"beard": 0, "beard_color": 1, "weapon": 0}

static func human_data() -> Dictionary:
	return data().races.human

static func count(config: Dictionary, key: String) -> int:
	var human := human_data()
	match key:
		"skin": return human.heads.size()
		"face": return data().sheets[human.heads[config.skin]].slots.size()
		"body": return data().bodies.size()
		"hair": return 1 + data().sheets[human.hair[config.hair_color]].slots.size()
		"hair_color": return human.hair.size()
		"beard": return 1 + data().sheets[human.beard[config.beard_color]].slots.size()
		"beard_color": return human.beard.size()
		"weapon": return data().weapons.size()
	return 1

static func normalize(config: Dictionary) -> void:
	# The creator always produces an unarmoured human; old equipment selections
	# cannot leak into a new character if a previous in-memory config is supplied.
	for key in ["race", "hands", "hat_family", "hat", "hat_color"]:
		config.erase(key)
	for key in ["skin", "face", "body", "hair_color", "hair", "beard_color", "beard", "weapon"]:
		config[key] = clampi(int(config.get(key, 0)), 0, count(config, key) - 1)

static func description(config: Dictionary, key: String) -> String:
	match key:
		"body": return BODY_LABELS[config.body]
		"hair": return "없음" if config.hair == 0 else ""
		"beard": return "없음" if config.beard == 0 else ""
		"weapon": return data().weapons[config.weapon].label
	return ""

# Keep weapon, gripping hand and body bob in one pose calculation.
static func pose(animation: String, frame: int) -> Dictionary:
	var bob := int([0, 1, 2, 1][frame]) if animation == "idle" else int([0, 1, 0, -1, 0, 1, 0, -1][frame])
	var swing := 0 if animation == "idle" else int([0, 1, 1, 0, 0, -1, -1, 0][frame])
	return {"bob": bob, "grip": Vector2i(20, 49 + bob + swing), "free_hand": Vector2i(30, 41 + bob - swing)}

static func weapon_position(config: Dictionary, animation: String, frame: int) -> Vector2i:
	var grip: Array = data().weapons[config.weapon].grip
	return pose(animation, frame).grip - Vector2i(int(grip[0]), int(grip[1]))

static func sheet_image(path: String) -> Image:
	if not images.has(path):
		var img: Image = (load(ROOT + path) as Texture2D).get_image()
		img.convert(Image.FORMAT_RGBA8)
		images[path] = img
	return images[path]

static func part_rect(path: String, index: int) -> Rect2i:
	var q: Array = data().sheets[path].slots[index].rect
	return Rect2i(int(q[0]), int(q[1]), int(q[2]), int(q[3]))

static func paste(target: Image, path: String, index: int, position: Vector2i) -> void:
	target.blend_rect(sheet_image(path), part_rect(path, index), position)

static func compose(config: Dictionary, animation := "idle", frame := 0) -> Image:
	assert(FRAME_COUNTS.has(animation) and frame >= 0 and frame < FRAME_COUNTS[animation])
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var base := Vector2i(16, 24)
	var current_pose := pose(animation, frame)
	var head := base + Vector2i(0, current_pose.bob)
	var race := human_data()
	var body_index := frame + (0 if animation == "idle" else (4 if animation == "walk" else 12))
	paste(img, data().bodies[config.body], body_index, base)
	var weapon: Dictionary = data().weapons[config.weapon]
	paste(img, weapon.sheet, weapon.slot, weapon_position(config, animation, frame))
	paste(img, race.heads[config.skin], config.face, head)
	if config.hair > 0:
		paste(img, race.hair[config.hair_color], config.hair - 1, head)
	if config.beard > 0:
		paste(img, race.beard[config.beard_color], config.beard - 1, head)
	# Skin indices share the original human hand palette. No glove override.
	var hand_path: String = race.hand
	paste(img, hand_path, config.skin, current_pose.grip - Vector2i(8, 8))
	paste(img, hand_path, config.skin, current_pose.free_hand)
	return img

static func animations(config: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation in FRAME_COUNTS:
		frames.add_animation(animation)
		frames.set_animation_loop(animation, true)
		frames.set_animation_speed(animation, 6.0 if animation == "idle" else 12.0)
		for i in range(FRAME_COUNTS[animation]):
			frames.add_frame(animation, ImageTexture.create_from_image(compose(config, animation, i)))
	return frames

static func preview_texture(source: Texture2D) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = PREVIEW_REGION
	atlas.filter_clip = true
	return atlas
