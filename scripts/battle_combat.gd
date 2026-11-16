extends RefCounted
## Formation approach, then individual melee slots with solid unit collisions.
const REACH := 25.0
const ENGAGE_DISTANCE := 43.0
const FIGHTING_DEPTH_GAP := 13.0
const CONTACT_GAP := 18.0
const PERSONAL_SPACE := 8.5
const CONTACT_SIDE_STEP := 9.0
const RESERVE_GAP := 18.0
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

func begin_melee(key: String, focus := Vector2.INF) -> void:
	var members := living(group(key))
	var direction := (center(foes(key)) if focus == Vector2.INF else focus) - center(members)
	var axis := Vector2(signf(direction.x), 0) if absf(direction.x) >= absf(direction.y) else Vector2(0, signf(direction.y))
	if axis == Vector2.ZERO: axis = Vector2.RIGHT if key != "enemy" else Vector2.LEFT
	var lateral := axis.orthogonal()
	# Read actual formation columns, including partial columns and vertical approaches.
	var columns: Dictionary = {}
	for unit in members:
		var depth := snappedf(unit.formation_slot.dot(axis), 0.001)
		if not columns.has(depth): columns[depth] = []
		columns[depth].append(unit)
	var depths := columns.keys()
	depths.sort()
	depths.reverse()
	var fighting_depths := ceili(depths.size() / 2.0)
	var fronts: Array[BattleUnit] = []
	var layout: Array[Vector2] = []
	var reserves: Array = []
	var width := 1
	for i in range(depths.size()):
		var column: Array = columns[depths[i]]
		column.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return a.formation_slot.dot(lateral) < b.formation_slot.dot(lateral))
		width = maxi(width, column.size())
		if i < fighting_depths:
			for row in range(column.size()):
				fronts.append(column[row])
				layout.append(Vector2(i, row - (column.size()-1)*0.5))
		else: reserves.append(column.duplicate())
	orders[key] = {"engaged": true, "fronts": fronts, "layout": layout,
		"reserves": reserves, "depths": fighting_depths, "width": width,
		"axis": axis, "lateral_center": center(members).dot(lateral)}
	map.reform_anchors.erase(key)
	for unit in members:
		unit.target = unit.position
		unit.march_path.clear()
	plan_time = 0.0

func reserve_columns(key: String) -> Array:
	var columns: Array = []
	for column: Array in orders[key].reserves:
		var available: Array[BattleUnit] = []
		for unit: BattleUnit in column:
			if unit.alive() and not orders[key].fronts.has(unit): available.append(unit)
		if not available.is_empty(): columns.append(available)
	return columns

func replacement_cost(unit: BattleUnit, point: Vector2) -> float:
	var cost := unit.position.distance_to(point)
	# Favor a short open approach over crossing occupied lanes. This bounded sweep
	# avoids running a visibility graph for every candidate at every casualty.
	for other in all_units():
		if other == unit or not other.alive(): continue
		if map.contact_fraction(unit.contact_box(), point-unit.position, other.contact_box()) < 1.0:
			cost += 24.0
	return cost

func replace_fronts(key: String) -> void:
	var fronts: Array[BattleUnit] = orders[key].fronts
	for i in range(fronts.size()):
		if fronts[i].alive(): continue
		var columns := reserve_columns(key)
		if columns.is_empty(): break
		var best := INF
		var candidates: Array[BattleUnit] = []
		var vacancy := fronts[i].combat_slot
		for unit: BattleUnit in columns[0]:
			best = minf(best, replacement_cost(unit, vacancy))
		for unit: BattleUnit in columns[0]:
			if replacement_cost(unit, vacancy) <= best + 3.0: candidates.append(unit)
		# Randomness only breaks near ties in the foremost available reserve rank.
		fronts[i] = candidates.pick_random()
		plan_time = 0.0

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
			# Survivors can end up on opposite sides after an oblique engagement.
			# Reface a separated enemy behind the group, rather than treating the
			# necessary pursuit as forbidden backwards avoidance forever.
			var axis: Vector2 = orders[key].axis
			if distance > REACH and (closest.position-center(members)).dot(axis) < -REACH:
				begin_melee(key, closest.position)
			replace_fronts(key)
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
	return can_strike_from(unit, unit.position, enemy)

