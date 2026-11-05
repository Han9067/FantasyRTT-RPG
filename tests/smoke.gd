extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.textures.size() == 8)
	for frames in game.animations:
		assert(frames.get_frame_count("idle") == 1)
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
					assert(head.get_used_rect().end.y <= 430)
					assert(body.get_used_rect().position.y >= 380)
					var result := frames.get_frame_texture(animation,index).get_image()
					var bounds := opaque_bounds(result)
					assert(bounds.position.x > 0 and bounds.end.x < 512 and bounds.end.y < 704)
					# Both layers contribute opaque pixels to the final image.
					for layer in [head,body]:
						assert(layer.get_used_rect().has_area())
					assert(result.get_used_rect().size.y > head.get_used_rect().size.y)
	# Compare the actual imported/composed textures directly with the approved artwork.
	# Independent fixture coordinates: translations only, never resize, recolour or replace heads.
	var approved := Image.load_from_file("res://tools/references/approved_male_01.png")
	var idle_changes := 0
	for pose in range(3):
		var rendered: Image = game.animations[0].get_frame_texture("idle" if pose==0 else "walk",0 if pose==0 else pose-1).get_image()
		assert(rendered.get_size() == Vector2i(512,704))
		for y in range(704):
			for x in range(512):
				var expected := approved.get_pixel([157,835,1514][pose]+x,17+y)
				var actual := rendered.get_pixel(x,y)
				var matches := actual.a == expected.a
				if expected.a > 0:
					matches = matches and absf(actual.r-expected.r) <= 1.01/255 and absf(actual.g-expected.g) <= 1.01/255 and absf(actual.b-expected.b) <= 1.01/255
				if not matches:
					# Only the requested one-source-pixel idle boot contour edit may differ.
					assert(pose==0 and y>=623 and y<670 and x>=180 and x<=350, "Approved artwork changed outside the idle toe")
					idle_changes += 1
	assert(idle_changes > 0 and idle_changes <= 94, "Idle correction exceeded one contour column plus its edge")
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
	assert(is_equal_approx(game.world.player_sprite.scale.y * 654, 30.0))
	assert(game.world.player_sprite.animation == "idle")
	var start_position = game.world.player_sprite.position
	game._process(1.0)
	assert(game.world.player_sprite.position == start_position)
	game.show_menu()
	game.show_creation()
	assert(game.player_name == "테스트 인물")
	assert(game.selected_gender == 1)
	assert(game.selected_looks[1] == 3)
	print("PASS: original references preserved, 24 source-resolution frames/layers valid, approved artwork pixel comparison passed, menu, 8 appearances, gender, portrait, name, age bounds, 1/2 unique animation frames per appearance, world transition, selected character, stationary map, retained selections")
	quit()

func opaque_bounds(image: Image) -> Rect2i:
	var minimum := image.get_size()
	var maximum := Vector2i.ZERO
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a > 0.5:
				minimum = minimum.min(Vector2i(x,y))
				maximum = maximum.max(Vector2i(x+1,y+1))
	return Rect2i(minimum,maximum-minimum)
