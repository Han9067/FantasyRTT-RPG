extends SceneTree
var game: Control
const Combat = preload("res://scripts/battle_combat.gd")

func _initialize() -> void:
	call_deferred("run")

func fresh() -> BattleMap:
	game.show_battle()
	var map: BattleMap = game.battle
	map.set_physics_process(false)
	return map

func no_overlap(map: BattleMap) -> void:
	var units := Combat.living(map.combat.all_units())
	for a in range(units.size()):
		for b in range(a + 1, units.size()):
			assert(not units[a].contact_box().intersects(units[b].contact_box()), "March must not pass through any living body")

func advance(map: BattleMap, seconds: float) -> void:
	for i in range(int(seconds * 60)):
		map._physics_process(1.0 / 60.0)
		no_overlap(map)

func run() -> void:
	root.size = Vector2i(1280, 800)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# Head-on, reverse, vertical and diagonal passage with a stationary ally in the lane.
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP, Vector2(1,1).normalized()]:
		var map := fresh()
		await process_frame
		var center := Combat.center(map.infantry)
		var hero := map.hero_group[0]
		hero.position = center + direction * 110.0
		hero.target = hero.position
		var original := hero.position
		var goal := center + direction * 260.0
		map.selection.assign(map.infantry)
		map.issue_move(goal)
		var max_center_drift := 0.0
		for i in range(360):
			map._physics_process(1.0 / 60.0)
			no_overlap(map)
			max_center_drift = maxf(max_center_drift, absf((Combat.center(map.infantry)-center).cross(direction)))
		assert(hero.position == original, "Idle ally must not be pushed")
		assert(max_center_drift < 8.0, "One ally must not divert the whole formation")
		for unit in map.infantry:
			assert(unit.position.distance_to(goal + unit.formation_slot) < 0.05, "Recover original slots after passage: %s %s" % [direction,unit.position-unit.target])
		print("PASS: passage and reformation ", direction)
	# Player passes through gaps in an idle formation, not around its whole perimeter.
	var map := fresh()
	await process_frame
	var center := Combat.center(map.infantry)
	var hero := map.hero_group[0]
	hero.position = center + Vector2(-100,0)
	hero.target = hero.position
	map.selection.assign(map.hero_group)
	map.issue_move(center + Vector2(100,0))
	var max_drift := 0.0
	for i in range(300):
		map._physics_process(1.0 / 60.0)
		no_overlap(map)
		max_drift = maxf(max_drift, absf(hero.position.y-center.y))
	assert(hero.position.is_equal_approx(hero.target) and max_drift < 12.0)
	for unit in map.infantry: assert(unit.position.is_equal_approx(center+unit.formation_slot))
	# Freeze mid-passage, replace the command, and recover the same original slot layout.
	map = fresh()
	await process_frame
	center = Combat.center(map.infantry)
	map.selection.assign(map.infantry)
	map.issue_move(center+Vector2(300,0))
	advance(map, 1.2)
	var positions: Array[Vector2] = []
	for unit in map.infantry: positions.append(unit.position)
	map.set_battle_paused(true)
	var goal := center + Vector2(240,120)
	map.issue_move(goal)
	advance(map, 1.0)
	for i in range(map.infantry.size()): assert(map.infantry[i].position == positions[i])
	map.set_battle_paused(false)
	advance(map, 6.0)
	for unit in map.infantry: assert(unit.position.distance_to(goal+unit.formation_slot) < 0.05)
	# Attack approach also stays near its original line past the idle hero.
	map = fresh()
	await process_frame
	center = Combat.center(map.infantry)
	var original_hero := map.hero_group[0].position
	map.selection.assign(map.infantry)
	map.issue_attack(map.enemies[0])
	advance(map, 3.0)
	assert(Combat.center(map.infantry).x > original_hero.x+90.0)
	assert(absf(Combat.center(map.infantry).y-center.y) < 8.0)
	for unit in map.infantry: assert((unit.position - Combat.center(map.infantry)).distance_to(unit.formation_slot) < 1.0)
	advance(map, 10.0)
	assert(map.infantry.any(func(unit: BattleUnit) -> bool: return unit.damage_dealt > 0))
	print("PASS: fluid allied passage, small local detours, restored slots, stationary allies, solid collisions, paused replacement orders and attack approach")
	quit()
