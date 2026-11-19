extends SceneTree
const Art = preload("res://scripts/character_art.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 800)
	var catalog := Art.data()
	assert(catalog.schema == 6 and catalog.atlases.size() == 2)
	assert(not DirAccess.dir_exists_absolute("res://art/medieval/sprites/Characters/elf"))
	assert(not DirAccess.dir_exists_absolute("res://art/medieval/sprites/Characters/body/body_black 1"))
	assert(not DirAccess.dir_exists_absolute("res://art/medieval/sprites/Characters/body/body_black 2"))
	assert(not DirAccess.dir_exists_absolute("res://docs/asset-guides"))
	var part_count := 0
	for path in catalog.sheets:
		var entry: Dictionary = catalog.sheets[path]
		for i in range(entry.slots.size()):
			var slot: Dictionary = entry.slots[i]
			assert(not slot.source.contains("__r"))
			assert(i == 0 or slot.id > entry.slots[i - 1].id, "Renamed parts changed their selection order")
			var bytes := FileAccess.get_file_as_bytes("res://art/medieval/" + slot.source)
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(bytes)
			assert(hash.finish().hex_encode() == slot.sha256, "Loose PNG changed after packing")
			var original := Image.new()
			original.load_png_from_buffer(bytes)
			original.convert(Image.FORMAT_RGBA8)
			assert(original.get_size() == Art.part_rect(path, i).size)
			assert(original.get_data() == Art.part_image(path, i).get_data(), "Atlas/import changed source pixels")
			assert(Rect2i(Vector2i.ZERO, Art.atlas_image(slot.atlas).get_size()).encloses(Art.part_rect(path, i)))
			part_count += 1
	assert(part_count == 1246)
	var config := Art.defaults()
	assert(Art.count(config, "face") == 40)
	assert(Art.count(config, "body") == 12)
	assert(Art.count(config, "hair") == 31 and Art.count(config, "beard") == 30)
	assert(Art.count(config, "weapon") == 10 and Art.count(config, "offhand") == 4)
	assert(catalog.weapon_items.size() == 159)
	assert(not catalog.primary_types.has("one_shield"))
	assert(catalog.secondary_types == ["one_axe", "one_blunt", "one_shield", "one_sword"])
	assert(Art.PRIMARY_WEAPON_PIVOT == Vector2(0.5,0.5))
	assert(Art.weapon_pivot_offset(Vector2i(32,64),0) == Vector2i(16,32))
	assert(Art.weapon_pivot_offset(Vector2i(32,64),1) == Vector2i(32,16))
	assert(Art.weapon_pivot_offset(Vector2i(32,64),-1) == Vector2i(32,16))
	verify_equipment(catalog)
	verify_shield_layers()
	config.offhand = catalog.secondary_types.find("one_sword")
	for skin in range(Art.count(config, "skin")):
		config.skin = skin
		for face in range(40):
			config.face = face
			assert(not Art.compose(config).is_invisible())
		for weapon_index in range(3):
			config.weapon = weapon_index
			var weapon: Dictionary = Art.equipped_weapon(config)
			var preview := Art.preview_texture(Art.animations(config).get_frame_texture("idle", 0))
			for animation in Art.FRAME_COUNTS:
				for frame in range(Art.FRAME_COUNTS[animation]):
					var pose := Art.pose(animation, frame)
					var position := Art.weapon_position(config, animation, frame)
					assert(position + Art.rotated_point(Vector2i(16,16),Vector2i(32,32),pose.rotation) == Art.weapon_anchor(config,animation,frame), "Primary weapon image center must use the hand anchor")
					var art := Art.compose(config, animation, frame)
					assert(Rect2i(preview.region).encloses(art.get_used_rect()), "Weapon clipped in preview")
					# Verify both visible hands use exactly the selected skin, overlaid above the weapon.
					var hand_path: String = Art.human_data().hand
					var hand := Art.part_image(hand_path, skin)
					var offsets: Array = [pose.free_hand]
					if pose.visible and pose.rotation == 0:
						offsets.append(pose.grip - Vector2i(8, 8))
					for offset in offsets:
						for y in range(16):
							for x in range(16):
								if hand.get_pixel(x, y).a == 1.0:
									assert(art.get_pixelv(offset + Vector2i(x, y)) == hand.get_pixel(x, y), "Hand skin differs from selected skin")
					if pose.effect >= 0:
						assert(not pose.visible)
						var effect := Art.part_image(catalog.attack_effect, pose.effect)
						for y in range(effect.get_height()):
							for x in range(effect.get_width()):
								if effect.get_pixel(x,y).a == 1.0:
									assert(art.get_pixelv(Vector2i(x,y) + Art.ATTACK_EFFECT_ORIGIN) == effect.get_pixel(x,y), "Guide attack trail missing")
	# Guide phases remain distinct, rotations are exact quarter turns, recovery closes the loop.
	config = Art.defaults()
	for weapon_index in range(3):
		config.weapon = weapon_index
		var unique := {}
		for frame in range(6):
			unique[Art.compose(config, "attack", frame).get_data().hex_encode()] = true
		assert(unique.size() == 6)
		assert(Art.compose(config,"attack",0).get_data() == Art.compose(config,"idle",0).get_data())
	for frame in range(6):
		assert(Art.pose("attack",frame).body_frame == 0 and Art.pose("attack",frame).bob == 0)
	assert(Art.pose("attack",5).grip.x < Art.BODY_ORIGIN.x + 8, "Follow-through hand crossed the torso")
	var timing = catalog.attack_references.chop_attack
	var attack_frames := Art.animations(Art.defaults())
	assert(attack_frames.get_frame_count("attack") == timing.frames)
	for frame in range(timing.frames):
		assert(is_equal_approx(attack_frames.get_frame_duration("attack",frame) / attack_frames.get_animation_speed("attack"), timing.durations_ms[frame] / 1000.0))
	assert(Art.frame_at_time(attack_frames,"attack",0.599) == 5)
	assert(Art.frame_at_time(attack_frames,"attack",0.601) == 0)
	assert(Art.pose("attack",1).rotation == 1 and Art.pose("attack",5).rotation == -1)
	config.merge({"race": 3, "hands": 12, "hat_family": 6, "hat_color": 7, "hat": 22})
	Art.normalize(config)
	for hidden in ["race", "hands", "hat_family", "hat_color", "hat"]:
		assert(not config.has(hidden))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.game_version == "0.0.48")
	for item: Dictionary in Art.data().weapon_items.values():
		assert(item["is_unique"] is bool)
	assert(Art.weapon_by_item_id(1011).is_unique and not Art.weapon_by_item_id(1001).is_unique)
	verify_ui_font(game)
	game.show_creation()
	await process_frame
	await process_frame
	verify_ui_font(game)
	assert(game.portrait.size == Vector2(Art.PREVIEW_REGION.size) * Art.PREVIEW_SCALE)
	assert(game.bottom_panel.is_ancestor_of(game.portrait))
	assert(game.portrait.get_global_rect().get_center().distance_to(game.portrait.get_parent().get_global_rect().get_center()) <= 0.71)
	for label in game.bottom_panel.find_children("*", "Label", true, false):
		assert(label.text not in ["외형 미리보기", "외형 파츠", "좌우 버튼으로 외형과 무기 선택", "성별과 관계없이 파츠 조합 가능"])
	assert(not game.top_panel.is_ancestor_of(game.portrait))
	assert(game.top_panel.is_ancestor_of(game.name_input))
	assert(game.part_controls.size() == 11)
	assert(game.part_controls.face.number.text == "1/40")
	assert(game.create_button.get_global_rect().end.y <= root.size.y)
	assert(game.find_children("*", "ScrollContainer", true, false).is_empty())
	assert(game.parts_columns[0].get_child_count() == 5 and game.parts_columns[1].get_child_count() == 6)
	for key in ["beard", "beard_color", "weapon", "weapon_item", "offhand", "offhand_item"]:
		assert(game.parts_columns[1].is_ancestor_of(game.part_controls[key].right))
		assert(game.part_controls[key].right.global_position.x > game.part_controls.skin.right.global_position.x)
	assert(is_equal_approx(game.part_controls.beard.right.global_position.y, game.part_controls.skin.right.global_position.y))
	for key in game.part_controls:
		for control in [game.part_controls[key].left, game.part_controls[key].right, game.part_controls[key].number]:
			assert(game.bottom_panel.get_global_rect().encloses(control.get_global_rect()), "Part selector is outside the panel")
	assert(game.part_controls.weapon.right.global_position.y < game.part_controls.hair_color.right.global_position.y)
	for entry in Art.PARTS:
		var key: String = entry[0]
		var previous: int = game.appearance[key]
		game.part_controls[key].right.pressed.emit()
		var order := Art.selection_order(game.appearance, key)
		assert(game.appearance[key] == order[(order.find(previous) + 1) % order.size()])
		assert(not game.part_controls[key].number.text.is_empty())
		assert(game.portrait.size == Vector2(Art.PREVIEW_REGION.size) * Art.PREVIEW_SCALE, "Changing equipment must not resize the character preview")
		assert(game.portrait.texture.get_size() == Vector2(Art.PREVIEW_REGION.size))
		game.part_controls[key].left.pressed.emit()
		assert(game.appearance[key] == previous)
	game.appearance.face = 39
	game.change_part("face", 1)
	assert(game.appearance.face == 0 and game.part_controls.face.number.text == "1/40")
	game.change_part("face", -1)
	assert(game.appearance.face == 39)
	for hidden in ["race", "hands", "hat_family", "hat_color", "hat"]:
		assert(not game.part_controls.has(hidden) and not game.appearance.has(hidden))
	assert(game.part_controls.weapon.number.text == "한손 검")
	assert(Art.selection_order(game.appearance,"weapon") == [2,0,1,7,3,4,6,5,8,9])
	assert(Art.selection_order(game.appearance,"offhand") == [3,0,1,2])
	for family in ["one_sword","one_axe","one_blunt","two_sword","two_axe","two_blunt","two_spear","two_polearm","bow","crossbow"]:
		assert(Art.equipped_weapon(game.appearance).family == family)
		game.change_part("weapon",1)
	assert(Art.equipped_weapon(game.appearance).family == "one_sword")
	game.appearance.offhand = catalog.secondary_types.find("one_shield")
	game.appearance.offhand_item = 0
	game.refresh_part_controls()
	game.change_part("weapon_item", 3)
	assert(Art.equipped_weapon(game.appearance).id == "one_sword/4")
	assert(game.part_controls.weapon_item.number.text == "04")
	var previous_frame: PackedByteArray = game.character_frames.get_frame_texture("idle",0).get_image().get_data()
	game.change_part("offhand_item", 1)
	assert(Art.equipped_offhand(game.appearance).id == "one_shield/2")
	var expected_shields := []
	for number in range(1, 49):
		expected_shields.append(number)
	for direction in [1, -1]:
		for step in range(expected_shields.size()):
			var expected: int = expected_shields[posmod(1 + step * direction, expected_shields.size())]
			assert(game.part_controls.offhand_item.number.text == "%02d" % expected)
			assert(Art.equipped_offhand(game.appearance).id == "one_shield/%d" % expected)
			game.change_part("offhand_item", direction)
	assert(previous_frame != game.character_frames.get_frame_texture("idle",0).get_image().get_data())
	game.change_part("weapon", 3)
	assert(Art.equipped_weapon(game.appearance).id == "two_sword/1")
	for key in ["offhand", "offhand_item"]:
		assert(game.part_controls[key].left.disabled and game.part_controls[key].right.disabled)
		assert(game.part_controls[key].number.text == "미장착")
		game.change_part(key, 1)
		assert(game.appearance[key] == -1)
	assert(Art.equipped_offhand(game.appearance).is_empty())
	game.change_part("weapon", -1)
	assert(not game.part_controls.offhand.right.disabled and Art.equipped_offhand(game.appearance).id == "one_axe/1")
	game.name_input.text = "파츠 테스트"
	game.name_input.text_changed.emit(game.name_input.text)
	game.age_slider.value = 16
	assert(game.player_age == 16)
	game.age_slider.value = 99
	assert(game.player_age == 40)
	var selected: Dictionary = game.appearance.duplicate()
	var frame_set: SpriteFrames = game.character_frames
	for gender in range(2):
		game.genders[gender].pressed.emit()
		assert(game.appearance == selected and game.character_frames == frame_set)
		for animation in Art.FRAME_COUNTS:
			game.set_preview_animation(animation)
			var frames: SpriteFrames = game.character_frames
			assert(frames.get_frame_count(animation) == Art.FRAME_COUNTS[animation])
			var elapsed := 0.0
			for i in range(Art.FRAME_COUNTS[animation]):
				game.animation_time = (elapsed + 0.1) / frames.get_animation_speed(animation)
				elapsed += frames.get_frame_duration(animation, i)
				game._process(0.0)
				assert(game.portrait.texture.atlas == frames.get_frame_texture(animation, i))
		game.create_button.pressed.emit()
		await process_frame
		verify_ui_font(game)
		assert(game.world.character_frames == frame_set)
		assert(game.world.unit_position == game.world.spawn_position)
		assert(game.world.scale == Vector2.ONE and game.world.player_sprite.scale == Vector2.ONE)
		assert(game.world.character_name == "파츠 테스트")
		game.show_creation()
		assert(game.selected_gender == gender and game.appearance == selected)
		assert(game.player_age == 40 and game.player_name == "파츠 테스트")
	for old in ["assets/characters", "assets/adventurers", "assets/adventurers_side", "tests/fixtures", "tools/references"]:
		assert(not DirAccess.dir_exists_absolute("res://" + old))
	print("PASS: 1246 loose source parts match two atlases byte-for-byte; two weapon slots; 11 selectors; original GIF six-frame/100ms attack, fixed body, left follow-through, trail alignment and two-column scroll-free layout; skin-matched hands; unclipped animations and world entry continuity")
	quit()

