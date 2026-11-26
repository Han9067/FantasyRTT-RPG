class_name CharacterArt
extends RefCounted
## Composite original modular sprites at integer coordinates; never resample source art.
const ROOT := "res://assets/medieval/"
const FRAME_SIZE := Vector2i(136, 104)
const PREVIEW_REGION := Rect2i(0, 0, 136, 104)
const PREVIEW_SCALE := 3
const PRIMARY_WEAPON_PIVOT := Vector2(0.5, 0.5)
const SHIELD_WEAPON_PIVOT := Vector2(0.5, 1.0)
const ARCHER_BOW := "bow/1"
const BOW_OFFHAND_CENTER := Vector2i(4, -2)
const BOW_HOLD_OFFSET := Vector2i(0, 2)
const BOW_OFFSET := Vector2i(1, 0) # Native sprite faces left; flip_h mirrors this offset.
const NON_MELEE_WEAPON_ANCHOR := Vector2i(68, 68)
const WORLD_SCALE := 1.0
const FEET_Y := 80
const FRAME_COUNTS := {"idle": 4, "walk": 4, "attack": 6}
# Original chop_attack_sample.gif: six fixed-body frames, exactly 100ms each.
# Padding accommodates enlarged weapons at their original pixel size.
const BODY_ORIGIN := Vector2i(64, 48)
const CANVAS_PADDING := Vector2i(32, 24)
const ATTACK_BODIES := [0, 0, 0, 0, 0, 0]
# Offsets in native pixels before the whole character is mirrored.
const PRIMARY_GRIP_SHIFT := Vector2i(2, 0)
const CROSSBOW_GRIP_SHIFT := Vector2i(6, 0)
const OFFHAND_GRIP_SHIFT := Vector2i(4, 0)
const EMPTY_OFFHAND_SHIFT := Vector2i(3, 0)
const SHIELD_GRIP_SHIFT := Vector2i(1, 0)
const DEFAULT_OUTFIT := "tunic_green"
const PARTS := [
	["skin", "피부"], ["eye", "눈"], ["body", "복장"],
	["hair", "머리 모양"], ["hair_color", "머리 색상"],
	["weapon", "무기1 종류"],
	["weapon_item", "무기1 번호"], ["offhand", "무기2 종류"], ["offhand_item", "무기2 형태"]
]
const TYPE_LABELS := {"one_axe":"한손 도끼", "one_blunt":"한손 둔기", "one_sword":"한손 검",
	"one_shield":"방패", "two_axe":"양손도끼", "two_blunt":"양손둔기", "two_sword":"양손검",
	"two_polearm":"장병기", "two_spear":"창", "bow":"활", "crossbow":"석궁"}
static var catalog: Dictionary = {}
static var weapons_by_item_id: Dictionary = {}
static var images: Dictionary = {}

static func data() -> Dictionary:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "catalog.json"))
		for item: Dictionary in catalog.weapon_items.values():
			item.equip_type = int(item.equip_type)
			if item.has("item_id"):
				item.item_id = int(item.item_id)
				weapons_by_item_id[item.item_id] = item
	return catalog

static func weapon_by_item_id(item_id: int) -> Dictionary:
	data()
	return weapons_by_item_id.get(item_id, {})

static func defaults() -> Dictionary:
	return {"gender": 0, "skin": 0, "eye": 0, "body": data().body_ids.find(DEFAULT_OUTFIT), "hair": 0, "hair_color": 1,
		"weapon": data().primary_types.find("one_sword"), "weapon_item": 0,
		"offhand": -1, "offhand_item": -1}

static func human_data() -> Dictionary:
	return data().races.human

static func infantry_appearance(allied: bool, variant: int) -> Dictionary:
	var config := defaults()
	config.body = data().body_ids.find("tunic_blue" if allied else "tunic_red")
	config.skin = [1, 3, 0, 5, 2][variant]
	config.eye = [2, 5, 0, 7, 4][variant]
	config.hair = 0
	config.helmet = data().infantry_helmet
	config.equipped_weapon = "one_sword/1"
	config.offhand = data().secondary_types.find("one_shield")
	config.offhand_item = data().melee_groups.one_shield.find("one_shield/27")
	return config

static func archer_appearance(allied: bool, variant: int) -> Dictionary:
	var config := infantry_appearance(allied, variant)
	config.equipped_weapon = ARCHER_BOW
	config.offhand = -1
	config.offhand_item = -1
	return config

static func frame_count(config: Dictionary, animation: String) -> int:
	return 12 if animation == "attack" and equipped_weapon(config).attack == "bow_shot" else FRAME_COUNTS[animation]

