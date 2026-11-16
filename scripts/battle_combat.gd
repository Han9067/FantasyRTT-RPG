extends RefCounted
## Formation approach, then individual melee slots with solid unit collisions.
const REACH := 20.0
const ENGAGE_DISTANCE := 38.0
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

func cancel(key: String, reform := false) -> void:
	orders.erase(key)
	for unit in group(key):
		unit.opponent = null
		unit.swing_target = null
		unit.swing_time = -1.0
		unit.target = unit.position
		unit.march_path.clear()
		if not map.battle_paused: unit.enter_idle()
	if reform: map.reform_group(key)

func cancel_for(units: Array[BattleUnit]) -> void:
	for unit in units:
		if orders.has(key_for(unit)): cancel(key_for(unit))

func begin_melee(key: String) -> void:
	var members := living(group(key))
	var direction := center(foes(key)) - center(members)
	var axis := Vector2(signf(direction.x), 0) if absf(direction.x) >= absf(direction.y) else Vector2(0, signf(direction.y))
	if axis == Vector2.ZERO: axis = Vector2.RIGHT if key != "enemy" else Vector2.LEFT
	var width: int = map.INFANTRY_ROWS if axis.x != 0 else map.INFANTRY_COLUMNS
	members.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		var distance := (a.position - b.position).dot(axis)
		return distance > 0.01 if absf(distance) > 0.01 else a.position.cross(axis) > b.position.cross(axis))
	var fronts: Array[BattleUnit] = []
	fronts.assign(members.slice(0, mini(width, members.size())))
	orders[key] = {"engaged": true, "fronts": fronts, "axis": axis}
	map.reform_anchors.erase(key)
	for unit in members:
		unit.target = unit.position
		unit.march_path.clear()
	plan_time = 0.0

func replace_fronts(key: String) -> void:
	var fronts: Array[BattleUnit] = orders[key].fronts
	var reserves: Array[BattleUnit] = []
	for unit in living(group(key)):
		if not fronts.has(unit): reserves.append(unit)
	for i in range(fronts.size()):
		if fronts[i].alive(): continue
		if reserves.is_empty(): continue
		var vacancy := fronts[i].position
		reserves.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return a.position.distance_squared_to(vacancy) < b.position.distance_squared_to(vacancy))
		fronts[i] = reserves.pop_front()
	orders[key].fronts = living(fronts)

func is_front(unit: BattleUnit) -> bool:
	var key := key_for(unit)
	return engaged(key) and orders[key].fronts.has(unit)

func prepare(delta: float) -> void:
	for unit in all_units():
		unit.tick_health(delta)
		unit.cooldown = maxf(0.0, unit.cooldown - delta)
	for key: String in orders.keys():
		var members := living(group(key))
		var opponents := foes(key)
		if members.is_empty() or opponents.is_empty():
			cancel(key, not members.is_empty())
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
			map.order_formation(members, goal)

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
	for key: String in orders:
		if engaged(key): replace_fronts(key)
	for key: String in orders:
		if not engaged(key): continue
		var fronts: Array[BattleUnit] = orders[key].fronts
		var axis: Vector2 = orders[key].axis
		var opponents: Array[BattleUnit] = []
		for enemy in foes(key):
			if not engaged(key_for(enemy)) or is_front(enemy): opponents.append(enemy)
		var claimed: Array[BattleUnit] = []
		for unit in living(group(key)):
			if not fronts.has(unit):
				unit.opponent = null
				unit.target = unit.position
				unit.combat_slot = unit.position
		# One opponent per front soldier; reserves keep their space behind the line.
		for unit in fronts:
			var previous := unit.opponent
			unit.opponent = null
			if previous != null and opponents.has(previous) and not claimed.has(previous): unit.opponent = previous
			if unit.opponent == null:
				opponents.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
					var a_cost := absf((a.position-unit.position).cross(axis)) * 4.0 + unit.position.distance_to(a.position)
					var b_cost := absf((b.position-unit.position).cross(axis)) * 4.0 + unit.position.distance_to(b.position)
					return a_cost < b_cost)
				for enemy in opponents:
					if not claimed.has(enemy):
						unit.opponent = enemy
						break
			if unit.opponent != null:
				claimed.append(unit.opponent)
				unit.combat_slot = map.clamp_point(unit.opponent.position - axis * (REACH - 1.0))
			else:
				unit.combat_slot = unit.position

func face(unit: BattleUnit, point: Vector2) -> void:
	if absf(point.x - unit.position.x) > 0.001:
		unit.flip_h = point.x > unit.position.x
		unit.offset = -map.sprite_anchor(unit.flip_h)

func safe_motion(unit: BattleUnit, motion: Vector2, keep_ranks := false) -> Vector2:
	var fraction := 1.0
	for other in all_units():
		if other != unit and other.alive():
			fraction = minf(fraction, map.contact_fraction(unit.contact_box(), motion, other.contact_box()))
			if keep_ranks and key_for(other) == key_for(unit):
				var size: Vector2 = map.FORMATION_SPACING - Vector2.ONE
				var body := Rect2(unit.position - size * 0.5, size)
				var obstacle := Rect2(other.position - size * 0.5, size)
				# Existing slight deformation can separate without becoming trapped.
				if not body.intersects(obstacle):
					fraction = minf(fraction, map.contact_fraction(body, motion, obstacle))
	return motion * maxf(0.0, fraction - 0.0001) if fraction < 1.0 else motion

func advance_unit(unit: BattleUnit, delta: float) -> void:
	unit.target = unit.combat_slot
	var wanted := (unit.target - unit.position).limit_length(map.MOVE_SPEED * delta)
	var motion := safe_motion(unit, wanted, true)
	if motion.length() < wanted.length() * 0.8:
		# Slide around occupied front slots rather than walking through allies.
		for angle in [PI / 4, PI / 2, -PI / 4, -PI / 2]:
			var alternative := safe_motion(unit, wanted.rotated(angle * unit.avoid_side), true)
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