func verify_shield_layers() -> void:
	var config := Art.defaults()
	var bare := config.duplicate()
	bare.offhand = -1
	for animation in Art.FRAME_COUNTS:
		for frame in range(Art.FRAME_COUNTS[animation]):
			var pose := Art.pose(animation, frame)
			var base := Art.compose(bare, animation, frame)
			for index in range(Art.count(config, "offhand_item")):
				config.offhand_item = index
				var shield := Art.equipped_offhand(config)
				var grip := Vector2i(shield.grip[0], shield.grip[1])
				var expected := base.duplicate() as Image
				Art.paste(expected, shield.sheet, shield.slot, pose.free_hand + Vector2i(8, 8) - grip)
				# Only compare the hand area; attack trails can cover the shield elsewhere.
				var hand := Rect2i(pose.free_hand, Vector2i(16, 16))
				var actual := Art.compose(config, animation, frame)
				assert(actual.get_region(hand).get_data() == expected.get_region(hand).get_data(), shield.id)
	print("PASS: all shields cover the offhand in idle, walk, run and attack frames")

func verify_equipment(catalog: Dictionary) -> void:
	var config := Art.defaults()
	var spear_count := 0
	assert(catalog.weapon_items.has("two_spear/13") and not catalog.weapon_items.has("two_spear/14") and not catalog.weapon_items.has("spear_101"))
	var expected_offsets := {"two_axe/1": 7, "two_axe/2": 6, "two_axe/4": 7, "two_axe/11": 6, "two_axe/12": 6, "two_axe/13": 6, "two_axe/14": 6}
	assert(catalog.melee_groups.two_axe == expected_offsets.keys())
	var two_blunt_offsets := [5, 7]
	for index in range(two_blunt_offsets.size()):
		expected_offsets["two_blunt/%d" % (index + 1)] = two_blunt_offsets[index]
	var two_spear_offsets := [9, 9, 7, 7, 5, 3, 10, 10, 10, 4, 6, 6, 6]
	for index in range(two_spear_offsets.size()):
		expected_offsets["two_spear/%d" % (index + 1)] = two_spear_offsets[index]
	var two_polearm_offsets := [9, 7, 7, 7, 7, 7, 7, 6, 9, 8]
	for index in range(two_polearm_offsets.size()):
		expected_offsets["two_polearm/%d" % (index + 1)] = two_polearm_offsets[index]
	var two_sword_offsets := [13, 13, 13, 14, 13, 14, 14, 14, 14, 14, 13, 13, 12, 14, 13, 14, 14, 14, 15, 14]
	for index in range(two_sword_offsets.size()):
		expected_offsets["two_sword/%d" % (index + 1)] = two_sword_offsets[index]
	var blunt_offsets := [5, 6, 3, 4, 4, 4, 4, 4, 4, 4, 4, 6, 5, 5, 5, 5, 6, 7, 6]
	for index in range(blunt_offsets.size()):
		expected_offsets["one_blunt/%d" % (index + 1)] = blunt_offsets[index]
	var axe_offsets := [4, 6, 5, 4, 4, 5, 5, 5, 5, 6, 5, 4, 6, 6, 6]
	for index in range(axe_offsets.size()):
		expected_offsets["one_axe/%d" % (index + 1)] = axe_offsets[index]
	var sword_offsets := [7,10,11,10,10,10,10,9,9,10,11,7,6,8]
	for index in range(sword_offsets.size()):
		expected_offsets["one_sword/%d" % (index + 1)] = sword_offsets[index]
	for removed in ["throwing weapons", "ranged weapons/pistol", "ranged weapons/musket", "ranged weapons/arquebus"]:
		assert(not DirAccess.dir_exists_absolute("res://art/medieval/sprites/weapons/" + removed))
	for id in catalog.weapon_items:
		config.equipped_weapon = id
		var weapon: Dictionary = Art.equipped_weapon(config)
		assert(int(weapon.get("y_up",0)) == expected_offsets.get(id,0), "Only sheet rows may shift weapons upward")
		if weapon.two_handed:
			var armed := Art.compose(config)
			var with_free_hand := armed.duplicate() as Image
			Art.paste(with_free_hand, Art.human_data().hand, config.skin, Art.pose("idle", 0).free_hand)
			assert(armed.get_data() != with_free_hand.get_data(), "Two-handed weapon shows offhand: " + id)
		# The ranged smoke check covers all twelve original bow shot frames.
		if id == "bow_01":
			assert(weapon.attack == "bow_shot")
			continue
		var is_spear: bool = weapon.family == "two_spear"
		assert(weapon.attack == ("thrust_attack" if is_spear else "chop_attack"))
		if is_spear: spear_count += 1
		var source := Art.part_image(weapon.sheet, weapon.slot)
		assert(source.get_pixel(weapon.grip[0], weapon.grip[1]).a > 0.0, "Grip is outside weapon pixels: " + id)
		var frames := Art.animations(config)
		var preview := Art.preview_texture(frames.get_frame_texture("idle", 0))
		var region := preview.region
		assert(preview.get_size() == Vector2(Art.PREVIEW_REGION.size), "Equipment must not resize the preview canvas")
		if (catalog.melee_groups.has(weapon.family) and weapon.family != "one_shield"):
			assert(Art.weapon_anchor(config,"idle",0) == Art.pose("idle",0,weapon.attack,weapon.family).grip - Vector2i(0,expected_offsets.get(id,0)), "Melee anchor must use the sheet upward offset")
		else:
			assert(Art.weapon_anchor(config,"idle",0) == Art.NON_MELEE_WEAPON_ANCHOR + (Vector2i(2,0) if weapon.family == "bow" else Vector2i.ZERO))
		assert(region == Rect2(Art.PREVIEW_REGION), "All weapons share the same padded preview canvas")
		for animation in Art.FRAME_COUNTS:
			for f in range(Art.FRAME_COUNTS[animation]):
				var pose := Art.pose(animation, f, weapon.attack, weapon.family)
				if weapon.family == "two_polearm":
					assert(pose.grip == Art.pose(animation, f, "thrust_attack").grip)
				var rendered := frames.get_frame_texture(animation, f)
				assert(Art.preview_texture(rendered).region == region, "Preview crop changes between poses")
				assert(Rect2i(region).encloses(rendered.get_image().get_used_rect()))
				if pose.visible:
					# Check source bounds BEFORE compositing: checking a clipped result alone misses lost pixels.
					var rotated := source.duplicate() as Image
					if pose.rotation != 0: rotated.rotate_90(CLOCKWISE if pose.rotation == 1 else COUNTERCLOCKWISE)
					var occupied := rotated.get_used_rect()
					var position := Art.weapon_position(config, animation, f)
					occupied.position += position
					assert(Rect2i(Vector2i.ZERO, Art.FRAME_SIZE).encloses(occupied), "Weapon clipped before composition: " + id)
					assert(Rect2i(region).encloses(occupied), "Weapon clipped by preview crop: " + id)
					if (catalog.melee_groups.has(weapon.family) and weapon.family != "one_shield"):
						# Mark the source pixel under the idle hand, then rotate an actual
						# image to locate it independently of the placement math.
						var contact := source.get_size() / 2 + Vector2i(0,expected_offsets.get(id,0))
						var marker := Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8)
						marker.set_pixelv(contact,Color.WHITE)
						if pose.rotation != 0: marker.rotate_90(CLOCKWISE if pose.rotation == 1 else COUNTERCLOCKWISE)
						assert(position + marker.get_used_rect().position == pose.grip, "Idle contact pixel detached from hand: " + id)
						if pose.rotation == 0:
							assert(position == pose.grip - contact, "Idle/walk placement must remain unchanged")
					else:
						var pivot := Vector2(0.5, 1.0) if weapon.family == "one_shield" else Vector2(0.5, 0.5)
						assert(position + Art.weapon_pivot_offset(source.get_size(),pose.rotation,pivot) == Art.weapon_anchor(config,animation,f))
				if animation == "attack":
					var reference: Dictionary = catalog.attack_references[weapon.attack]
					assert(is_equal_approx(frames.get_frame_duration(animation,f) / frames.get_animation_speed(animation), reference.durations_ms[f] / 1000.0))
					if pose.effect >= 0:
						var effect := Art.part_image(pose.effect_sheet, pose.effect)
						if pose.effect_rotation != 0: effect.rotate_90(COUNTERCLOCKWISE)
						for y in range(effect.get_height()):
							for x in range(effect.get_width()):
								if effect.get_pixel(x,y).a == 1.0:
									assert(rendered.get_image().get_pixelv(pose.effect_origin + Vector2i(x,y)) == effect.get_pixel(x,y))
		assert(Art.compose(config,"attack",0).get_data() == Art.compose(config,"idle",0).get_data())
		if is_spear:
			var ready := Art.pose("attack",1,weapon.attack)
			var extended := Art.pose("attack",5,weapon.attack)
			assert(ready.rotation == -1 and extended.rotation == -1)
			assert(extended.grip.x < ready.grip.x and extended.grip.y == ready.grip.y, "Thrust must extend horizontally")
	assert(spear_count == 13)
	print("PASS: all ", catalog.weapon_items.size(), " equipped weapons retain pixels without clipping and keep the idle contact pixel attached through both attack rotations with unchanged sheet offsets; 13 spears thrust, other melee weapons chop; fixed preview canvas and reference timing")

func verify_ui_font(node: Node) -> void:
	if node is Label or node is Button or node is LineEdit:
		var font: Font = node.get_theme_font("font")
		assert(font.resource_path == "res://assets/fonts/PFStardust3-Bold.ttf", "UI text must inherit the uploaded font")
		for character in node.text:
			if character.strip_edges().is_empty(): continue
			assert(font.has_char(character.unicode_at(0)), "Missing uploaded-font glyph: " + character)
	for child in node.get_children(): verify_ui_font(child)