static func infantry_frames(config: Dictionary, can_walk: bool) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation in (["idle", "walk", "attack"] if can_walk else ["idle"]):
		frames.add_animation(animation)
		frames.set_animation_speed(animation, 6.0 if animation == "idle" else (10.0 if animation == "attack" else 12.0))
		for i in range(frame_count(config, animation)):
			frames.add_frame(animation, ImageTexture.create_from_image(compose(config, animation, i)))
	return frames

static func primary_items(family: String) -> Array:
	if data().ranged_groups.has(family): return data().ranged_groups[family]
	return data().melee_groups[family]

static func is_primary_melee(family: String) -> bool:
	return family != "one_shield" and data().melee_groups.has(family)

static func count(config: Dictionary, key: String) -> int:
	var human := human_data()
	match key:
		"gender": return human.heads.size()
		"skin": return data().sheets[human.heads[config.gender]].slots.size()
		"eye": return data().sheets[human[key]].slots.size()
		"body": return data().bodies.size()
		"hair": return 1 + data().sheets[human.hair[config.gender][config.hair_color]].slots.size()
		"hair_color": return human.hair[config.gender].size()
		"weapon": return data().primary_types.size()
		"weapon_item": return primary_items(data().primary_types[config.weapon]).size()
		"offhand": return 1 + data().secondary_types.size() if not equipped_weapon(config).two_handed else 0
		"offhand_item":
			if config.offhand < 0 or count(config, "offhand") == 0: return 0
			return data().melee_groups[data().secondary_types[config.offhand]].size()
	return 1

static func selection_order(config: Dictionary, key: String) -> Array:
	# Display order is independent of catalog indices stored in existing presets.
	var order: Array = range(count(config, key))
	if key not in ["weapon", "offhand"] or order.is_empty(): return order
	var types: Array = data().primary_types if key == "weapon" else data().secondary_types
	order.clear()
	if key == "offhand": order.append(-1)
	for family in ["one_sword", "one_axe", "one_blunt", "two_sword", "two_axe", "two_blunt", "two_spear", "two_polearm", "bow"]:
		var index := types.find(family)
		if index >= 0: order.append(index)
	for index in range(types.size()):
		if types[index] != "crossbow" and not order.has(index): order.append(index)
	return order

static func normalize(config: Dictionary) -> void:
	# The creator always produces an unarmoured human; old equipment selections
	# cannot leak into a new character if a previous in-memory config is supplied.
	for key in ["race", "hands", "hat_family", "hat", "hat_color", "beard", "beard_color", "mouth"]:
		config.erase(key)
	for key in ["gender", "skin", "eye", "body", "hair_color", "hair", "weapon", "weapon_item", "offhand", "offhand_item"]:
		var total := count(config, key)
		var first := -1 if key == "offhand" else 0
		config[key] = clampi(int(config.get(key, first)), first, first + total - 1) if total > 0 else -1

static func description(config: Dictionary, key: String) -> String:
	match key:
		"body": return data().body_labels[config.body]
		"hair": return "없음" if config.hair == 0 else ""
		"weapon": return TYPE_LABELS.get(data().primary_types[config.weapon], data().primary_types[config.weapon])
		"offhand":
			if config.offhand < 0: return "미장착"
			var family: String = data().secondary_types[config.offhand]
			return TYPE_LABELS.get(family, family)
	return ""

static func equipped_weapon(config: Dictionary) -> Dictionary:
	var key: String = config.get("equipped_weapon", "")
	if key.begins_with("bow_") and key.substr(4).is_valid_int():
		key = "bow/%d" % int(key.substr(4))
	if data().weapon_items.has(key):
		return data().weapon_items[key]
	var ids: Array = primary_items(data().primary_types[config.weapon])
	return data().weapon_items[ids[config.get("weapon_item", 0)]]

static func equipped_offhand(config: Dictionary) -> Dictionary:
	if config.get("offhand", -1) < 0 or equipped_weapon(config).two_handed:
		return {}
	var ids: Array = data().melee_groups[data().secondary_types[config.offhand]]
	return data().weapon_items[ids[config.get("offhand_item", 0)]]

# Keep weapon, gripping hand and body bob in one pose calculation.
static func pose(animation: String, frame: int, attack_type := "chop_attack", equip_type := 0, family := "", offhand_family := "") -> Dictionary:
	var result := local_pose(animation, frame, attack_type, equip_type)
	result.grip += CANVAS_PADDING
	if equip_type == 3:
		result.grip += BOW_HOLD_OFFSET
		# The hand textures are 16x16. free_hand stores the top-left, grip the center.
		result.free_hand = result.grip + BOW_OFFHAND_CENTER - Vector2i(8, 8)
	else:
		result.free_hand += CANVAS_PADDING
		match offhand_family:
			"": result.free_hand += EMPTY_OFFHAND_SHIFT
			"one_shield": result.free_hand += SHIELD_GRIP_SHIFT
			_: result.free_hand += OFFHAND_GRIP_SHIFT
		if equip_type >= 0:
			var shift := CROSSBOW_GRIP_SHIFT if family == "crossbow" else PRIMARY_GRIP_SHIFT
			result.grip += shift
			result.effect_origin += shift
	result.effect_origin += CANVAS_PADDING
	return result

