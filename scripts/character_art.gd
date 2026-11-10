class_name CharacterArt
extends RefCounted
## Composite original modular sprites at integer coordinates; never resample source art.
const ROOT := "res://assets/medieval/"
const FRAME_SIZE := Vector2i(128, 96)
const PREVIEW_REGION := Rect2(32, 20, 80, 56)
const WORLD_SCALE := 1.0
const FEET_Y := 72
const FRAME_COUNTS := {"idle": 4, "walk": 8, "run": 8, "attack": 6}
# Original chop_attack_sample.gif: six fixed-body frames, exactly 100ms each.
# Padding accommodates enlarged weapons; starter previews retain their previous scale.
const BODY_ORIGIN := Vector2i(64, 40)
const CANVAS_PADDING := Vector2i(32, 16)
const ATTACK_BODIES := [0, 0, 0, 0, 0, 0]
const ATTACK_EFFECT_ORIGIN := Vector2i(32, 37)
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

# Equipment IDs are independent of the creator's three starter choices.
static func equipped_weapon(config: Dictionary) -> Dictionary:
	if config.has("equipped_weapon"):
		return data().weapon_items[config.equipped_weapon]
	return data().weapons[config.weapon]

# Keep weapon, gripping hand and body bob in one pose calculation.
static func pose(animation: String, frame: int, attack_type := "chop_attack") -> Dictionary:
	var result := local_pose(animation, frame, attack_type)
	result.grip += CANVAS_PADDING
	result.free_hand += CANVAS_PADDING
	result.effect_origin += CANVAS_PADDING
	return result

static func local_pose(animation: String, frame: int, attack_type: String) -> Dictionary:
	if animation == "attack":
		if attack_type == "thrust_attack":
			# Original thrust guide: upright guard, horizontal preparation, three
			# straight impact trails, extended horizontal recovery. Fixed body.
			var grip: Vector2i = [Vector2i(35,42), Vector2i(48,48), Vector2i(35,48), Vector2i(35,48), Vector2i(35,48), Vector2i(31,48)][frame]
			return {"bob": 0, "grip": grip, "free_hand": Vector2i(46,41),
				"rotation": 0 if frame == 0 else -1, "visible": frame not in [2,3,4],
				"effect": frame - 2 if frame in [2,3,4] else -1, "body_frame": 0,
				"effect_sheet": data().thrust_effect, "effect_rotation": -1,
				"effect_origin": Vector2i(-2 if frame == 2 else -10,31)}
		# Relative to the chop guide's fixed body origin (22,9).
		var grip: Vector2i = [Vector2i(35,49), Vector2i(41,24), Vector2i(35,49), Vector2i(35,49), Vector2i(35,49), Vector2i(32,47)][frame]
		return {"bob": 0, "grip": grip, "free_hand": Vector2i(46,41),
			"rotation": [0,1,0,0,0,-1][frame], "visible": frame not in [2,3,4],
			"effect": frame - 2 if frame in [2,3,4] else -1, "body_frame": ATTACK_BODIES[frame],
			"effect_sheet": data().attack_effect, "effect_rotation": 0, "effect_origin": Vector2i(0,21)}
	var bob := int([0, 1, 2, 1][frame]) if animation == "idle" else int([0, 1, 0, -1, 0, 1, 0, -1][frame])
	var swing := 0 if animation == "idle" else int([0, 1, 1, 0, 0, -1, -1, 0][frame])
	return {"bob": bob, "grip": Vector2i(35, (42 if attack_type == "thrust_attack" else 49) + bob + swing), "free_hand": Vector2i(46, 41 + bob - swing),
		"rotation": 0, "visible": true, "effect": -1, "effect_origin": Vector2i.ZERO,
		"body_frame": frame + (0 if animation == "idle" else (4 if animation == "walk" else 12))}

static func rotated_point(point: Vector2i, size: Vector2i, turns: int) -> Vector2i:
	if turns == 1: return Vector2i(size.y - 1 - point.y, point.x)
	if turns == -1: return Vector2i(point.y, size.x - 1 - point.x)
	return point

static func weapon_position(config: Dictionary, animation: String, frame: int) -> Vector2i:
	var weapon: Dictionary = equipped_weapon(config)
	var current_pose := pose(animation, frame, weapon.attack)
	var grip := Vector2i(int(weapon.grip[0]), int(weapon.grip[1]))
	return current_pose.grip - rotated_point(grip, part_rect(weapon.sheet, weapon.slot).size, current_pose.rotation)

