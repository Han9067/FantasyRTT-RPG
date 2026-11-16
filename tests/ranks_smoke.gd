extends SceneTree
const Combat = preload("res://scripts/battle_combat.gd")
var game: Control

func _initialize() -> void:
	call_deferred("run")

func fresh() -> BattleMap:
	game.show_battle()
	var map: BattleMap = game.battle
	map.set_physics_process(false)
	# Keep these legacy formation scenarios isolated from the new ranged group.
	for unit in map.archers:
		unit.position = Vector2(400,1400) + unit.formation_slot
		unit.target = unit.position
	for unit in map.infantry + map.enemies: unit.accuracy = 1.0
	return map

func advance(map: BattleMap, seconds: float) -> void:
	for i in range(int(seconds * 60)):
		var before: Dictionary = {}
		for unit in Combat.living(map.combat.all_units()):
			var key: String = map.combat.key_for(unit)
			if map.combat.engaged(key): before[unit] = [unit.position, map.combat.orders[key].axis]
		map._physics_process(1.0 / 60.0)
		for unit: BattleUnit in before:
			var key: String = map.combat.key_for(unit)
			if unit.alive() and map.combat.engaged(key) and map.combat.orders[key].axis == before[unit][1]:
				assert((unit.position-before[unit][0]).dot(before[unit][1]) >= -0.0001, "Melee avoidance must not step backwards")
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

func setup_pressure(extra_column := false) -> BattleMap:
	var map := fresh()
	map.hero_group[0].position = Vector2(400,400)
	map.hero_group[0].target = map.hero_group[0].position
	var origin := Combat.center(map.infantry)
	if extra_column:
		for row in range(5):
			var unit := BattleUnit.new()
			unit.sprite_frames = map.infantry[0].sprite_frames
			unit.position = origin + Vector2(-62.5, (row-2)*18)
			unit.formation_slot = unit.position-origin
			unit.target = unit.position
			map.get_node("Units").add_child(unit)
			map.infantry.append(unit)
			map.friendlies.append(unit)
		map.packed_counts.infantry = 25
	var shift := origin + Vector2(100,0) - Combat.center(map.enemies)
	for unit in map.enemies:
		unit.position += shift
		unit.target = unit.position
	for unit in map.infantry + map.enemies:
		unit.hp = 1000
		unit.max_hp = 1000
	map.selection.assign(map.infantry)
	map.refresh_selection()
	map.issue_attack(map.enemies[0])
	return map