static func local_pose(animation: String, frame: int, attack_type: String, equip_type: int) -> Dictionary:
	var spear_grip := equip_type == 2
	if equip_type == 3 and animation == "attack":
		return {"bob": 0, "grip": Vector2i(35,43), "free_hand": Vector2i(46,41),
			"rotation": 0, "visible": true, "effect": -1, "effect_origin": Vector2i.ZERO, "body_frame": 0}
	if animation == "attack":
		var grip: Vector2i
		if attack_type == "thrust_attack":
			grip = [Vector2i(35,42), Vector2i(48,48), Vector2i(35,48), Vector2i(35,48), Vector2i(35,48), Vector2i(31,48)][frame]
		else:
			grip = [Vector2i(35,49), Vector2i(41,24), Vector2i(35,49), Vector2i(35,49), Vector2i(35,49), Vector2i(32,47)][frame]
		if attack_type == "thrust_attack":
			return {"bob": 0, "grip": grip, "free_hand": Vector2i(46,41),
				"rotation": 0 if frame == 0 else -1, "visible": frame not in [2,3,4],
				"effect": frame - 2 if frame in [2,3,4] else -1, "body_frame": 0,
				"effect_sheet": data().thrust_effect, "effect_rotation": -1,
				"effect_origin": Vector2i(-2 if frame == 2 else -10,31)}
		# Relative to the chop guide's fixed body origin (22,9).
		return {"bob": 0, "grip": grip, "free_hand": Vector2i(46,41),
			"rotation": [0,1,0,0,0,-1][frame], "visible": frame not in [2,3,4],
			"effect": frame - 2 if frame in [2,3,4] else -1, "body_frame": ATTACK_BODIES[frame],
			"effect_sheet": data().attack_effect, "effect_rotation": 0, "effect_origin": Vector2i(0,21)}
	var bob := int([0, 1, 2, 1][frame]) if animation == "idle" else int([0, 1, 0, -1][frame])
	var swing := 0 if animation == "idle" else int([0, 1, 1, 0][frame])
	return {"bob": bob, "grip": Vector2i(35, (42 if spear_grip else (43 if equip_type == 3 else 49)) + bob + swing), "free_hand": Vector2i(46, 41 + bob - swing),
		"rotation": 0, "visible": true, "effect": -1, "effect_origin": Vector2i.ZERO,
		"body_frame": frame + (4 if animation == "walk" else 0)}

static func rotated_point(point: Vector2i, size: Vector2i, turns: int) -> Vector2i:
	if turns == 1: return Vector2i(size.y - 1 - point.y, point.x)
	if turns == -1: return Vector2i(point.y, size.x - 1 - point.x)
	return point

static func weapon_anchor(config: Dictionary, animation: String, frame: int) -> Vector2i:
	var weapon := equipped_weapon(config)
	var current_pose := pose(animation, frame, weapon.attack, weapon.equip_type, weapon.family)
	# Rotate the sheet adjustment with the weapon around the gripping hand.
	if is_primary_melee(weapon.family):
		var offset := Vector2i(0, -int(weapon.get("y_up", 0)))
		if current_pose.rotation == 1: offset = Vector2i(-offset.y, offset.x)
		elif current_pose.rotation == -1: offset = Vector2i(offset.y, -offset.x)
		return current_pose.grip + offset
	var offset := PRIMARY_GRIP_SHIFT
	if weapon.family == "crossbow": offset = CROSSBOW_GRIP_SHIFT
	if weapon.family == "bow": offset = bow_offset(weapon)
	return NON_MELEE_WEAPON_ANCHOR + offset + current_pose.grip - pose("idle", 0, weapon.attack, weapon.equip_type, weapon.family).grip

static func bow_shot_slot(weapon: Dictionary, frame: int) -> int:
	return (int(weapon.number) - 1) * 12 + frame

static func bow_offset(weapon: Dictionary) -> Vector2i:
	return BOW_HOLD_OFFSET + BOW_OFFSET - Vector2i(0, int(weapon.y_up))

static func weapon_position(config: Dictionary, animation: String, frame: int) -> Vector2i:
	var weapon: Dictionary = equipped_weapon(config)
	var current_pose := pose(animation, frame, weapon.attack, weapon.equip_type, weapon.family)
	var size := part_rect(data().bow_shot, bow_shot_slot(weapon, frame)).size if weapon.attack == "bow_shot" and animation == "attack" else part_rect(weapon.sheet, weapon.slot).size
	if is_primary_melee(weapon.family):
		# Use the same pixel-center rotation as the hand and Image.rotate_90.
		var pivot := Vector2i(Vector2(size) * PRIMARY_WEAPON_PIVOT)
		return weapon_anchor(config, animation, frame) - rotated_point(pivot, size, current_pose.rotation)
	var pivot := SHIELD_WEAPON_PIVOT if weapon.family == "one_shield" else PRIMARY_WEAPON_PIVOT
	return weapon_anchor(config, animation, frame) - weapon_pivot_offset(size, current_pose.rotation, pivot)

