extends SceneTree
const Combat = preload("res://scripts/battle_combat.gd")
var game: Control

func _initialize() -> void:
	call_deferred("run")

func fresh() -> BattleMap:
	game.show_battle()
	var map: BattleMap = game.battle
	map.set_physics_process(false)
	return map

func advance(map: BattleMap, seconds: float) -> void:
	for i in range(int(seconds * 60)):
		map._physics_process(1.0 / 60.0)
		var units := Combat.living(map.combat.all_units())
		for a in range(units.size()):
			for b in range(a+1, units.size()):
				assert(not units[a].contact_box().intersects(units[b].contact_box()), "Ranks must not overlap physical bodies")

func check_compact(map: BattleMap, count: int, anchor: Vector2) -> void:
	var members := Combat.living(map.infantry)
	assert(members.size() == count)
	var columns: Dictionary = {}
	for unit in members:
		assert(unit.position.distance_to(unit.target) < 0.1, "Survivor failed to settle: %s" % [unit.position-unit.target])
		var x := snappedf(unit.formation_slot.x, 0.001)
		if not columns.has(x): columns[x] = []
		columns[x].append(unit.formation_slot.y)
	var xs := columns.keys()
	xs.sort()
	assert(xs.size() == ceili(count / 5.0))
	var full_columns := 0
	for i in range(xs.size()):
		if i > 0: assert(absf(xs[i]-xs[i-1]-25.0) < 0.01)
		var ys: Array = columns[xs[i]]
		ys.sort()
		if ys.size() == 5: full_columns += 1
		for j in range(1, ys.size()): assert(is_equal_approx(ys[j]-ys[j-1],18.0))
	assert(full_columns == count / 5)
	assert(Combat.center(members).distance_to(anchor) < 0.1)
	assert(map.standard.position.distance_to(anchor + BattleMap.BODY_CENTER_FROM_FEET) < 0.1)

func run() -> void:
	root.size = Vector2i(1280,800)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var map := fresh()
	await process_frame
	assert(BattleMap.FORMATION_SPACING == Vector2(25,18) and Combat.REACH == 20.0)
	var hero := map.hero_group[0]
	var enemy := map.enemies[0]
	enemy.position = hero.position + Vector2(20,0)
	assert(map.combat.can_strike(hero,enemy))
	enemy.position.x += 0.1
	assert(not map.combat.can_strike(hero,enemy))
	# Start two aligned ranks at the new reach; prevent ordinary deaths until promotion is tested.
	map = fresh()
	await process_frame
	map.hero_group[0].position = Vector2(400,400)
	map.hero_group[0].target = map.hero_group[0].position
	var center := Combat.center(map.infantry)
	var shift := center + Vector2(95,0) - Combat.center(map.enemies)
	for unit in map.enemies:
		unit.position += shift
		unit.target = unit.position
	for unit in map.infantry + map.enemies:
		unit.hp = 1000
		unit.max_hp = 1000
	map.selection.assign(map.infantry)
	map.refresh_selection()
	map.issue_attack(map.enemies[0])
	advance(map, 0.1)
	var fronts: Array[BattleUnit] = map.combat.orders.infantry.fronts.duplicate()
	assert(fronts.size() == 5)
	var waiting: Dictionary = {}
	for unit in map.infantry:
		if not fronts.has(unit): waiting[unit] = unit.position
	assert(waiting.size() == 15)
	advance(map, 1.0)
	for unit: BattleUnit in waiting:
		assert(unit.position == waiting[unit] and unit.damage_dealt == 0 and unit.animation == &"idle")
	for unit in fronts: assert(unit.damage_dealt > 0)
	var fallen := fronts[2]
	fallen.take_damage(10000)
	advance(map, 0.25)
	var next_fronts: Array[BattleUnit] = map.combat.orders.infantry.fronts
	assert(next_fronts.size() == 5 and not next_fronts.has(fallen))
	var promoted: BattleUnit
	for unit in next_fronts:
		if not fronts.has(unit): promoted = unit
	assert(promoted != null and waiting.has(promoted))
	advance(map, 1.5)
	assert(promoted.damage_dealt > 0)
	for unit: BattleUnit in waiting:
		if unit != promoted: assert(unit.position == waiting[unit] and unit.damage_dealt == 0)
	# Victory automatically compacts survivors around a stable flag anchor.
	for unit in map.enemies: unit.take_damage(10000)
	advance(map, 0.1)
	assert(not map.combat.orders.has("infantry"))
	var anchor: Vector2 = map.reform_anchors.infantry
	advance(map, 8.0)
	check_compact(map,19,anchor)
	print("PASS: 20px reach, five front fighters, fifteen reserves, casualty replacement and automatic victory reformation")
	# Different survivor counts fill vertical columns first and keep the flag centered.
	for count in [1,4,5,7,11,17]:
		map = fresh()
		await process_frame
		map.selection.assign(map.infantry)
		var survivors: Array[int] = []
		for i in range(count): survivors.append((i*7)%20)
		for i in range(20):
			if not survivors.has(i): map.infantry[i].take_damage(1000)
		map.refresh_selection()
		anchor = Combat.center(Combat.living(map.infantry))
		advance(map,8.0)
		check_compact(map,count,anchor)
		var destination := anchor + Vector2(130,120)
		map.set_battle_paused(true)
		map.issue_move(destination)
		advance(map,0.5)
		assert(Combat.center(Combat.living(map.infantry)).distance_to(anchor) < 0.1)
		map.set_battle_paused(false)
		advance(map,6.0)
		check_compact(map,count,destination)
	print("PASS: survivor columns 1/4/5/7/11/17, 25x18 spacing, flag centering and paused move reformation")
	quit()
