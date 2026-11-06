extends SceneTree
const Art = preload("res://scripts/character_art.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 800)
	var catalog := Art.data()
	assert(catalog.sheets.size() == 124)
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
	assert(Art.count(config, "hands") == 13)
	for race in range(4):
		config.race = race
		Art.normalize(config)
		for skin in range(Art.count(config, "skin")):
			config.skin = skin
			for face in range(40):
				config.face = face
				assert(not Art.compose(config).is_invisible())
	# All headgear families/colours/shapes must render, including 48px tall pieces.
	for family in range(7):
		config.hat_family = family
		Art.normalize(config)
		for color in range(Art.count(config, "hat_color")):
			config.hat_color = color
			for hat in range(Art.count(config, "hat")):
				config.hat = hat
				var composed := Art.compose(config)
				assert(composed.get_used_rect().end.y == Art.FEET_Y)
				assert(composed.get_used_rect().position.y > 0, "Tall headgear touches canvas boundary")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.game_version == "0.0.12")
	game.show_creation()
	await process_frame
	await process_frame
	assert(game.bottom_panel.is_ancestor_of(game.portrait))
	assert(not game.top_panel.is_ancestor_of(game.portrait))
	assert(game.top_panel.is_ancestor_of(game.name_input))
	assert(game.part_controls.size() == 12)
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
	game.appearance.race = 1
	game.appearance.skin = 7
	game.appearance.hat_family = 1
	game.appearance.hat_color = 7
	game.appearance.hat = 48
	game.change_part("race", 1)
	assert(game.appearance.skin == 3 and game.part_controls.skin.number.text == "4/4")
	game.change_part("hat_family", 1)
	assert(game.appearance.hat_color == 0 and game.appearance.hat == 4)
	assert(game.part_controls.hat_color.right.disabled)
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
	print("PASS: 124 original sheets/hash/pixels, all faces/headgear, 12 selectors/wrapping/dependencies, lower portrait, gender-independent appearance, 4/8/8 animation, world continuity/feet, removed legacy assets")
	quit()
