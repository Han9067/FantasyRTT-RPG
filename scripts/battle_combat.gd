extends RefCounted
## Formation approach, then individual melee slots with solid unit collisions.
const REACH := 14.0
const ENGAGE_DISTANCE := 32.0
const ATTACK_INTERVAL := 1.0
const IMPACT_TIME := 0.3
const SWING_DURATION := 0.6
var map: Node2D
var orders: Dictionary = {}
var plan_time := 0.0

func _init(battle: Node2D) -> void:
	map = battle

static func living(units: Array[BattleUnit]) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in units:
		if unit.alive(): result.append(unit)
	return result

func all_units() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	result.append_array(map.friendlies)
	result.append_array(map.enemies)
	return result

func group(key: String) -> Array[BattleUnit]:
	if key == "hero": return map.hero_group
	return map.infantry if key == "infantry" else map.enemies

func key_for(unit: BattleUnit) -> String:
	return "hero" if unit == map.player_sprite else ("infantry" if unit.allied else "enemy")

func foes(key: String) -> Array[BattleUnit]:
	return living(map.friendlies if key == "enemy" else map.enemies)

static func center(units: Array[BattleUnit]) -> Vector2:
	var point := Vector2.ZERO
	for unit in units: point += unit.position
	return point / maxi(1, units.size())

func engaged(key: String) -> bool:
	return orders.has(key) and orders[key].engaged

func command(units: Array[BattleUnit]) -> void:
	for unit in units:
		if unit.alive(): orders[key_for(unit)] = {"engaged": false}
	plan_time = 0.0

func cancel(key: String) -> void:
	orders.erase(key)
	for unit in group(key):
		unit.opponent = null
		unit.swing_target = null
		unit.swing_time = -1.0
		unit.target = unit.position
		if not map.battle_paused: unit.enter_idle()

func cancel_for(units: Array[BattleUnit]) -> void:
	for unit in units:
		if orders.has(key_for(unit)): cancel(key_for(unit))

func begin_melee(key: String) -> void:
	orders[key] = {"engaged": true}
	for unit in living(group(key)): unit.target = unit.position
	plan_time = 0.0

func prepare(delta: float) -> void:
	for unit in all_units():
		unit.tick_health(delta)
		unit.cooldown = maxf(0.0, unit.cooldown - delta)
	for key: String in orders.keys():
		var members := living(group(key))
		var opponents := foes(key)
		if members.is_empty() or opponents.is_empty():
			cancel(key)
			continue
		var distance := INF
		var closest: BattleUnit
		for unit in members:
			for enemy in opponents:
				var d := unit.position.distance_to(enemy.position)
				if d < distance:
					distance = d
					closest = enemy
		if engaged(key):
			var defender_key := key_for(closest)
			var defenders := living(group(defender_key))
			# Idle defenders retaliate; an explicit retreat/move order stays in force.
			if distance <= ENGAGE_DISTANCE and not engaged(defender_key):
				if orders.has(defender_key) or defenders.all(func(unit: BattleUnit) -> bool: return unit.position.is_equal_approx(unit.target)):
					begin_melee(defender_key)
			continue
		if distance <= ENGAGE_DISTANCE:
			begin_melee(key)
			# The defending formation joins the fight only when approached for combat.
			if not engaged(key_for(closest)): begin_melee(key_for(closest))
		else:
			var goal := center(living(group(key_for(closest))))
			map.order_formation(members, approach_waypoint(key, members, goal))

func approach_waypoint(key: String, members: Array[BattleUnit], goal: Vector2) -> Vector2:
	var origin := center(members)
	var route: Array = orders[key].get("waypoints", [])
	while not route.is_empty() and origin.distance_to(route[0]) < 1.0: route.pop_front()
	if not route.is_empty():
		orders[key].waypoints = route
		return route[0]
	var bounds := members[0].contact_box()
	for unit in members: bounds = bounds.merge(unit.contact_box())
	var movement := goal - origin
	# Keep the formation intact when a separate allied group blocks its approach.
	for other_key: String in ["hero", "infantry", "enemy"]:
		var others := living(group(other_key))
		if other_key == key or others.is_empty() or others[0].allied != members[0].allied: continue
		var obstacle := others[0].contact_box()
		for other in others: obstacle = obstacle.merge(other.contact_box())
		if map.contact_fraction(bounds, movement, obstacle) >= 1.0: continue
		var obstacle_center := obstacle.get_center() - BattleUnit.BODY_CENTER_FROM_FEET
		var sideways := (bounds.size.y + obstacle.size.y) * 0.5 + 12.0
		var forward := (bounds.size.x + obstacle.size.x) * 0.5 + 12.0
		if absf(movement.x) >= absf(movement.y):
			var y := obstacle_center.y + (sideways if origin.y >= obstacle_center.y else -sideways)
			if y > map.playable_rect().end.y - bounds.size.y * 0.5: y = obstacle_center.y - sideways
			if y < map.playable_rect().position.y + bounds.size.y * 0.5: y = obstacle_center.y + sideways
			route = [Vector2(origin.x, y), Vector2(obstacle_center.x + signf(movement.x) * forward, y)]
		else:
			var x := obstacle_center.x + (forward if origin.x >= obstacle_center.x else -forward)
			if x > map.playable_rect().end.x - bounds.size.x * 0.5: x = obstacle_center.x - forward
			if x < map.playable_rect().position.x + bounds.size.x * 0.5: x = obstacle_center.x + forward
			route = [Vector2(x, origin.y), Vector2(x, obstacle_center.y + signf(movement.y) * sideways)]
		orders[key].waypoints = route
		return route[0]
	return goal

