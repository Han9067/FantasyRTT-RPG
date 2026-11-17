extends RefCounted
## Local passage around idle allies; each soldier retains its destination slot.
const CLEARANCE := 6.0
var map: Node2D
var simulation_time := 0.0
var failed_searches: Dictionary = {}

func begin_frame(delta: float) -> void:
	simulation_time += delta

func _init(battle: Node2D) -> void:
	map = battle

func idle_allies(others: Array[BattleUnit]) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in others:
		if unit.alive() and unit.position.is_equal_approx(unit.target) and unit.swing_time < 0.0 and not map.combat.engaged(map.combat.key_for(unit)):
			result.append(unit)
	return result

func clear_line(start: Vector2, finish: Vector2, obstacles: Array[BattleUnit], clearance := CLEARANCE) -> bool:
	var point := Rect2(start, Vector2(0.00001, 0.00001))
	var nearby := Rect2(start,finish-start).abs().grow(clearance+0.0001)
	for obstacle in obstacles:
		if not nearby.has_point(obstacle.position): continue
		var box := Rect2(obstacle.position - Vector2.ONE * clearance, Vector2.ONE * clearance * 2.0)
		if map.contact_fraction(point, finish - start, box) < 1.0: return false
	return true

func route(start: Vector2, finish: Vector2, obstacles: Array[BattleUnit], forward_axis := Vector2.ZERO, clearance := CLEARANCE) -> Array[Vector2]:
	# No graph can reach an endpoint already inside an allied body.
	if not clear_line(finish,finish,obstacles,clearance): return []
	# A visibility graph uses individual bodies, so gaps within an idle formation stay open.
	var points: Array[Vector2] = [start, finish]
	for obstacle in obstacles:
		for corner in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
			var point: Vector2 = obstacle.position + corner * (clearance + 0.1)
			if candidate_reachable(start,finish,point,forward_axis) and map.playable_rect().has_point(point) and clear_line(point, point, obstacles, clearance): points.append(point)
			if forward_axis != Vector2.ZERO:
				# A soldier already beside a blocker may first step sideways at its
				# current depth, without backing up to the obstacle's rear corner.
				var side_point := point-forward_axis*(point-start).dot(forward_axis)
				if candidate_reachable(start,finish,side_point,forward_axis) and not points.has(side_point) and map.playable_rect().has_point(side_point) and clear_line(side_point, side_point, obstacles, clearance): points.append(side_point)
	var heuristic: Array[float] = []
	for point in points: heuristic.append(point.distance_to(finish))
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
			if not visited[i] and costs[i] < INF and (current == -1 or costs[i]+heuristic[i] < costs[current]+heuristic[current]): current = i
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
			# Ordinary marching is unrestricted. Melee routes may go sideways or
			# forward through a gap, but must not retreat to circle an occupied rank.
			if (points[next]-points[current]).dot(forward_axis) < -0.00001: continue
			var cost := costs[current] + points[current].distance_to(points[next])
			if cost < costs[next] and clear_line(points[current], points[next], obstacles, clearance):
				costs[next] = cost
				previous[next] = current
	return []

static func candidate_reachable(start: Vector2, finish: Vector2, point: Vector2, axis: Vector2) -> bool:
	# A forward-only route can never use points behind its start or past its goal.
	return axis == Vector2.ZERO or ((point-start).dot(axis) >= -0.00001 and (finish-point).dot(axis) >= -0.00001)

func waypoint(unit: BattleUnit, obstacles: Array[BattleUnit], forward_axis := Vector2.ZERO, clearance := CLEARANCE) -> Vector2:
	if clear_line(unit.position, unit.target, obstacles, clearance):
		unit.march_path.clear()
		failed_searches.erase(unit)
		return unit.target
	while not unit.march_path.is_empty() and unit.position.distance_to(unit.march_path[0]) < 0.05:
		unit.march_path.pop_front()
	if not unit.march_path.is_empty() and (unit.march_path[0]-unit.position).dot(forward_axis) < -0.00001:
		unit.march_path.clear()
	if unit.march_path.is_empty() or not clear_line(unit.position, unit.march_path[0], obstacles, clearance):
		var failed: Dictionary = failed_searches.get(unit,{})
		if not failed.is_empty() and simulation_time < failed.until and unit.position.distance_squared_to(failed.start) < 4.0 and unit.target.is_equal_approx(failed.goal) and forward_axis == failed.axis and clearance == failed.clearance and obstacles.size() == failed.count:
			return unit.target
		unit.march_path = route(unit.position, unit.target, obstacles, forward_axis, clearance)
		if unit.march_path.is_empty():
			failed_searches[unit] = {"until":simulation_time+0.08+0.02*(unit.get_index()%5),"start":unit.position,"goal":unit.target,"axis":forward_axis,"clearance":clearance,"count":obstacles.size()}
		else:
			failed_searches.erase(unit)
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
