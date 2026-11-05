extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.textures.size() == 8)
	for frames in game.animations:
		assert(frames.get_frame_count("idle") == 2)
		assert(frames.get_frame_count("walk") == 2)
		for animation in ["idle", "walk"]:
			var images := {}
			for i in range(frames.get_frame_count(animation)):
				images[frames.get_frame_texture(animation, i).get_image().get_data().hex_encode()] = true
			assert(images.size() == frames.get_frame_count(animation), "Animation contains duplicate poses")
	# Reference fixtures are the uploaded completed sprites, independent of our compositor.
	for gender in range(2):
		for look in range(4):
			for animation in ["idle", "walk"]:
				var reference := Image.load_from_file("res://tests/fixtures/%s/%02d/%s_full_sheet.png" % ["male" if gender == 0 else "female", look+1, animation])
				var frames: SpriteFrames = game.animations[gender*4+look]
				for index in range(2 if animation == "idle" else 4):
					var source_columns := [0, 2] if animation == "idle" else [1, 3, 5, 7]
					var actual: Image = game.CharacterArt.texture(gender,look,animation,index,true).get_image()
					assert(actual.get_size() == Vector2i(32,36))
					for y in range(36):
						for x in range(32):
							var expected := reference.get_pixel(source_columns[index]*32+x,y)
							var pixel := actual.get_pixel(x,y)
							assert(pixel.a == expected.a)
							if expected.a > 0:
								assert(pixel == expected, "Visible source pixels changed")
	# Side-profile assets must remain separate aligned layers, with no clipping at the canvas edges.
	for gender in range(2):
		for look in range(4):
			for animation in ["idle", "walk"]:
				var frames: SpriteFrames = game.animations[gender*4+look]
				for index in range(frames.get_frame_count(animation)):
					var head: Image = game.CharacterArt.layer_texture(gender,look+1,animation,index,"head").get_image()
					var body: Image = game.CharacterArt.layer_texture(gender,look+1,animation,index,"body").get_image()
					assert(head.get_used_rect().end.y <= 21)
					assert(body.get_used_rect().position.y >= 16)
					var result := frames.get_frame_texture(animation,index).get_image()
					var bounds := result.get_used_rect()
					assert(bounds.position.x > 0 and bounds.end.x < 32 and bounds.end.y < 36)
					# Both layers contribute opaque pixels to the final image.
					for layer in [head,body]:
						assert(layer.get_used_rect().has_area())
					assert(result.get_used_rect().size.y > head.get_used_rect().size.y)
	# Exact idle toe correction on the native pixel grid and stable feet during breathing.
	var idle_0: Image = game.CharacterArt.layer_texture(0,1,"idle",0,"body").get_image()
	var idle_1: Image = game.CharacterArt.layer_texture(0,1,"idle",1,"body").get_image()
	assert(idle_0.get_pixel(18,30).a == 0 and idle_0.get_pixel(18,31).a == 0)
	assert(idle_0.get_pixel(17,30).a == 1)
	assert(idle_0.get_pixel(13,30) == Color("563629"))
	for y in range(27,36):
		for x in range(32):
			var a := idle_0.get_pixel(x,y)
			var b := idle_1.get_pixel(x,y)
			# Imported textures may dilate RGB into fully transparent pixels.
			assert(a.a == b.a and (a.a == 0 or a == b))
	for gender in range(2):
		for look in range(4):
			var first: Image = game.CharacterArt.layer_texture(gender,look+1,"walk",0,"head").get_image()
			var second: Image = game.CharacterArt.layer_texture(gender,look+1,"walk",1,"head").get_image()
			assert(first.get_data() == second.get_data(), "Walking head position changed")
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
	game._process(0.5)
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
	print("PASS: original references preserved, 32 side-profile frames/layers valid, menu, 8 appearances, gender, portrait, name, age bounds, 2/2 unique animation frames per appearance, world transition, selected character, stationary map, retained selections")
	quit()
