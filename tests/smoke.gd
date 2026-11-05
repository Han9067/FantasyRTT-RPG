extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.textures.size() == 8)
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
	game.create_button.pressed.emit()
	assert(is_instance_valid(game.name_input))
	game.show_menu()
	game.show_creation()
	assert(game.player_name == "테스트 인물")
	assert(game.selected_gender == 1)
	assert(game.selected_looks[1] == 3)
	print("PASS: menu, 8 appearances, gender, portrait, name, age bounds, inert create button, retained selections")
	quit()