func can_strike(unit: BattleUnit, enemy: BattleUnit) -> bool:
	if enemy == null or not enemy.alive() or unit.allied == enemy.allied: return false
	if unit.position.distance_to(enemy.position) > REACH: return false
	var ray := Rect2(unit.contact_box().get_center(), Vector2(0.1, 0.1))
	var motion := enemy.position - unit.position
	for other in all_units():
		if other == unit or other == enemy or not other.alive(): continue
		if map.contact_fraction(ray, motion, other.contact_box()) < 1.0: return false
	return true

func plan_slots() -> void:
	var fighters: Array[BattleUnit] = []
	for key: String in orders:
		if engaged(key): fighters.append_array(living(group(key)))
	# Front ranks reserve reachable positions before rear ranks seek the gaps.
	fighters.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return nearest_distance(a) < nearest_distance(b))
	var reserved: Array[Vector2] = []
	var obstacles := living(all_units())
	for unit in fighters:
		var opponents := foes(key_for(unit))
		opponents.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return unit.position.distance_squared_to(a.position) < unit.position.distance_squared_to(b.position))
		unit.opponent = null
		for enemy in opponents:
			if can_strike(unit, enemy):
				unit.opponent = enemy
				unit.combat_slot = unit.position
				break
		if unit.opponent != null:
			reserved.append(unit.position)
			continue
		var best := INF
		for enemy in opponents.slice(0, 6):
			for i in range(8):
				var slot: Vector2 = (enemy.position + Vector2.RIGHT.rotated(i * TAU / 8.0) * 12.0).round()
				if not map.playable_rect().has_point(slot): continue
				var cost := unit.position.distance_squared_to(slot)
				if cost >= best: continue
				var box := Rect2(slot + BattleUnit.BODY_CENTER_FROM_FEET - Vector2(3, 3), Vector2(6, 6))
				var blocked := false
				for other in obstacles:
					if other != unit and box.intersects(other.contact_box()):
						blocked = true
						break
				if blocked: continue
				for point in reserved:
					if point.distance_squared_to(slot) < 36.0:
						blocked = true
						break
				if blocked: continue
				best = cost
				unit.opponent = enemy
				unit.combat_slot = slot
		if unit.opponent != null: reserved.append(unit.combat_slot)

func nearest_distance(unit: BattleUnit) -> float:
	var distance := INF
	for enemy in foes(key_for(unit)):
		distance = minf(distance, unit.position.distance_squared_to(enemy.position))
	return distance

func face(unit: BattleUnit, point: Vector2) -> void:
	if absf(point.x - unit.position.x) > 0.001:
		unit.flip_h = point.x > unit.position.x
		unit.offset = -map.sprite_anchor(unit.flip_h)

func safe_motion(unit: BattleUnit, motion: Vector2) -> Vector2:
	var fraction := 1.0
	for other in all_units():
		if other != unit and other.alive():
			fraction = minf(fraction, map.contact_fraction(unit.contact_box(), motion, other.contact_box()))
	return motion * maxf(0.0, fraction - 0.0001) if fraction < 1.0 else motion

func advance_unit(unit: BattleUnit, delta: float) -> void:
	unit.target = unit.combat_slot
	var wanted := (unit.target - unit.position).limit_length(map.MOVE_SPEED * delta)
	var motion := safe_motion(unit, wanted)
	if motion.length() < wanted.length() * 0.8:
		# Slide around occupied front slots rather than walking through allies.
		for angle in [PI / 4, PI / 2, -PI / 4, -PI / 2]:
			var alternative := safe_motion(unit, wanted.rotated(angle * unit.avoid_side))
			if alternative.length() > motion.length() + 0.01:
				motion = alternative
				if motion.length() >= wanted.length() * 0.8: break
	if motion.length() > 0.001:
		face(unit, unit.position + motion)
		unit.position = map.clamp_point(unit.position + motion)
		unit.play(&"walk")
	else:
		unit.enter_idle()

func step(delta: float) -> void:
	plan_time -= delta
	if plan_time <= 0.0:
		plan_slots()
		plan_time = 0.2
	var hits: Array[Dictionary] = []
	for key: String in orders:
		if not engaged(key): continue
		for unit in living(group(key)):
			if unit.swing_time >= 0.0:
				unit.swing_time += delta
				if not unit.impact_done and unit.swing_time >= IMPACT_TIME:
					unit.impact_done = true
					if can_strike(unit, unit.swing_target):
						hits.append({"attacker": unit, "target": unit.swing_target})
				if unit.swing_time >= SWING_DURATION:
					unit.swing_time = -1.0
					unit.enter_idle()
				continue
			if unit.opponent == null or not unit.opponent.alive():
				unit.target = unit.position
				unit.enter_idle()
				plan_time = 0.0
				continue
			if can_strike(unit, unit.opponent):
				unit.target = unit.position
				face(unit, unit.opponent.position)
				if unit.cooldown <= 0.0:
					unit.cooldown = ATTACK_INTERVAL
					unit.swing_time = 0.0
					unit.swing_target = unit.opponent
					unit.impact_done = false
					unit.play(&"attack")
					unit.set_frame_and_progress(0, 0.0)
				else:
					unit.enter_idle()
			else:
				advance_unit(unit, delta)
	# Resolve simultaneous impacts together; a hit never damages a whole formation.
	for hit in hits:
		var attacker: BattleUnit = hit.attacker
		var victim: BattleUnit = hit.target
		attacker.damage_dealt += mini(victim.hp, attacker.attack_damage)
		victim.take_damage(attacker.attack_damage)
	if not hits.is_empty(): plan_time = 0.0
	map.queue_redraw()