static func weapon_pivot_offset(size: Vector2i, turns: int, normalized_pivot := PRIMARY_WEAPON_PIVOT) -> Vector2i:
	# Rotate the original image-boundary pivot with the art, not the rotated AABB's bottom.
	var pivot := Vector2(size) * normalized_pivot
	if turns == 1: pivot = Vector2(size.y - pivot.y, pivot.x)
	elif turns == -1: pivot = Vector2(pivot.y, size.x - pivot.x)
	return Vector2i(pivot)

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
	assert(FRAME_COUNTS.has(animation) and frame >= 0 and frame < frame_count(config, animation))
	var img := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var base := BODY_ORIGIN
	# World portraits omit equipment without changing the saved loadout or body parts.
	var weapon := equipped_weapon(config) if include_weapon else {}
	var secondary := equipped_offhand(config) if include_weapon else {}
	var shield: bool = secondary.get("family", "") == "one_shield"
	var current_pose := pose(animation, frame, weapon.get("attack", "chop_attack"), weapon.get("equip_type", -1), weapon.get("family", ""), secondary.get("family", ""))
	var head := base + Vector2i(0, current_pose.bob)
	var race := human_data()
	var body_index: int = current_pose.body_frame
	paste(img, data().bodies[config.body], body_index, base)
	paste(img, race.heads[config.gender], config.skin, head)
	paste(img, race.eye, config.eye, head)
	if config.has("helmet"):
		paste(img, config.helmet, 0, head + Vector2i(0, -2))
	elif config.hair > 0:
		paste(img, race.hair[config.gender][config.hair_color], config.hair - 1, head)
	# Draw back to front. A shield covers the secondary hand; the primary hand is foremost.
	var offhand_position := Vector2i.ZERO
	if not secondary.is_empty():
		offhand_position = current_pose.free_hand + Vector2i(8, 8) - Vector2i(secondary.grip[0], secondary.grip[1])
		if not shield:
			paste(img, secondary.sheet, secondary.slot, offhand_position)
	if include_weapon and current_pose.visible:
		if weapon.attack == "bow_shot" and animation == "attack":
			paste(img, data().bow_shot, bow_shot_slot(weapon, frame), weapon_position(config, animation, frame))
		else:
			paste_rotated(img, weapon.sheet, weapon.slot, weapon_position(config, animation, frame), current_pose.rotation)
	if include_weapon and current_pose.effect >= 0:
		paste_rotated(img, current_pose.effect_sheet, current_pose.effect, current_pose.effect_origin, current_pose.effect_rotation)
	if weapon.get("equip_type", 0) in [0, 3]:
		paste(img, race.hand, config.skin, current_pose.free_hand)
	if shield:
		paste(img, secondary.sheet, secondary.slot, offhand_position)
	if current_pose.visible:
		var hand_origin: Vector2i = current_pose.grip - rotated_point(Vector2i(8, 8), Vector2i(16, 16), current_pose.rotation)
		paste_rotated(img, race.hand, config.skin, hand_origin, current_pose.rotation)
	return img

static func animations(config: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var textures: Array[Texture2D] = []
	var timing: Dictionary = data().attack_references[equipped_weapon(config).attack]
	for animation in FRAME_COUNTS:
		frames.add_animation(animation)
		frames.set_animation_loop(animation, true)
		frames.set_animation_speed(animation, 6.0 if animation == "idle" else (10.0 if animation == "attack" else 12.0))
		for i in range(frame_count(config, animation)):
			var image := compose(config, animation, i)
			var texture := ImageTexture.create_from_image(image)
			textures.append(texture)
			frames.add_frame(animation, texture, float(timing.durations_ms[i]) / 100.0 if animation == "attack" else 1.0)
	# One equipment-independent padded canvas keeps the scale fixed in every pose.
	for texture in textures:
		texture.set_meta("preview_region", Rect2(PREVIEW_REGION))
	return frames

static func preview_texture(source: Texture2D) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	var canvas := Rect2(Vector2.ZERO, source.get_size())
	var crop: Rect2 = source.get_meta("preview_region", canvas)
	atlas.region = crop.intersection(canvas)
	# Long equipment can require symmetric transparent space outside the frame.
	atlas.margin = Rect2(atlas.region.position - crop.position, crop.size - atlas.region.size)
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