func can_strike_from(unit: BattleUnit, point: Vector2, enemy: BattleUnit) -> bool:
	if enemy == null or not enemy.alive() or unit.allied == enemy.allied: return false
	if point.distance_to(enemy.position) > REACH: return false
	var ray := Rect2(unit.contact_box().get_center()+point-unit.position, Vector2(0.1, 0.1))
	var motion := enemy.position - point
	for other in all_units():
		if other == unit or other == enemy or not other.alive(): continue
		# Every living body blocks an attack ray, including participating comrades.
		if map.contact_fraction(ray, motion, other.contact_box()) < 1.0: return false
	return true

func active_layout(key: String) -> Dictionary:
	var order: Dictionary = orders[key]
	var columns: Dictionary = {}
	for i in range(order.fronts.size()):
		if not order.fronts[i].alive(): continue
		var depth: float = order.layout[i].x
		if not columns.has(depth): columns[depth] = []
		columns[depth].append(i)
	var depths := columns.keys()
	depths.sort()
	var cells: Dictionary = {}
	var width := 1
	for depth in range(depths.size()):
		var column: Array = columns[depths[depth]]
		width = maxi(width, column.size())
		for row in range(column.size()):
			cells[column[row]] = Vector2(depth, row-(column.size()-1)*0.5)
	return {"cells": cells, "depths": depths.size(), "width": width}

func set_slot(unit: BattleUnit, point: Vector2) -> void:
	var key := key_for(unit)
	# Keep a usable contact position through the cooldown and the full swing.
	# Replanning must not pull a fighter back toward its nominal formation cell.
	if unit.swing_time >= 0.0 or nearest_opponent(unit, foes(key), true) != null:
		point = unit.position
	else:
		var axis: Vector2 = orders[key].axis
		point -= axis * minf(0.0, (point-unit.position).dot(axis))
	if unit.combat_slot.distance_squared_to(point) > 1.0: unit.march_path.clear()
	unit.combat_slot = point

func nearest_opponent(unit: BattleUnit, opponents: Array[BattleUnit], require_clear := false) -> BattleUnit:
	var chosen: BattleUnit
	var best := INF
	for enemy in opponents:
		if require_clear and not can_strike(unit, enemy): continue
		var cost := unit.position.distance_squared_to(enemy.position)
		if cost < best:
			chosen = enemy
			best = cost
	return chosen

func follow_slot(unit: BattleUnit, leaders: Array[BattleUnit], axis: Vector2, lane: float, gap: float) -> Vector2:
	var lateral := axis.orthogonal()
	var leader: BattleUnit
	var best := INF
	for candidate in leaders:
		var cost := absf(candidate.position.dot(lateral)-lane)
		if cost < best:
			best = cost
			leader = candidate
	if leader == null: return unit.position
	# Follow the actual soldier ahead, not a future front plane. A blocked leader
	# therefore slows its followers instead of making them route around the queue.
	return axis*(leader.position.dot(axis)-gap) + lateral*lane

