extends SceneTree
const Store = preload("res://scripts/character_presets.gd")
const Art = preload("res://scripts/character_art.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 800)
	root.gui_embed_subwindows = true
	var path := "user://preset_smoke_%d.cfg" % OS.get_process_id()
	var game = load("res://main.tscn").instantiate()
	game.preset_store = Store.new(path)
	root.add_child(game)
	await process_frame
	game.show_creation()
	await process_frame
	for slot in game.preset_buttons: assert(slot.disabled)
	game.player_name = "프리셋 테스트"
	game.player_age = 31
	game.select_gender(1)
	var snapshots: Array[Dictionary] = []
	for i in range(3):
		game.change_part("eye", 1)
		game.change_part("mouth", 1)
		game.change_part("hair", 1)
		game.change_part("weapon", -1 if i < 2 else 1)
		snapshots.append(game.appearance.duplicate(true))
		game.preset_save_button.pressed.emit()
		assert(game.preset_popup.visible)
		await process_frame # Headless windows lose focus; real popup lifetime is checked in Chromium.
		for choice in game.preset_choices: assert(choice.size == Vector2(64,64))
		game.preset_choices[i].pressed.emit()
		assert(not game.preset_popup.visible and not game.preset_buttons[i].disabled)
		for j in range(i + 1, 3): assert(game.preset_buttons[j].disabled)
	# Reload from disk as a fresh launch would, then use the actual load buttons.
	game.preset_store = Store.new(path)
	for i in range(3):
		game.preset_buttons[i].pressed.emit()
		assert(game.appearance == snapshots[i])
		assert(game.player_name == "프리셋 테스트" and game.player_age == 31 and game.selected_gender == 1)
		assert(game.character_frames.get_frame_texture("idle",0).get_image().get_data() == Art.compose(snapshots[i],"idle",0).get_data())
		var two_handed: bool = Art.equipped_weapon(snapshots[i]).two_handed
		assert(game.part_controls.offhand.right.disabled == two_handed)
		game.change_part("body",1)
		assert(game.preset_store.get_appearance(i) == snapshots[i], "Editing a loaded appearance must not mutate its saved slot")
	# Overwrite only the chosen slot; cancel/reopening and screen changes never save.
	var replacement: Dictionary = game.appearance.duplicate(true)
	game.preset_save_button.pressed.emit()
	game.preset_choices[1].pressed.emit()
	var restored := Store.new(path)
	assert(restored.get_appearance(0) == snapshots[0])
	assert(restored.get_appearance(1) == replacement)
	assert(restored.get_appearance(2) == snapshots[2])
	game.preset_save_button.pressed.emit()
	game.preset_popup.hide()
	game.show_menu()
	assert(game.preset_popup == null)
	game.show_creation()
	await process_frame
	assert(game.appearance.hair == 0 and game.appearance.body == 3)
	for slot in game.preset_buttons: assert(not slot.disabled)
	assert(game.top_panel.get_global_rect().encloses(game.preset_buttons[2].get_global_rect()))
	assert(game.create_button.get_global_rect().end.y <= root.size.y)
	game.preset_buttons[1].pressed.emit()
	game.start_journey()
	await process_frame
	assert(game.world.character_appearance == replacement)
	# Invalid saved slot data is treated as empty; other slots survive.
	var data := ConfigFile.new()
	assert(data.load(path) == OK)
	data.set_value("presets", "0", {"face": "invalid"})
	assert(data.save(path) == OK)
	restored = Store.new(path)
	assert(restored.get_appearance(0).is_empty() and restored.get_appearance(1) == replacement)
	assert(restored.get_appearance(-1).is_empty() and restored.get_appearance(3).is_empty())
	# Catalog indices from older presets must retain their original weapon types.
	var legacy := Art.defaults()
	for key in ["eye","mouth","gender"]: legacy.erase(key)
	legacy.face = 1
	legacy.body = 15 # White gambeson in 0.0.76, outside the current index range.
	legacy.weapon = 0
	legacy.weapon_item = 0
	legacy.offhand = 3
	legacy.offhand_item = 1
	data.set_value("presets", "0", legacy)
	assert(data.save(path) == OK)
	restored = Store.new(path)
	assert(restored.get_appearance(0).eye == 7 and restored.get_appearance(0).mouth == 0)
	assert(Art.description(restored.get_appearance(0), "body") == "흰색 갬비슨")
	assert(Art.equipped_weapon(restored.get_appearance(0)).id == "one_axe/1")
	assert(Art.equipped_offhand(restored.get_appearance(0)).id == "one_sword/2")
	# An old slot index for axe 4 must still select axe 4 after axe 3 is removed.
	legacy.weapon = Art.data().primary_types.find("two_axe")
	legacy.weapon_item = 3
	data.set_value("presets", "0", legacy)
	assert(data.save(path) == OK)
	restored = Store.new(path)
	assert(Art.equipped_weapon(restored.get_appearance(0)).id == "two_axe/4")
	var late_axe := restored.get_appearance(0)
	late_axe.weapon_item = Art.data().melee_groups.two_axe.find("two_axe/14")
	assert(restored.save_appearance(0, late_axe) == OK)
	restored = Store.new(path)
	assert(Art.equipped_weapon(restored.get_appearance(0)).id == "two_axe/14")
	var dual := Art.defaults()
	dual.offhand = Art.data().secondary_types.find("one_axe")
	assert(restored.save_appearance(0, dual) == OK and data.load(path) == OK)
	var record: Dictionary = data.get_value("presets", "0")
	assert(record.primary_item_id == 1001 and record.secondary_item_id == 1201)
	record.weapon_item = 5
	record.offhand_item = 5
	data.set_value("presets", "0", record)
	assert(data.save(path) == OK)
	restored = Store.new(path)
	assert(restored.get_appearance(0) == dual)
	assert(Art.weapon_by_item_id(1613).id == "two_spear/13" and Art.weapon_by_item_id(1303).is_empty())
	# Existing bow slots stored an index; resaving also records the new sheet ID.
	legacy.weapon = Art.data().primary_types.find("bow")
	legacy.weapon_item = 6
	data.set_value("presets", "0", legacy)
	assert(data.save(path) == OK)
	restored = Store.new(path)
	var bow := restored.get_appearance(0)
	assert(Art.equipped_weapon(bow).id == "bow/7" and Art.equipped_offhand(bow).is_empty())
	assert(restored.save_appearance(0, bow) == OK and data.load(path) == OK)
	assert(data.get_value("presets", "0").primary_item_id == 1807)
	DirAccess.remove_absolute(path)
	print("PASS: three disabled empty slots, square popup choices, disk reload, independent appearance/weapon presets, unchanged personal details, preview/dependency refresh, isolated overwrite, cancel/screen cleanup and world continuity")
	quit()
