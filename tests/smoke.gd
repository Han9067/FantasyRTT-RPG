extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.game_version == "0.0.11")
	assert(game.CharacterArt.LOOK_COUNT == 1)
	assert(game.textures.size() == 2 and game.animations.size() == 2)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/source_manifest.json"))
	assert(manifest.frames.size() == 10)
	for entry in manifest.frames:
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(FileAccess.get_file_as_bytes("res://"+entry.path))
		assert(hash.finish().hex_encode() == entry.sha256, "Uploaded PNG bytes changed")
	for gender in range(2):
		var frames: SpriteFrames = game.animations[gender]
		assert(frames.get_frame_count("idle") == 1)
		assert(frames.get_frame_count("walk") == 4)
		assert(is_equal_approx(4.0 / frames.get_animation_speed("walk"), 0.84))
		for animation in ["idle", "walk"]:
			var unique := {}
			for i in range(frames.get_frame_count(animation)):
				var source := Image.load_from_file(game.CharacterArt.source_path(gender, animation, i))
				var texture: Texture2D = frames.get_frame_texture(animation, i)
				var imported := texture.get_image()
				source.convert(Image.FORMAT_RGBA8)
				imported.convert(Image.FORMAT_RGBA8)
				assert(imported.get_size() == Vector2i(64,64))
				assert(imported.get_data() == source.get_data(), "Source pixels changed during import")
				assert(imported.get_used_rect() == Rect2i(23,17,16,30))
				unique[imported.get_data().hex_encode()] = true
				var preview: AtlasTexture = game.CharacterArt.preview_texture(texture)
				assert(preview.atlas == texture and preview.region == Rect2(20,14,22,36))
			assert(unique.size() == frames.get_frame_count(animation), "Repeated walk frame")
	game.show_creation()
	assert(game.choices.get_child_count() == 1)
	game.name_input.text = "테스트 인물"
	game.name_input.text_changed.emit(game.name_input.text)
	assert(game.player_name == "테스트 인물")
	game.age_slider.value = 16
	assert(game.player_age == 16)
	game.age_slider.value = 40
	assert(game.player_age == 40)
	game.age_slider.value = 99
	assert(game.player_age == 40)
	for gender in range(2):
		game.genders[gender].pressed.emit()
		assert(game.selected_gender == gender)
		assert(game.choices.get_child_count() == 1)
		assert(game.choices.get_child(0).tooltip_text == ("남성" if gender==0 else "여성")+" 모험가 01")
		game.choices.get_child(0).pressed.emit()
		assert(game.portrait.texture == game.textures[gender])
		game.preview_animation = "walk"
		for i in range(4):
			game.animation_time = i*0.21+0.01
			game._process(0.0)
			assert(game.portrait.texture.atlas == game.animations[gender].get_frame_texture("walk",i))
		game.create_button.pressed.emit()
		await process_frame
		assert(game.current_screen == "world")
		assert(game.world.character_name == "테스트 인물")
		assert(game.world.player_sprite.sprite_frames == game.animations[gender])
		assert(game.world.player_sprite.is_playing() and game.world.player_sprite.animation == "idle")
		assert(game.world.player_sprite.scale == Vector2.ONE)
		assert(game.world.player_sprite.position.y + 47 == 320)
		var start_position = game.world.player_sprite.position
		game._process(1.0)
		assert(game.world.player_sprite.position == start_position)
		game.show_creation()
		assert(game.selected_gender == gender and game.selected_looks[gender] == 0)
	game.show_menu()
	game.show_creation()
	assert(game.player_name == "테스트 인물" and game.player_age == 40)
	assert(not DirAccess.dir_exists_absolute("res://assets/adventurers_side"))
	print("PASS: 10 untouched 64x64 PNGs, exact imported pixels, 1 idle + 4 unique walk frames, one appearance per gender, both world transitions, scale/feet alignment, retained name/age, stationary map")
	quit()