func open_contact_slot(unit: BattleUnit, following: Vector2, axis: Vector2, opponents: Array[BattleUnit], claimed: Array[Vector2]) -> Vector2:
	# A priority follower can use a nearby gap, but never force its way into one.
	# Search only within its lane neighborhood, preserving the group's overall shape.
	var lateral := axis.orthogonal()
	var best := INF
	var chosen := following
	# Half of the normal 18px row gap leaves room on both sides. Keeping
	# clearance just below 9px avoids sealing the passage between those rows.
	for offset in [0.0, -CONTACT_SIDE_STEP, CONTACT_SIDE_STEP]:
		for forward in [0.0, 4.0, 8.0, 12.0, 16.0]:
			var point: Vector2 = following + axis*forward + lateral*offset
			var space := Rect2(point-Vector2.ONE*PERSONAL_SPACE*0.5, Vector2.ONE*PERSONAL_SPACE)
			if not map.playable_rect().has_point(point): continue
			var free := true
			for slot in claimed:
				if space.intersects(Rect2(slot-Vector2.ONE*PERSONAL_SPACE*0.5, Vector2.ONE*PERSONAL_SPACE)):
					free = false
			for other in all_units():
				if other == unit or not other.alive(): continue
				if space.intersects(Rect2(other.position-Vector2.ONE*PERSONAL_SPACE*0.5, Vector2.ONE*PERSONAL_SPACE)):
					free = false
				if map.contact_fraction(unit.contact_box(), point-unit.position, other.contact_box()) < 1.0:
					free = false
			if not free: continue
			for enemy in opponents:
				if not can_strike_from(unit, point, enemy): continue
				var cost := unit.position.distance_to(point)
				if cost < best:
					best = cost
					chosen = point
	return chosen

func contact_slot(unit: BattleUnit, axis: Vector2, lane: float, opponents: Array[BattleUnit]) -> Vector2:
	var lateral := axis.orthogonal()
	var enemy: BattleUnit
	var best := INF
	for candidate in opponents:
		var cost := absf(candidate.position.dot(lateral)-lane)*3.0 + unit.position.distance_to(candidate.position)
		if cost < best:
			best = cost
			enemy = candidate
	var across := absf(lane-enemy.position.dot(lateral))
	var gap := minf(CONTACT_GAP, sqrt(maxf(36.0, pow(REACH-2.0,2)-across*across)))
	var plane := (unit.position.dot(axis)+enemy.position.dot(axis)-gap)*0.5
	return axis*plane + lateral*lane

func plan_slots() -> void:
	for key: String in orders:
		if not engaged(key): continue
		replace_fronts(key)
		var order: Dictionary = orders[key]
		var axis: Vector2 = order.axis
		var lateral := axis.orthogonal()
		var opponents := foes(key)
		if opponents.is_empty(): continue
		var layout := active_layout(key)
		var lower := INF
		var upper := -INF
		for enemy in opponents:
			lower = minf(lower, enemy.position.dot(lateral))
			upper = maxf(upper, enemy.position.dot(lateral))
		var lane_spacing: float = map.FORMATION_SPACING.y if axis.x != 0 else map.FORMATION_SPACING.x
		# Preserve a readable width; only narrow for a genuinely smaller enemy front.
		lane_spacing = minf(lane_spacing, maxf(10.0, (upper-lower+40.0)/maxi(1, layout.width-1)))
		var side: float = clampf(order.lateral_center, lower, upper)
		var fronts: Array[BattleUnit] = order.fronts
		var preceding: Array[BattleUnit] = []
		var claimed: Array[Vector2] = []
		for depth in range(layout.depths):
			var row_members: Array[BattleUnit] = []
			for i in range(fronts.size()):
				var unit := fronts[i]
				if not unit.alive() or int(layout.cells[i].x) != depth: continue
				var lane: float = side + layout.cells[i].y*lane_spacing
				var point: Vector2
				var leader_ahead := false
				for leader in preceding:
					if (leader.position-unit.position).dot(axis) > 0.0 and absf(leader.position.dot(lateral)-lane) < lane_spacing*0.6:
						leader_ahead = true
				if depth == 0 or not leader_ahead:
					# After a casualty, the physically foremost soldier fills the open
					# contact line; a replacement still approaching must not hold it back.
					point = contact_slot(unit, axis, lane, opponents)
				else:
					point = follow_slot(unit, preceding, axis, lane, FIGHTING_DEPTH_GAP)
					point = open_contact_slot(unit, point, axis, opponents, claimed)
				set_slot(unit, map.clamp_point(point))
				claimed.append(unit.combat_slot)
				unit.opponent = nearest_opponent(unit, opponents, true)
				if unit.opponent == null: unit.opponent = nearest_opponent(unit, opponents)
				row_members.append(unit)
			preceding = row_members
		for column: Array in reserve_columns(key):
			var following: Array[BattleUnit] = []
			for row in range(column.size()):
				var unit: BattleUnit = column[row]
				var lane := side+(row-(column.size()-1)*0.5)*lane_spacing
				set_slot(unit, map.clamp_point(follow_slot(unit, preceding, axis, lane, RESERVE_GAP)))
				# Priority ranks are not an absolute permission gate: an exposed reserve
				# can defend/attack a reachable enemy without pushing through its allies.
				unit.opponent = nearest_opponent(unit, opponents, true)
				following.append(unit)
			preceding = following

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
				var size := Vector2.ONE * PERSONAL_SPACE
				var body := Rect2(unit.position - size * 0.5, size)
				var obstacle := Rect2(other.position - size * 0.5, size)
				# Existing slight deformation can separate without becoming trapped.
				if not body.intersects(obstacle):
					fraction = minf(fraction, map.contact_fraction(body, motion, obstacle))
	return motion * maxf(0.0, fraction - 0.0001) if fraction < 1.0 else motion

