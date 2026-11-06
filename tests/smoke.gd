extends SceneTree
const Art = preload("res://scripts/character_art.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 800)
	var catalog := Art.data()
	assert(catalog.sheets.size() == 127)
	for path in catalog.sheets:
		var entry: Dictionary = catalog.sheets[path]
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(FileAccess.get_file_as_bytes(Art.ROOT + path))
		assert(hash.finish().hex_encode() == entry.sha256, "Source PNG bytes changed: " + path)
		var original := Image.new()
		original.load_png_from_buffer(FileAccess.get_file_as_bytes(Art.ROOT + path))
		original.convert(Image.FORMAT_RGBA8)
		assert(original.get_data() == Art.sheet_image(path).get_data(), "Import altered source pixels")
		for i in range(entry.slots.size()):
			assert(Rect2i(Vector2i.ZERO, original.get_size()).encloses(Art.part_rect(path, i)))
	var config := Art.defaults()
	assert(Art.count(config, "face") == 40)
	assert(Art.count(config, "body") == 12)
	assert(Art.count(config, "hair") == 31 and Art.count(config, "beard") == 30)
	assert(Art.count(config, "weapon") == 3)
	assert(catalog.weapons[0].sheet.ends_with("/axe.png") and catalog.weapons[0].slot == 0)
	assert(catalog.weapons[1].sheet.ends_with("/blunt.png") and catalog.weapons[1].slot == 0)
	assert(catalog.weapons[2].sheet.ends_with("/sword.png") and catalog.weapons[2].slot == 12)
	assert(Art.part_rect(catalog.weapons[2].sheet, 12) == Rect2i(160, 32, 32, 32))
	assert(catalog.sheets[catalog.weapons[2].sheet].slots[12].name == "sword_12")
	for skin in range(Art.count(config, "skin")):
		config.skin = skin
		for face in range(40):
			config.face = face
			assert(not Art.compose(config).is_invisible())
		for weapon_index in range(3):
			config.weapon = weapon_index
			var weapon: Dictionary = catalog.weapons[weapon_index]
			for animation in Art.FRAME_COUNTS:
				for frame in range(Art.FRAME_COUNTS[animation]):
					var pose := Art.pose(animation, frame)
					var position := Art.weapon_position(config, animation, frame)
					assert(position + Vector2i(weapon.grip[0], weapon.grip[1]) == pose.grip, "Weapon detached from hand")
					var art := Art.compose(config, animation, frame)
					assert(Rect2i(Art.PREVIEW_REGION).encloses(art.get_used_rect()), "Weapon clipped in preview")
					# Verify both visible hands use exactly the selected skin, overlaid above the weapon.
					var hand_path: String = Art.human_data().hand
					var hand := Art.sheet_image(hand_path).get_region(Art.part_rect(hand_path, skin))
					for offset in [pose.grip - Vector2i(8, 8), pose.free_hand]:
						for y in range(16):
							for x in range(16):
								if hand.get_pixel(x, y).a == 1.0:
									assert(art.get_pixelv(offset + Vector2i(x, y)) == hand.get_pixel(x, y), "Hand skin differs from selected skin")
	config.merge({"race": 3, "hands": 12, "hat_family": 6, "hat_color": 7, "hat": 22})
	Art.normalize(config)
	for hidden in ["race", "hands", "hat_family", "hat_color", "hat"]:
		assert(not config.has(hidden))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.game_version == "0.0.13")
	game.show_creation()
	await process_frame
	await process_frame
	assert(game.bottom_panel.is_ancestor_of(game.portrait))
	assert(not game.top_panel.is_ancestor_of(game.portrait))
	assert(game.top_panel.is_ancestor_of(game.name_input))
	assert(game.part_controls.size() == 8)
	assert(game.part_controls.face.number.text == "1/40")
	assert(game.create_button.get_global_rect().end.y <= root.size.y)
	assert(game.parts_scroll.get_v_scroll_bar().max_value > game.parts_scroll.size.y)
	for entry in Art.PARTS:
		var key: String = entry[0]
		var previous: int = game.appearance[key]
		game.part_controls[key].right.pressed.emit()
		assert(game.appearance[key] == (previous + 1) % Art.count(game.appearance, key))
		assert(game.part_controls[key].number.text == "%d/%d" % [game.appearance[key] + 1, Art.count(game.appearance, key)])
		game.part_controls[key].left.pressed.emit()
		assert(game.appearance[key] == previous)
	game.appearance.face = 39
	game.change_part("face", 1)
	assert(game.appearance.face == 0 and game.part_controls.face.number.text == "1/40")
	game.change_part("face", -1)
	assert(game.appearance.face == 39)
	for hidden in ["race", "hands", "hat_family", "hat_color", "hat"]:
		assert(not game.part_controls.has(hidden) and not game.appearance.has(hidden))
	assert(game.part_controls.weapon.number.text == "1/3")
	var rendered_weapons := {}
	for weapon_index in range(3):
		assert(game.appearance.weapon == weapon_index)
		assert(game.part_controls.weapon.detail.text == ["한손 도끼", "한손 둔기", "한손 검"][weapon_index])
		rendered_weapons[game.character_frames.get_frame_texture("idle", 0).get_image().get_data().hex_encode()] = true
		game.part_controls.weapon.right.pressed.emit()
	assert(rendered_weapons.size() == 3 and game.appearance.weapon == 0)
	game.part_controls.weapon.left.pressed.emit()
	assert(game.appearance.weapon == 2 and game.part_controls.weapon.number.text == "3/3")
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
			for i in range(Art.FRAME_COUNTS[animation]):
				game.animation_time = (i + 0.1) / frames.get_animation_speed(animation)
				game._process(0.0)
				assert(game.portrait.texture.atlas == frames.get_frame_texture(animation, i))
		game.create_button.pressed.emit()
		await process_frame
		assert(game.world.character_frames == frame_set)
		assert(game.world.player_sprite.position.y + Art.FEET_Y == 320)
		assert(game.world.character_name == "파츠 테스트")
		game.show_creation()
		assert(game.selected_gender == gender and game.appearance == selected)
		assert(game.player_age == 40 and game.player_name == "파츠 테스트")
	for old in ["assets/characters", "assets/adventurers", "assets/adventurers_side", "tests/fixtures", "tools/references"]:
		assert(not DirAccess.dir_exists_absolute("res://" + old))
	print("PASS: 127 original sheets/hash/pixels; human-only 8 selectors; exact axe_0/blunt_0/sword_12; 3-way wrap; skin-matched hands; grip alignment and unclipped 4/8/8 animations; world continuity")
	quit()
