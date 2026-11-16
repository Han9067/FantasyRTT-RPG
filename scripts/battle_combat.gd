extends RefCounted
## Formation approach, then individual melee slots with solid unit collisions.
const REACH := 25.0
const ENGAGE_DISTANCE := 43.0
const FIGHTING_DEPTH_GAP := 7.0
const RESERVE_GAP := 18.0
const RESERVE_DEPTH_GAP := 18.0
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

func replace_fronts(key: String) -> void:
	var fronts: Array[BattleUnit] = orders[key].fronts
	# Keep vacant cells so exactly one random reserve inherits each fallen fighter's role.
	for i in range(fronts.size()):
		if fronts[i].alive(): continue
		var columns := reserve_columns(key)
		if columns.is_empty(): break
		var first: Array = columns[0]
		fronts[i] = first[randi_range(0, first.size()-1)]
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
	if enemy == null or not enemy.alive() or unit.allied == enemy.allied: return false
	if unit.position.distance_to(enemy.position) > REACH: return false
	var ray := Rect2(unit.contact_box().get_center(), Vector2(0.1, 0.1))
	var motion := enemy.position - unit.position
	for other in all_units():
		if other == unit or other == enemy or not other.alive(): continue
		# The compressed fighting half can strike past its own participating comrades.
		# Reserves and unrelated groups still block the line; all movement stays solid.
		if key_for(other) == key_for(unit) and is_front(unit) and is_front(other): continue
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
	if unit.combat_slot.distance_squared_to(point) > 1.0: unit.march_path.clear()
	unit.combat_slot = point

func plan_slots() -> void:
	var layouts: Dictionary = {}
	for key: String in orders:
		if engaged(key):
			replace_fronts(key)
			layouts[key] = active_layout(key)
	for key: String in orders:
		if not engaged(key): continue
		var order: Dictionary = orders[key]
		var axis: Vector2 = order.axis
		var lateral := axis.orthogonal()
		var opponents: Array[BattleUnit] = []
		var layout: Dictionary = layouts[key]
		var combined_depths: int = layout.depths
		for enemy in foes(key):
			var other_key := key_for(enemy)
			if not engaged(other_key) or is_front(enemy):
				opponents.append(enemy)
				if engaged(other_key): combined_depths = maxi(combined_depths, layouts[other_key].depths)
		if opponents.is_empty(): continue
		var forward := INF
		var lower := INF
		var upper := -INF
		for enemy in opponents:
			forward = minf(forward, enemy.position.dot(axis))
			lower = minf(lower, enemy.position.dot(lateral))
			upper = maxf(upper, enemy.position.dot(lateral))
		var lane_spacing: float = map.FORMATION_SPACING.y if axis.x != 0 else map.FORMATION_SPACING.x
		lane_spacing = minf(lane_spacing, maxf(6.0, (upper-lower+lane_spacing) / layout.width))
		var side: float = clampf(order.lateral_center, lower, upper)
		var depth_gap := minf(FIGHTING_DEPTH_GAP, (REACH-7.0) / maxi(1, combined_depths-1))
		var contact_gap := REACH - 1.0 - (combined_depths-1) * depth_gap
		var own_forward := -INF
		for unit in living(order.fronts): own_forward = maxf(own_forward, unit.position.dot(axis))
		if own_forward == -INF: continue
		# Both sides approach the same contact midpoint, avoiding alternating overshoot.
		var first_plane := (own_forward + forward - contact_gap) * 0.5
		var fronts: Array[BattleUnit] = order.fronts
		for i in range(fronts.size()):
			var unit := fronts[i]
			if not unit.alive(): continue
			var cell: Vector2 = layout.cells[i]
			set_slot(unit, map.clamp_point(axis * (first_plane-cell.x*depth_gap) + lateral * (side+cell.y*lane_spacing)))
			var best := INF
			unit.opponent = null
			for enemy in opponents:
				var cost := unit.position.distance_squared_to(enemy.position)
				if cost < best:
					best = cost
					unit.opponent = enemy
		var columns := reserve_columns(key)
		for i in range(columns.size()):
			var column: Array = columns[i]
			var plane: float = first_plane - (layout.depths-1)*depth_gap - RESERVE_GAP - i*RESERVE_DEPTH_GAP
			for row in range(column.size()):
				var unit: BattleUnit = column[row]
				unit.opponent = null
				set_slot(unit, map.clamp_point(axis*plane + lateral*(side+(row-(column.size()-1)*0.5)*lane_spacing)))

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
				var size := Vector2(6, 6)
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
	if motion.length() < wanted.length() * 0.8 or not unit.march_path.is_empty():
		var allies := living(group(key_for(unit)))
		allies.erase(unit)
		# A random replacement may need to cross lanes. Route through real gaps
		# instead of leaving it stuck behind an occupied fighting cell.
		var waypoint: Vector2 = map.march.waypoint(unit, allies)
		wanted = (waypoint - unit.position).limit_length(map.MOVE_SPEED * delta)
		motion = safe_motion(unit, wanted, true)
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
			if not is_front(unit):
				# Waiting ranks move with the engagement and stay immediately behind it.
				if unit.position.distance_to(unit.combat_slot) > 0.1: advance_unit(unit, delta)
				else:
					unit.target = unit.position
					unit.enter_idle()
				continue
			if unit.opponent == null or not unit.opponent.alive():
				unit.target = unit.position
				unit.enter_idle()
				continue
			if can_strike(unit, unit.opponent) and unit.cooldown <= 0.0:
				unit.target = unit.position
				face(unit, unit.opponent.position)
				unit.cooldown = ATTACK_INTERVAL
				unit.swing_time = 0.0
				unit.march_path.clear()
				unit.swing_target = unit.opponent
				unit.impact_done = false
				unit.play(&"attack")
				unit.set_frame_and_progress(0, 0.0)
			elif unit.position.distance_to(unit.combat_slot) > 0.1:
				# Close the fighting ranks between swings, rather than stopping the whole
				# group as soon as the first row enters attack range.
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
