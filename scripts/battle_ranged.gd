extends RefCounted
const Arrow = preload("res://scripts/battle_arrow.gd")
const RANGE := 640.0
const INTERVAL := 4.0
const RELEASE_TIME := 0.7
const SHOT_DURATION := 1.2
var map: Node2D
var projectiles: Array[BattleArrow] = []

func _init(battle: Node2D) -> void:
	map = battle

func targets() -> Array[BattleUnit]:
	var key: String = map.combat.orders.get("archers", {}).get("target_key", "enemy")
	return map.combat.living(map.combat.group(key))

func in_range(unit: BattleUnit, opponents: Array[BattleUnit]) -> Array[BattleUnit]:
	var available: Array[BattleUnit] = []
	for enemy in opponents:
		if enemy.alive() and enemy.allied != unit.allied and unit.position.distance_to(enemy.position) <= RANGE:
			available.append(enemy)
	return available

func prepare() -> void:
	var members: Array[BattleUnit] = map.combat.living(map.archers)
	var opponents := targets()
	if members.is_empty() or opponents.is_empty():
		map.combat.cancel("archers", not members.is_empty())
		return
	# Finish drawing before pursuing a target that has just left range.
	if members.any(func(unit: BattleUnit) -> bool: return unit.shot_time >= 0.0): return
	var ready := 0
	for unit in members:
		if not in_range(unit, opponents).is_empty(): ready += 1
	var holding: bool = map.combat.engaged("archers")
	if ready == members.size() or (holding and ready > 0):
		if not holding:
			map.combat.orders.archers.engaged = true
			for unit in members:
				unit.target = unit.position
				unit.march_path.clear()
		return
	map.combat.orders.archers.engaged = false
	var target_center: Vector2 = map.combat.center(opponents)
	var direction: Vector2 = (map.combat.center(members)-target_center).normalized()
	map.order_formation(members, target_center+direction*(RANGE-80.0))

func predicted_aim(start: Vector2, target: BattleUnit) -> Vector2:
	var current := target.contact_box().get_center()
	if target.velocity.length_squared() < 0.01 or target.position.is_equal_approx(target.target): return current
	var point := current
	# The predicted distance changes flight time. Iterate the same timing rule
	# used by the projectile, then freeze this estimate at release (never home).
	for iteration in range(10):
		var travel := target.velocity * Arrow.flight_time(start, point)
		travel = travel.limit_length(target.position.distance_to(target.target))
		point = map.clamp_point(target.position+travel) + BattleUnit.BODY_CENTER_FROM_FEET
	return point

func fire(unit: BattleUnit, target: BattleUnit) -> BattleArrow:
	map.combat.face(unit, target.position)
	var hit := unit.roll_hit()
	var start := unit.position+Vector2(17.0 if unit.flip_h else -17.0,-13.0)
	var aim := predicted_aim(start, target)
	var point := aim
	# A miss visibly falls wide; a successful accuracy roll can still be dodged.
	if not hit: point += Vector2.RIGHT.rotated(randf()*TAU)*randf_range(12.0,24.0)
	var arrow := Arrow.new()
	arrow.configure(start, point, unit, target, hit, RANGE)
	arrow.aim_snapshot = aim
	map.get_node("Units").add_child(arrow)
	projectiles.append(arrow)
	unit.shots_fired += 1
	return arrow

func resolve_impact(arrow: BattleArrow) -> void:
	if not arrow.accurate: return
	var victim: BattleUnit
	var closest := INF
	for unit in map.combat.all_units():
		if not unit.alive() or unit.allied == arrow.allied: continue
		if not unit.contact_box().grow(1.0).has_point(arrow.landing): continue
		var distance: float = unit.contact_box().get_center().distance_squared_to(arrow.landing)
		if distance < closest:
			closest = distance
			victim = unit
	if victim == null: return
	if is_instance_valid(arrow.shooter): arrow.shooter.damage_dealt += mini(victim.hp,arrow.damage)
	victim.take_damage(arrow.damage)
	# Idle defenders respond to being shot; explicit movement/retreat is respected.
	var key: String = map.combat.key_for(victim)
	var defenders: Array[BattleUnit] = map.combat.living(map.combat.group(key))
	if not map.combat.orders.has(key) and defenders.all(func(unit: BattleUnit) -> bool: return unit.position.is_equal_approx(unit.target)):
		map.combat.command(defenders)

func step(delta: float) -> void:
	# Advance existing arrows first: newly released arrows start at elapsed zero.
	for arrow in projectiles.duplicate():
		if arrow.advance(delta):
			resolve_impact(arrow)
			projectiles.erase(arrow)
			arrow.queue_free()
	if not map.combat.orders.has("archers"): return
	var opponents := targets()
	for unit: BattleUnit in map.combat.living(map.archers):
		if unit.shot_time >= 0.0:
			unit.shot_time += delta
			if not unit.shot_released and unit.shot_time >= RELEASE_TIME:
				unit.shot_released = true
				var available := in_range(unit, opponents)
				if not available.is_empty():
					# Choose uniformly from living in-range soldiers in the ordered group.
					unit.shot_target = available.pick_random()
					fire(unit,unit.shot_target)
			if unit.shot_time >= SHOT_DURATION:
				unit.shot_time = -1.0
				unit.enter_idle()
			continue
		if not map.combat.engaged("archers") or unit.cooldown > 0.0: continue
		var available := in_range(unit, opponents)
		if available.is_empty(): continue
		unit.shot_target = available.pick_random()
		map.combat.face(unit,unit.shot_target.position)
		unit.shot_time = 0.0
		unit.shot_released = false
		unit.cooldown = INTERVAL
		unit.target = unit.position
		unit.play(&"attack")
		unit.set_frame_and_progress(0,0.0)
