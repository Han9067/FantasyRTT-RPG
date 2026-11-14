extends SceneTree
const Combat = preload("res://scripts/battle_combat.gd")
var game: Control

func _initialize() -> void:
	call_deferred("run")

func advance(map: BattleMap, seconds: float) -> void:
	for i in range(int(round(seconds * 60))): map._physics_process(1.0 / 60.0)

func mouse(map: BattleMap, point: Vector2, button := MOUSE_BUTTON_LEFT, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	map._unhandled_input(event)

func hover(map: BattleMap, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	map._unhandled_input(event)

func select(map: BattleMap, unit: BattleUnit) -> void:
	var point := map.world_to_screen(unit.position + BattleMap.BODY_CENTER_FROM_FEET)
	mouse(map, point)
	mouse(map, point, MOUSE_BUTTON_LEFT, false)

func fresh_battle() -> BattleMap:
	game.show_battle()
	var map: BattleMap = game.battle
	map.set_physics_process(false)
	return map

func check_no_overlap(map: BattleMap) -> void:
	var units := Combat.living(map.combat.all_units())
	for a in range(units.size()):
		for b in range(a + 1, units.size()):
			assert(not units[a].contact_box().intersects(units[b].contact_box()), "Live units cannot pass through each other")

func run() -> void:
	root.size = Vector2i(1280, 800)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var map := fresh_battle()
	await process_frame
	var hero := map.hero_group[0]
	assert(hero.hp == 100 and hero.max_hp == 100 and hero.attack_damage == 6)
	for unit in map.infantry + map.enemies:
		assert(unit.hp == 10 and unit.max_hp == 10 and unit.attack_damage == 4)
		assert(unit.sprite_frames.get_frame_count(&"attack") == 6)
		assert(unit.sprite_frames.get_animation_speed(&"attack") == 10)
	var enemy_point := map.world_to_screen(map.enemies[0].position + BattleMap.BODY_CENTER_FROM_FEET)
	hover(map, enemy_point)
	assert(not map.attack_cursor_active)
	select(map, hero)
	assert(map.selected and hero.material == map.outline_material)
	assert(game.character_frames == hero.sprite_frames, "Outline must not modify shared animation images")
	hover(map, enemy_point)
	assert(map.attack_cursor_active) # OS cursor appearance is checked in the browser.
	map.set_battle_paused(true)
	mouse(map, enemy_point)
	mouse(map, enemy_point, MOUSE_BUTTON_LEFT, false)
	assert(map.selected and map.combat.orders.has("hero"))
	var original := hero.position
	var frozen_frame := hero.frame
	advance(map, 10.0)
	assert(hero.position == original and hero.frame == frozen_frame and hero.hp == 100)
	assert(map.enemies[0].hp == 10)
	map.set_battle_paused(false)
	advance(map, 0.5)
	assert(hero.position != original and map.enemies[0].hp == 10, "Attacks cannot damage at a distance")
	map.issue_move(hero.position + Vector2(0, 80))
	assert(not map.combat.orders.has("hero"))
	mouse(map, Vector2(600, 200))
	mouse(map, Vector2(600, 200), MOUSE_BUTTON_LEFT, false)
	assert(hero.material == null)
	hover(map, enemy_point)
	assert(not map.attack_cursor_active)
	# Health bars reset their timer per hit and use simulation time during pause.
	var victim := map.enemies[0]
	victim.take_damage(4)
	assert(victim.hp == 6 and victim.health_bar.visible)
	advance(map, 3.0)
	victim.take_damage(4)
	assert(victim.hp == 2)
	map.set_battle_paused(true)
	advance(map, 5.0)
	assert(is_equal_approx(victim.health_time, 4.0) and victim.health_bar.visible)
	map.set_battle_paused(false)
	advance(map, 3.9)
	assert(victim.health_bar.visible)
	advance(map, 0.2)
	assert(not victim.health_bar.visible)
	# Isolated duel: one impact per swing; exact damage; death removes blockers.
	map = fresh_battle()
	await process_frame
	hero = map.hero_group[0]
	victim = map.enemies[0]
	for unit in map.infantry: unit.take_damage(1000)
	for unit in map.enemies:
		if unit != victim: unit.take_damage(1000)
	victim.position = hero.position + Vector2(12, 0)
	victim.target = victim.position
	select(map, hero)
	map.issue_attack(victim)
	advance(map, 0.2)
	assert(victim.hp == 10 and hero.hp == 100)
	advance(map, 0.2)
	assert(victim.hp == 4 and hero.hp == 96)
	map.set_battle_paused(true)
	var swing := hero.swing_time
	advance(map, 4.0)
	assert(hero.hp == 96 and victim.hp == 4 and hero.swing_time == swing)
	map.set_battle_paused(false)
	advance(map, 1.1)
	assert(victim.hp == 0 and not victim.visible and not victim.alive())
	advance(map, 0.1)
	assert(map.combat.orders.is_empty())
	assert(map.enemy_at(victim.position + BattleMap.BODY_CENTER_FROM_FEET) == null)
	hero.take_damage(1000)
	advance(map, 0.1)
	assert(map.selection.is_empty() and not map.standard.visible and hero.material == null)
	# Full formation approach around the idle hero; rear ranks must reach combat.
	map = fresh_battle()
	await process_frame
	select(map, map.infantry[0])
	var initial_rear := map.infantry[0].position
	map.issue_attack(map.enemies[0])
	var rear_damage := 0
	var saw_red_bar := false
	for i in range(1800):
		map._physics_process(1.0 / 60.0)
		if i % 12 == 0: check_no_overlap(map)
		for unit in map.combat.all_units():
			if unit.alive() and unit.health_bar.visible: saw_red_bar = true
	for i in [0, 4, 8, 12, 16]: rear_damage += map.infantry[i].damage_dealt
	assert(rear_damage > 0 and map.infantry[0].position.distance_to(initial_rear) > 500)
	assert(saw_red_bar)
	assert(map.enemies.any(func(unit: BattleUnit) -> bool: return unit.damage_dealt > 0), "Defenders retaliate")
	map.set_battle_paused(true)
	game.show_world()
	await process_frame
	assert(not paused)
	print("PASS: player-only silhouette outline, contextual attack cursor, paused attack orders, stats, timed impacts, 4-second health bars, deaths, solid melee collision and rear-rank combat")
	quit()