func run() -> void:
	root.size = Vector2i(1280,800)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var map := fresh()
	await process_frame
	assert(BattleMap.FORMATION_SPACING == Vector2(25,18) and Combat.REACH == 25.0)
	var hero := map.hero_group[0]
	var enemy := map.enemies[0]
	enemy.position = hero.position + Vector2(25,0)
	assert(map.combat.can_strike(hero,enemy))
	enemy.position.x += 0.1
	assert(not map.combat.can_strike(hero,enemy))
	# Four columns retain a preferred fighting half, but blocked ranks wait.
	map = setup_pressure()
	var original: Dictionary = {}
	for unit in map.infantry: original[unit] = unit.position
	advance(map,0.1)
	var fronts: Array[BattleUnit] = map.combat.orders.infantry.fronts.duplicate()
	assert(fronts.size() == 10 and map.combat.orders.infantry.depths == 2)
	var reserve_columns: Array = map.combat.reserve_columns("infantry")
	var first_pool: Array = reserve_columns[0].duplicate()
	var last_pool: Array = reserve_columns[1].duplicate()
	var frozen: Dictionary = {}
	for unit in map.combat.all_units(): frozen[unit] = [unit.position,unit.damage_dealt]
	map.set_battle_paused(true)
	advance(map,2.0)
	for unit: BattleUnit in frozen:
		assert(unit.position == frozen[unit][0] and unit.damage_dealt == frozen[unit][1])
	map.set_battle_paused(false)
	advance(map,3.0)
	var hitters := 0
	for unit in fronts:
		if unit.damage_dealt > 0: hitters += 1
	assert(hitters > 0, "Open contact lanes must keep fighting")
	assert(fronts.slice(5).any(func(unit: BattleUnit) -> bool: return unit.damage_dealt > 0), "Priority followers use open neighboring attack lanes")
	# The extra visual breathing room must coexist with second-rank participation
	# through the original 18px lanes; increasing the body collider would seal them.
	for a in range(fronts.size()):
		for b in range(a+1, fronts.size()):
			var separation := (fronts[a].position-fronts[b].position).abs()
			assert(maxf(separation.x,separation.y) >= 8.5-0.001, "Melee comrades retain the enlarged spacing")
	for unit: BattleUnit in first_pool + last_pool:
		assert(unit.damage_dealt == 0 and unit.position.x > original[unit].x+10, "Reserves follow without attacking")
	var rear_front_x := INF
	for unit in fronts: rear_front_x = minf(rear_front_x,unit.position.x)
	var reserve_x := Combat.center(map.combat.reserve_columns("infantry")[0]).x
	assert(rear_front_x-reserve_x >= 5.0 and rear_front_x-reserve_x < 21.0, "First reserve column stays close")
	# Two simultaneous casualties take exactly two soldiers from the foremost reserve column.
	fronts[0].take_damage(10000)
	fronts[5].take_damage(10000)
	advance(map,0.1)
	var next_fronts := Combat.living(map.combat.orders.infantry.fronts)
	assert(next_fronts.size() == 10)
	var promoted: Array[BattleUnit] = []
	for unit in next_fronts:
		if not fronts.has(unit): promoted.append(unit)
	assert(promoted.size() == 2)
	for unit in promoted: assert(first_pool.has(unit) and not last_pool.has(unit))
	advance(map,3.0)
	for unit in promoted:
		assert(unit.position.distance_to(unit.combat_slot) < 1.0, "Replacement must reach its available cell")
	assert(promoted.any(func(unit: BattleUnit) -> bool: return unit.damage_dealt > 0), "Vacant contact positions resume fighting")
	# Exhaust that column before recruiting from the next one, without duplicate promotions.
	for i in range(4): next_fronts[i].take_damage(10000)
	advance(map,0.1)
	var final_fronts := Combat.living(map.combat.orders.infantry.fronts)
	assert(final_fronts.size() == 10)
	var first_count := 0
	var second_count := 0
	for unit in final_fronts:
		if not next_fronts.has(unit):
			if first_pool.has(unit): first_count += 1
			if last_pool.has(unit): second_count += 1
	assert(first_count == 3 and second_count == 1)
	for unit in map.enemies: unit.take_damage(10000)
	advance(map,0.1)
	assert(not map.combat.orders.has("infantry"))
	var anchor: Vector2 = map.reform_anchors.infantry
	advance(map,10.0)
	check_compact(map,14,anchor)
	print("PASS: 25px reach, space-limited fighting, close following reserves, pause and exact casualty replacement")
	# Five columns retain three priority columns; actual participation depends on space.
	map = setup_pressure(true)
	advance(map,4.0)
	fronts.assign(map.combat.orders.infantry.fronts)
	assert(fronts.size() == 15 and map.combat.orders.infantry.depths == 3)
	assert(fronts.any(func(unit: BattleUnit) -> bool: return unit.damage_dealt > 0))
	first_pool = map.combat.reserve_columns("infantry")[0].duplicate()
	var fallen := fronts[0]
	fallen.take_damage(10000)
	var best_cost := INF
	for unit: BattleUnit in first_pool:
		best_cost = minf(best_cost, map.combat.replacement_cost(unit, fallen.combat_slot))
	for sample in range(12):
		map.combat.orders.infantry.fronts[0] = fallen
		seed(sample+10)
		map.combat.replace_fronts("infantry")
		var picked: BattleUnit = map.combat.orders.infantry.fronts[0]
		assert(first_pool.has(picked))
		assert(map.combat.replacement_cost(picked, fallen.combat_slot) <= best_cost+3.0, "Prefer accessible replacements")
	# With equal approaches, still vary the choice instead of always taking an index.
	for unit in map.combat.all_units():
		if not first_pool.has(unit): unit.position = Vector2(2200,1400)
	fallen.combat_slot = Vector2(600,600)
	for i in range(first_pool.size()): first_pool[i].position = Vector2(300,200+i*40)
	first_pool[0].position = Vector2(570,590)
	first_pool[1].position = Vector2(570,610)
	var draws: Dictionary = {}
	for sample in range(16):
		map.combat.orders.infantry.fronts[0] = fallen
		seed(sample+20)
		map.combat.replace_fronts("infantry")
		var picked: BattleUnit = map.combat.orders.infantry.fronts[0]
		assert(picked == first_pool[0] or picked == first_pool[1])
		draws[picked] = true
	assert(draws.size() == 2, "Equivalent replacement routes retain variety")
	print("PASS: 5-column priorities, nearest accessible replacement and random ties in foremost reserve rank")
	# Even priority fighters cannot attack through one another.
	map = fresh()
	var attacker := map.infantry[3]
	var blocker := map.infantry[7]
	enemy = map.enemies[0]
	for unit in map.combat.all_units():
		if unit != attacker and unit != blocker and unit != enemy: unit.take_damage(10000)
	attacker.position = Vector2(600,600)
	blocker.position = Vector2(610,600)
	enemy.position = Vector2(620,600)
	map.combat.begin_melee("infantry")
	assert(map.combat.is_front(attacker) and map.combat.is_front(blocker))
	assert(not map.combat.can_strike(attacker,enemy), "An occupied attack lane must block a swing")
	blocker.take_damage(10000)
	assert(map.combat.can_strike(attacker,enemy), "A casualty opens the attack lane immediately")
	# A soldier boxed in at the front/sides waits instead of taking the open
	# backwards escape. Removing the front blocker lets it advance immediately.
	map = fresh()
	attacker = map.infantry[3]
	blocker = map.infantry[7]
	var upper := map.infantry[11]
	var lower := map.infantry[15]
	enemy = map.enemies[0]
	for unit in map.combat.all_units():
		if not [attacker,blocker,upper,lower,enemy].has(unit): unit.take_damage(10000)
	attacker.position = Vector2(600,600)
	blocker.position = Vector2(600+Combat.PERSONAL_SPACE,600)
	upper.position = Vector2(600,600-Combat.PERSONAL_SPACE)
	lower.position = Vector2(600,600+Combat.PERSONAL_SPACE)
	enemy.position = Vector2(650,600)
	map.combat.begin_melee("infantry")
	attacker.combat_slot = Vector2(620,600)
	var waiting_position := attacker.position
	for i in range(30): map.combat.advance_unit(attacker,1.0/60.0)
	assert(attacker.position.distance_to(waiting_position) < 0.01, "Blocked melee soldiers wait instead of retreating")
	blocker.take_damage(10000)
	map.combat.advance_unit(attacker,0.1)
	assert(attacker.position.x > waiting_position.x+1.0, "A new gap allows forward movement")
	# A reserve exposed to an enemy is allowed to fight without waiting for promotion.
	map = setup_pressure()
	advance(map,0.1)
	var exposed: BattleUnit = map.combat.reserve_columns("infantry")[0][0]
	enemy = map.enemies[0]
	enemy.position = exposed.position + Vector2(0, 20)
	enemy.target = enemy.position
	assert(not map.combat.is_front(exposed))
	advance(map,0.6)
	assert(exposed.damage_dealt > 0, "An open, reachable enemy permits reserve participation")
	print("PASS: friendly bodies block attacks, casualties open lanes and exposed reserves can fight")
	# Horizontal, vertical and oblique engagements must finish, with solid bodies.
	for direction: Vector2 in [Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,0.6).normalized()]:
		map = fresh()
		map.player_sprite.position = Vector2(400,400)
		map.player_sprite.target = map.player_sprite.position
		var shift := Combat.center(map.infantry)+direction*170-Combat.center(map.enemies)
		for unit in map.enemies:
			unit.position += shift
			unit.target = unit.position
		map.selection.assign(map.infantry)
		map.issue_attack(map.enemies[0])
		advance(map,35.0)
		assert(Combat.living(map.infantry).is_empty() or Combat.living(map.enemies).is_empty(), "Combat must resolve from direction %s" % direction)
	print("PASS: left/up/down/oblique engagements resolve without physical overlap")
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
