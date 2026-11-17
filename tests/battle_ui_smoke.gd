extends SceneTree
var game: Control

func _initialize() -> void:
	call_deferred("run")

func tick(map: BattleMap, seconds: float) -> void:
	for i in range(int(seconds * 60)): map._physics_process(1.0 / 60.0)

func run() -> void:
	root.size = Vector2i(1280, 800)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.show_battle()
	await process_frame
	await process_frame
	var map: BattleMap = game.battle
	map.set_physics_process(false)
	var roster = map.roster
	assert(roster.cards.size() == 3)
	assert(roster.size.x < root.size.x and roster.size.y > 112)
	assert(roster.get_global_rect().end.y <= root.size.y - 14)
	for key: String in ["hero", "infantry", "archers"]:
		assert(roster.counts[key].text == ("1" if key == "hero" else "20"))
		var card: VBoxContainer = roster.cards[key]
		assert(card.size.y > card.size.x)
		assert(card.get_child(0).size.y > card.get_child(1).size.y)
		assert(roster.counts[key].horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
		var portrait: TextureRect = card.get_child(0).get_child(0).get_child(0)
		assert(portrait.texture.atlas == map.combat.group(key)[0].sprite_frames.get_frame_texture(&"idle", 0))
	assert(map.selected_archer_range().is_empty())
	map.selection.assign(map.hero_group+map.infantry)
	map.refresh_selection()
	assert(map.selected_archer_range().is_empty(), "Only selected archers display firing range")
	map.selection.assign(map.archers)
	map.refresh_selection()
	var range_area := map.selected_archer_range()
	assert(range_area.radius == 640.0)
	assert(range_area.center == BattleMap.Combat.center(map.archers))
	map.selection.assign(map.friendlies)
	map.refresh_selection()
	assert(map.standards.size() == 2 and not map.standards.has("hero"))
	for key: String in map.standards:
		var flag: AnimatedSprite2D = map.standards[key]
		assert(flag.visible and flag.is_playing())
		assert(flag.position.is_equal_approx(BattleMap.Combat.center(map.combat.group(key)) + BattleMap.BODY_CENTER_FROM_FEET))
	map.set_battle_paused(true)
	var frames: Array = []
	for flag: AnimatedSprite2D in map.standards.values(): frames.append([flag.frame, flag.frame_progress])
	await create_timer(0.15).timeout
	var n := 0
	for flag: AnimatedSprite2D in map.standards.values():
		assert(flag.frame == frames[n][0] and flag.frame_progress == frames[n][1])
		n += 1
	var goal := BattleMap.Combat.center(map.friendlies) + Vector2(0, -180)
	map.issue_move(goal)
	assert(map.destination_slots().size() == 41)
	for member in map.friendlies: assert(map.destination_slots().has(member.target))
	var previous := map.destination_slots()
	map.issue_move(goal + Vector2(-100, 0))
	assert(map.destination_slots() != previous)
	var slots := map.destination_slots()
	map.selection.clear()
	map.refresh_selection()
	assert(not map.standard.visible and not map.standards.archers.visible)
	assert(map.destination_slots() == slots, "Orders retain their footprints after deselection")
	assert(map.selected_archer_range().is_empty())
	map.selection.assign(map.friendlies)
	map.refresh_selection()
	var event := InputEventMouseButton.new()
	event.position = roster.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	map._unhandled_input(event)
	assert(map.destination_slots() == slots and not map.attack_cursor_active, "Cards block map commands and attack cursors")
	map.infantry[0].take_damage(10)
	map.set_battle_paused(false)
	map._physics_process(1.0/60.0)
	roster.refresh_counts()
	assert(roster.counts.infantry.text == "19" and map.destination_slots().size() == 40)
	for member in BattleMap.Combat.living(map.friendlies): assert(map.destination_slots().has(member.target))
	tick(map, 8)
	assert(map.selected_archer_range().center == BattleMap.Combat.center(map.archers), "Selected range follows the actual formation during movement")
	assert(map.destination_slots().is_empty() and map.movement_guides().is_empty(), "Footprints and routes disappear together at arrival")
	for key: String in map.standards:
		assert(map.standards[key].position.is_equal_approx(BattleMap.Combat.center(BattleMap.Combat.living(map.combat.group(key))) + BattleMap.BODY_CENTER_FROM_FEET))
	for member in map.archers: member.take_damage(6)
	map.hero_group[0].take_damage(100)
	map._physics_process(1.0/60.0)
	roster.refresh_counts()
	assert(roster.counts.archers.text == "" and roster.counts.hero.text == "")
	assert(roster.cards.archers.visible and not map.standards.archers.visible)
	assert(map.standard.visible)
	assert(map.selected_archer_range().is_empty(), "Annihilated archers have no range circle")
	root.size = Vector2i(960,720)
	await process_frame
	await process_frame
	assert(roster.get_global_rect().end.y <= 706)
	assert(absf(roster.get_global_rect().get_center().x - 480) < 1)
	var screen_position: Vector2 = roster.position
	map.pan_camera(Vector2.RIGHT, 0.3)
	map.change_zoom(1.0, Vector2(480,300))
	assert(roster.position == screen_position)
	print("PASS: three portrait/count cards, live casualties and blank zero counts, tall split panels, HUD input/resize/camera isolation")
	print("PASS: simultaneous infantry/archer flags follow each formation, pause/deselect/death cleanup, no hero flag")
	print("PASS: archer-only selected 640px range circle, mixed selection, moving center and annihilation cleanup")
	print("PASS: actual destination slots for 41 allies, paused/replacement orders, casualties, deselection and arrival cleanup")
	game.show_world()
	await process_frame
	assert(not is_instance_valid(roster), "Battle roster must not leak into world UI")
	quit()
