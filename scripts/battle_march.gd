extends RefCounted
## Local passage around idle allies; each soldier retains its destination slot.
const CLEARANCE := 6.0
var map: Node2D

func _init(battle: Node2D) -> void:
	map = battle

func idle_allies(others: Array[BattleUnit]) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in others:
		if unit.alive() and unit.position.is_equal_approx(unit.target) and unit.swing_time < 0.0 and not map.combat.engaged(map.combat.key_for(unit)):
			result.append(unit)
	return result

func clear_line(start: Vector2, finish: Vector2, obstacles: Array[BattleUnit]) -> bool:
	var point := Rect2(start, Vector2(0.001, 0.001))
	for obstacle in obstacles:
		var box := Rect2(obstacle.position - Vector2.ONE * CLEARANCE, Vector2.ONE * CLEARANCE * 2.0)
		if map.contact_fraction(point, finish - start, box) < 1.0: return false
	return true

func route(start: Vector2, finish: Vector2, obstacles: Array[BattleUnit]) -> Array[Vector2]:
	# A visibility graph uses individual bodies, so gaps within an idle formation stay open.
	var points: Array[Vector2] = [start, finish]
	for obstacle in obstacles:
		for corner in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
			var point: Vector2 = obstacle.position + corner * (CLEARANCE + 0.1)
			if map.playable_rect().has_point(point) and clear_line(point, point, obstacles): points.append(point)
	var costs: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	costs.resize(points.size()); costs.fill(INF)
	previous.resize(points.size()); previous.fill(-1)
	visited.resize(points.size()); visited.fill(false)
	costs[0] = 0.0
	for iteration in range(points.size()):
		var current := -1
		for i in range(points.size()):
			if not visited[i] and costs[i] < INF and (current == -1 or costs[i] < costs[current]): current = i
		if current == -1: break
		if current == 1:
			var path: Array[Vector2] = []
			while current != 0:
				path.push_front(points[current])
				current = previous[current]
			return path
		visited[current] = true
		for next in range(points.size()):
			if visited[next]: continue
			var cost := costs[current] + points[current].distance_to(points[next])
			if cost < costs[next] and clear_line(points[current], points[next], obstacles):
				costs[next] = cost
				previous[next] = current
	return []

func waypoint(unit: BattleUnit, obstacles: Array[BattleUnit]) -> Vector2:
	if clear_line(unit.position, unit.target, obstacles):
		unit.march_path.clear()
		return unit.target
	while not unit.march_path.is_empty() and unit.position.distance_to(unit.march_path[0]) < 0.05:
		unit.march_path.pop_front()
	if unit.march_path.is_empty() or not clear_line(unit.position, unit.march_path[0], obstacles):
		unit.march_path = route(unit.position, unit.target, obstacles)
	return unit.target if unit.march_path.is_empty() else unit.march_path[0]

func advance(members: Array[BattleUnit], enemies: Array[BattleUnit], delta: float, others: Array[BattleUnit]) -> void:
	if members.is_empty(): return
	var idle := idle_allies(others)
	var movement := members[0].target - members[0].position
	var flexible := false
	for unit in members:
		if not (unit.target - unit.position).is_equal_approx(movement) or not clear_line(unit.position, unit.target, idle):
			flexible = true
			break
	if not flexible:
		map.advance_rigid_formation(members, enemies, delta, others)
		return
	# Small steps also preserve swept collision when a frame is unusually long.
	var remaining := delta
	while remaining > 0.00001:
		var step := minf(remaining, 1.0 / 60.0)
		advance_flexible(members, enemies, step, idle)
		remaining -= step
	map.queue_redraw()

func advance_flexible(members: Array[BattleUnit], enemies: Array[BattleUnit], delta: float, idle: Array[BattleUnit]) -> void:
	var center := Vector2.ZERO
	var destination := Vector2.ZERO
	for member in members:
		center += member.position
		destination += member.target
	center /= members.size()
	destination /= members.size()
	var direction := (destination - center).normalized()
	var anchor := center.move_toward(destination, 24.0)
	var ordered := members.duplicate()
	# Let the leading soldiers vacate their space before the rear soldiers follow.
	ordered.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return a.position.distance_squared_to(a.target) < b.position.distance_squared_to(b.target))
	for unit: BattleUnit in ordered:
		if unit.position.is_equal_approx(unit.target):
			unit.position = unit.target
			unit.enter_idle()
			continue
		var goal := waypoint(unit, idle)
		# Recover the marching slot soon after clearing the ally, not only at arrival.
		var slot := anchor + unit.target - destination
		if unit.march_path.is_empty() and clear_line(unit.position, slot, idle): goal = slot
		var lag := (center + unit.target - destination - unit.position).dot(direction)
		var speed: float = map.MOVE_SPEED + clampf(lag * 4.0, 0.0, map.MOVE_SPEED * 0.25)
		var wanted := (goal - unit.position).limit_length(speed * delta)
		# A regular move still stops on the enemy front; attack commands enter melee first.
		for enemy in enemies:
			if map.contact_fraction(unit.contact_box(), wanted, enemy.contact_box()) < 1.0:
				for member in members:
					member.target = member.position
					member.march_path.clear()
					member.enter_idle()
				return
		var motion: Vector2 = map.combat.safe_motion(unit, wanted)
		if motion.length() < wanted.length() * 0.8:
			for angle in [PI / 4, -PI / 4, PI / 2, -PI / 2]:
				var alternative: Vector2 = map.combat.safe_motion(unit, wanted.rotated(angle * unit.avoid_side))
				if alternative.length() > motion.length() + 0.01:
					motion = alternative
					if motion.length() >= wanted.length() * 0.8: break
		if motion.length() > 0.00001:
			map.combat.face(unit, unit.position + motion)
			unit.position = map.clamp_point(unit.position + motion)
			if unit.position.is_equal_approx(unit.target):
				unit.position = unit.target
				unit.enter_idle()
			else: unit.play(&"walk")
		else: unit.enter_idle()
