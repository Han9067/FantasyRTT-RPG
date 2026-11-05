extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.textures.size() == 8)
	for frames in game.animations:
		assert(frames.get_frame_count("idle") == 4)
		assert(frames.get_frame_count("walk") == 8)
		for animation in ["idle", "walk"]:
			var images := {}
			for i in range(frames.get_frame_count(animation)):
				images[frames.get_frame_texture(animation, i).get_image().get_data().hex_encode()] = true
			assert(images.size() == frames.get_frame_count(animation), "Animation contains duplicate poses")
	game.show_creation()
	assert(game.choices.get_child_count() == 4)
	game.name_input.text = "테스트 인물"
	game.name_input.text_changed.emit(game.name_input.text)
	assert(game.player_name == "테스트 인물")
	game.genders[1].pressed.emit()
	assert(game.selected_gender == 1)
	game.choices.get_child(3).pressed.emit()
	assert(game.portrait.texture == game.textures[7])
	game.age_slider.value = 16
	assert(game.player_age == 16)
	game.age_slider.value = 40
	assert(game.player_age == 40)
	game.age_slider.value = 99
	assert(game.player_age == 40)
	game.preview_animation = "walk"
	game.animation_time = 0.0
	game._process(0.15)
	assert(game.portrait.texture == game.animations[7].get_frame_texture("walk", 1))
	game.create_button.pressed.emit()
	await process_frame
	assert(game.current_screen == "world")
	assert(game.world.character_name == "테스트 인물")
	assert(game.world.player_sprite.sprite_frames == game.animations[7])
	assert(game.world.player_sprite.is_playing())
	assert(game.world.player_sprite.animation == "idle")
	var start_position = game.world.player_sprite.position
	game._process(1.0)
	assert(game.world.player_sprite.position == start_position)
	game.show_menu()
	game.show_creation()
	assert(game.player_name == "테스트 인물")
	assert(game.selected_gender == 1)
	assert(game.selected_looks[1] == 3)
	print("PASS: menu, 8 appearances, gender, portrait, name, age bounds, 4/8 unique animation frames per appearance, world transition, selected character, stationary map, retained selections")
	quit()