static func atlas_image(filename: String) -> Image:
	if not images.has(filename):
		var img: Image = (load(ROOT + filename) as Texture2D).get_image()
		img.convert(Image.FORMAT_RGBA8)
		images[filename] = img
	return images[filename]

static func part_rect(path: String, index: int) -> Rect2i:
	var q: Array = data().sheets[path].slots[index].rect
	return Rect2i(int(q[0]), int(q[1]), int(q[2]), int(q[3]))

static func part_image(path: String, index: int) -> Image:
	return atlas_image(data().sheets[path].slots[index].atlas).get_region(part_rect(path, index))

static func paste(target: Image, path: String, index: int, position: Vector2i) -> void:
	target.blend_rect(atlas_image(data().sheets[path].slots[index].atlas), part_rect(path, index), position)

static func paste_rotated(target: Image, path: String, index: int, position: Vector2i, turns: int) -> void:
	if turns == 0:
		paste(target, path, index, position)
		return
	var part := part_image(path, index)
	part.rotate_90(CLOCKWISE if turns == 1 else COUNTERCLOCKWISE)
	target.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), position)

static func compose(config: Dictionary, animation := "idle", frame := 0, include_weapon := true) -> Image:
	assert(FRAME_COUNTS.has(animation) and frame >= 0 and frame < FRAME_COUNTS[animation])
	var img := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var base := BODY_ORIGIN
	# World portraits omit equipment without changing the saved loadout or body parts.
	var attack_type: String = equipped_weapon(config).attack if include_weapon else "chop_attack"
	var current_pose := pose(animation, frame, attack_type)
	var head := base + Vector2i(0, current_pose.bob)
	var race := human_data()
	var body_index: int = current_pose.body_frame
	paste(img, data().bodies[config.body], body_index, base)
	if include_weapon and current_pose.visible:
		var weapon := equipped_weapon(config)
		paste_rotated(img, weapon.sheet, weapon.slot, weapon_position(config, animation, frame), current_pose.rotation)
	paste(img, race.heads[config.skin], config.face, head)
	if config.hair > 0:
		paste(img, race.hair[config.hair_color], config.hair - 1, head)
	if config.beard > 0:
		paste(img, race.beard[config.beard_color], config.beard - 1, head)
	# Skin indices share the original human hand palette. No glove override.
	var hand_path: String = race.hand
	if current_pose.visible:
		var hand_origin: Vector2i = current_pose.grip - rotated_point(Vector2i(8, 8), Vector2i(16, 16), current_pose.rotation)
		paste_rotated(img, hand_path, config.skin, hand_origin, current_pose.rotation)
	paste(img, hand_path, config.skin, current_pose.free_hand)
	if include_weapon and current_pose.effect >= 0:
		paste_rotated(img, current_pose.effect_sheet, current_pose.effect, current_pose.effect_origin, current_pose.effect_rotation)
	return img

static func animations(config: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var textures: Array[Texture2D] = []
	var preview_region := Rect2i(PREVIEW_REGION)
	var timing: Dictionary = data().attack_references[equipped_weapon(config).attack]
	for animation in FRAME_COUNTS:
		frames.add_animation(animation)
		frames.set_animation_loop(animation, true)
		frames.set_animation_speed(animation, 6.0 if animation == "idle" else (10.0 if animation == "attack" else 12.0))
		for i in range(FRAME_COUNTS[animation]):
			var image := compose(config, animation, i)
			var texture := ImageTexture.create_from_image(image)
			textures.append(texture)
			preview_region = preview_region.merge(image.get_used_rect())
			frames.add_frame(animation, texture, float(timing.durations_ms[i]) / 100.0 if animation == "attack" else 1.0)
	# Use one crop for every pose, so long equipment stays visible without camera jitter.
	for texture in textures:
		texture.set_meta("preview_region", Rect2(preview_region))
	return frames

static func preview_texture(source: Texture2D) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = source.get_meta("preview_region", PREVIEW_REGION)
	atlas.filter_clip = true
	return atlas

static func frame_at_time(frames: SpriteFrames, animation: String, elapsed: float) -> int:
	var total := 0.0
	for i in range(frames.get_frame_count(animation)):
		total += frames.get_frame_duration(animation, i)
	var cursor := fposmod(elapsed * frames.get_animation_speed(animation), total)
	for i in range(frames.get_frame_count(animation)):
		cursor -= frames.get_frame_duration(animation, i)
		if cursor < 0.0: return i
	return 0
