extends SceneTree
class CountMarch extends "res://scripts/battle_march.gd":
	var searches := 0
	var line_checks := 0
	func clear_line(start: Vector2, finish: Vector2, obstacles: Array[BattleUnit], clearance := CLEARANCE) -> bool:
		line_checks += 1
		return super.clear_line(start,finish,obstacles,clearance)
	func route(start: Vector2, finish: Vector2, obstacles: Array[BattleUnit], axis := Vector2.ZERO, clearance := CLEARANCE) -> Array[Vector2]:
		searches += 1
		return super.route(start,finish,obstacles,axis,clearance)

func _initialize() -> void: call_deferred("run")

# Exhaustive collision oracle: optimizations must agree without removing bodies.
func exhaustive_motion(map: BattleMap, unit: BattleUnit, motion: Vector2, ranks: bool) -> Vector2:
	var fraction := 1.0
	for other in map.combat.all_units():
		if other == unit or not other.alive(): continue
		fraction = minf(fraction,map.contact_fraction(unit.contact_box(),motion,other.contact_box()))
		if ranks and map.combat.key_for(other) == map.combat.key_for(unit):
			var size: Vector2 = Vector2.ONE*map.combat.PERSONAL_SPACE
			var box := Rect2(unit.position-size*0.5,size)
			var obstacle := Rect2(other.position-size*0.5,size)
			if not box.intersects(obstacle): fraction = minf(fraction,map.contact_fraction(box,motion,obstacle))
	return motion*maxf(0,fraction-0.0001) if fraction < 1 else motion

func exhaustive_strike(map: BattleMap, unit: BattleUnit, enemy: BattleUnit) -> bool:
	if unit.position.distance_to(enemy.position) > map.combat.REACH: return false
	var ray := Rect2(unit.contact_box().get_center(),Vector2(0.1,0.1))
	for other in map.combat.all_units():
		if other == unit or other == enemy or not other.alive(): continue
		if map.contact_fraction(ray,enemy.position-unit.position,other.contact_box()) < 1: return false
	return true

func run() -> void:
	seed(22022)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.show_battle()
	var map: BattleMap = game.battle
	map.set_physics_process(false)
	var unit := map.infantry[0]
	var enemy := map.enemies[0]
	for iteration in range(300):
		for other in map.combat.all_units():
			other.position = Vector2(800,800)+Vector2(randf_range(-100,100),randf_range(-100,100))
		unit.position = Vector2(800,800)
		enemy.position = unit.position+Vector2(randf_range(-30,30),randf_range(-30,30))
		var motion := Vector2(randf_range(-60,60),randf_range(-60,60))
		for ranks in [false,true]:
			assert(map.combat.safe_motion(unit,motion,ranks).is_equal_approx(exhaustive_motion(map,unit,motion,ranks)))
		assert(map.combat.can_strike(unit,enemy) == exhaustive_strike(map,unit,enemy))
	var march := CountMarch.new(map)
	var blocker := map.infantry[1]
	unit.position = Vector2(700,700)
	unit.target = Vector2(730,700)
	blocker.position = unit.target
	var obstacles: Array[BattleUnit] = [blocker]
	assert(march.route(unit.position,unit.target,obstacles).is_empty())
	assert(march.line_checks == 1, "Occupied goal is rejected before constructing any graph")
	march.searches = 0
	unit.march_path.clear()
	for iteration in range(4):
		march.begin_frame(1.0/60)
		march.waypoint(unit,obstacles)
	assert(march.searches == 1, "Failed search must not repeat every tick")
	unit.target += Vector2(1,0)
	march.waypoint(unit,obstacles)
	assert(march.searches == 2, "New destinations bypass failure backoff")
	blocker.position += Vector2(0,100)
	assert(march.waypoint(unit,obstacles) == unit.target and march.failed_searches.is_empty(), "Directly reopened gaps respond immediately")
	blocker.position = unit.target
	march.waypoint(unit,obstacles)
	var before_retry := march.searches
	march.begin_frame(0.17)
	march.waypoint(unit,obstacles)
	assert(march.searches == before_retry+1, "Failed routes are retried within 160ms")
	print("PASS: swept-collision and attack-ray broad phase matches exhaustive checks across 300 layouts")
	print("PASS: occupied-goal early rejection, failure backoff, changed-goal/direct-gap immediate response and bounded retries")
	quit()
