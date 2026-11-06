class_name CharacterArt
extends RefCounted
## Composite original modular sprites at integer coordinates; never resample source art.
const ROOT := "res://assets/medieval/"
const FRAME_SIZE := Vector2i(64, 64)
const PREVIEW_REGION := Rect2(8, 4, 48, 56)
const WORLD_SCALE := 1.0
const FEET_Y := 56
const FRAME_COUNTS := {"idle": 4, "walk": 8, "run": 8}
const RACES := ["human", "elf", "goblin", "orc"]
const RACE_LABELS := ["인간", "엘프", "고블린", "오크"]
const BODY_LABELS := ["검정", "파랑", "갈색", "금색", "초록", "회색", "주황", "분홍", "보라", "빨강", "은색", "노랑"]
const PARTS := [
	["race", "종족"], ["skin", "피부색"], ["face", "얼굴"],
	["body", "복장 색상"], ["hair", "머리 모양"], ["hair_color", "머리 색상"],
	["beard", "수염 모양"], ["beard_color", "수염 색상"], ["hands", "손 · 장갑"],
	["hat_family", "모자 · 투구 종류"], ["hat", "모자 · 투구 모양"], ["hat_color", "모자 · 투구 색상"]
]
static var catalog: Dictionary = {}
static var images: Dictionary = {}

static func data() -> Dictionary:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "catalog.json"))
	return catalog

static func defaults() -> Dictionary:
	return {"race": 0, "skin": 0, "face": 0, "body": 4, "hair": 1, "hair_color": 1,
		"beard": 0, "beard_color": 1, "hands": 0, "hat_family": 0, "hat": 0, "hat_color": 0}

static func race_data(config: Dictionary) -> Dictionary:
	return data().races[RACES[config.race]]

static func count(config: Dictionary, key: String) -> int:
	var race := race_data(config)
	var hats: Dictionary = data().headgear[config.hat_family]
	match key:
		"race": return RACES.size()
		"skin": return race.heads.size()
		"face": return data().sheets[race.heads[config.skin]].slots.size()
		"body": return data().bodies.size()
		"hair": return 1 + data().sheets[race.hair[config.hair_color]].slots.size()
		"hair_color": return race.hair.size()
		"beard": return 1 + data().sheets[race.beard[config.beard_color]].slots.size()
		"beard_color": return race.beard.size()
		"hands": return 1 + data().sheets[data().gloves].slots.size()
		"hat_family": return data().headgear.size()
		"hat_color": return maxi(1, hats.sheets.size())
		"hat":
			if hats.sheets.is_empty(): return 1
			return data().sheets[hats.sheets[config.hat_color]].slots.size()
	return 1

static func normalize(config: Dictionary) -> void:
	# Normalize dependencies before looking up their children.
	for key in ["race", "skin", "face", "body", "hair_color", "hair", "beard_color", "beard", "hands", "hat_family", "hat_color", "hat"]:
		config[key] = clampi(int(config.get(key, 0)), 0, count(config, key) - 1)

static func description(config: Dictionary, key: String) -> String:
	match key:
		"race": return RACE_LABELS[config.race]
		"body": return BODY_LABELS[config.body]
		"hair": return "없음" if config.hair == 0 else ("착용 장비에 가려짐" if config.hat_family != 0 else "")
		"beard": return "없음" if config.beard == 0 else ""
		"hands": return "맨손 · 피부색 연동" if config.hands == 0 else "장갑"
		"hat_family": return data().headgear[config.hat_family].label
		"hat", "hat_color": return "없음" if config.hat_family == 0 else ("단일 색상" if key == "hat_color" and count(config, key) == 1 else "")
	return ""

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
	var bob := int([0, 1, 2, 1][frame]) if animation == "idle" else int([0, 1, 0, -1, 0, 1, 0, -1][frame])
	var head := base + Vector2i(0, bob)
	var race := race_data(config)
	var body_index := frame + (0 if animation == "idle" else (4 if animation == "walk" else 12))
	paste(img, data().bodies[config.body], body_index, base)
	paste(img, race.heads[config.skin], config.face, head)
	if config.hair > 0 and config.hat_family == 0:
		paste(img, race.hair[config.hair_color], config.hair - 1, head)
	if config.beard > 0:
		paste(img, race.beard[config.beard_color], config.beard - 1, head)
	if config.hat_family > 0:
		var hat_path: String = data().headgear[config.hat_family].sheets[config.hat_color]
		var height := part_rect(hat_path, config.hat).size.y
		paste(img, hat_path, config.hat, head + Vector2i(0, -5 - (height - 32)))
	var hand_path: String = race.hand if config.hands == 0 else data().gloves
	var hand_index: int = mini(config.skin, data().sheets[hand_path].slots.size() - 1) if config.hands == 0 else config.hands - 1
	var swing := 0 if animation == "idle" else int([0, 1, 1, 0, 0, -1, -1, 0][frame])
	paste(img, hand_path, hand_index, base + Vector2i(0, 17 + bob + swing))
	paste(img, hand_path, hand_index, base + Vector2i(14, 17 + bob - swing))
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