func advance_unit(unit: BattleUnit, delta: float) -> void:
	unit.target = unit.combat_slot
	var axis: Vector2 = orders[key_for(unit)].axis
	var wanted := (unit.target - unit.position).limit_length(map.MOVE_SPEED * delta)
	var motion := safe_motion(unit, wanted, true)
	if motion.length() < wanted.length() * 0.8 or not unit.march_path.is_empty():
		var allies := living(map.friendlies if unit.allied else map.enemies)
		allies.erase(unit)
		# A replacement may still need to cross a lane through actual free space.
		var waypoint: Vector2 = map.march.waypoint(unit, allies, axis, PERSONAL_SPACE)
		wanted = (waypoint - unit.position).limit_length(map.MOVE_SPEED * delta)
		motion = safe_motion(unit, wanted, true)
	if motion.length() < wanted.length() * 0.8:
		# In melee, only slide toward an opening. Do not turn a blocked forward
		# step into a backwards sidestep, or oscillate sideways without progress.
		for angle in [PI / 4, -PI / 4, PI / 2, -PI / 2]:
			var alternative := safe_motion(unit, wanted.rotated(angle * unit.avoid_side), true)
			if alternative.dot(axis) < -0.00001: continue
			if (wanted-alternative).length_squared() >= wanted.length_squared(): continue
			if alternative.length() > motion.length() + 0.01:
				motion = alternative
				if motion.length() >= wanted.length() * 0.8: break
	if motion.dot(axis) < -0.00001: motion = Vector2.ZERO
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
			# Recheck nearby openings after movement/casualties; blocked soldiers wait
			# or follow their slot instead of attacking through a friendly body.
			if not can_strike(unit, unit.opponent):
				unit.opponent = nearest_opponent(unit, foes(key), true)
			if can_strike(unit, unit.opponent):
				unit.target = unit.position
				unit.combat_slot = unit.position
				unit.march_path.clear()
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
			elif unit.position.distance_to(unit.combat_slot) > 0.1:
				# Follow the locally available space while the leading soldiers fight.
				advance_unit(unit, delta)
			else:
				unit.target = unit.position
				unit.enter_idle()

	# Resolve simultaneous impacts together; a hit never damages a whole formation.
	for hit in hits:
		var attacker: BattleUnit = hit.attacker
		var victim: BattleUnit = hit.target
		attacker.damage_dealt += mini(victim.hp, attacker.attack_damage)
		victim.take_damage(attacker.attack_damage)
	if not hits.is_empty(): plan_time = 0.0
	map.queue_redraw()
