extends SceneTree
const Art = preload("res://scripts/character_art.gd")
const Combat = preload("res://scripts/battle_combat.gd")
const Ranged = preload("res://scripts/battle_ranged.gd")
var game: Control

func _initialize() -> void:
	call_deferred("run")

func advance(map: BattleMap, seconds: float) -> void:
	for i in range(int(round(seconds*60))): map._physics_process(1.0/60.0)

func click(map: BattleMap, unit: BattleUnit) -> void:
	var event := InputEventMouseButton.new()
	event.position = map.world_to_screen(unit.position+BattleMap.BODY_CENTER_FROM_FEET)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	map._unhandled_input(event)
	event.pressed = false
	map._unhandled_input(event)

func fresh() -> BattleMap:
	game.show_battle()
	var map: BattleMap = game.battle
	map.set_physics_process(false)
	return map

func prediction_check(map: BattleMap) -> void:
	var shooter := map.archers[0]
	var victim := map.enemies[0]
	for unit in map.combat.all_units():
		if unit != shooter and unit != victim: unit.take_damage(1000)
	shooter.position = Vector2(900,800)
	shooter.target = shooter.position
	shooter.accuracy = 1.0
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(-1,-1).normalized()]:
		map.combat.orders.clear()
		victim.hp = 100
		victim.position = Vector2(1300,800)
		victim.target = victim.position+direction*400
		victim.march_path.clear()
		advance(map,0.1)
		assert(victim.velocity.dot(direction) > 70, "Prediction must use actual movement in every direction")
		var shot: BattleArrow = map.combat.ranged.fire(shooter,victim)
		var lead := shot.landing-victim.contact_box().get_center()
		assert(lead.dot(direction) > 20 and absf(lead.cross(direction)) < 0.1)
		assert(lead.distance_to(victim.velocity*shot.duration) < 0.2, "Lead must account for flight time to the predicted point")
		var fixed_landing := shot.landing
		# Follow the real march loop to impact, not a manually teleported target.
		advance(map,shot.duration+0.05)
		assert(victim.hp == 96, "Consistent straight/diagonal motion should intersect the led arrow")
		assert(shot.landing == fixed_landing, "Projectile endpoints never track the target after release")
	# Stop and reverse after release: the arrow must continue to its frozen point.
	for reverse in [false,true]:
		map.combat.orders.clear()
		victim.hp = 100
		victim.position = Vector2(1300,800)
		victim.target = victim.position+Vector2(400,0)
		advance(map,0.1)
		var shot: BattleArrow = map.combat.ranged.fire(shooter,victim)
		var fixed_landing := shot.landing
		victim.target = victim.position + (Vector2(-300,0) if reverse else Vector2.ZERO)
		advance(map,shot.duration+0.05)
		assert(shot.landing == fixed_landing and victim.hp == 100)
	map.combat.orders.clear()
	victim.target = victim.position
	advance(map,0.1)
	assert(victim.velocity.is_zero_approx())
	var idle: BattleArrow = map.combat.ranged.fire(shooter,victim)
	assert(idle.landing == victim.contact_box().get_center())
	map.combat.ranged.step(idle.duration)
	# A short remaining route must not be extrapolated beyond its destination.
	map.combat.orders.clear()
	victim.position = Vector2(1300,800)
	victim.target = victim.position+Vector2(3,0)
	advance(map,1.0/60.0)
	var arriving: BattleArrow = map.combat.ranged.fire(shooter,victim)
	assert(arriving.landing.distance_to(victim.target+BattleUnit.BODY_CENTER_FROM_FEET) < 0.1)
	map.combat.ranged.step(arriving.duration)
	# Paused orders do not create fake velocity; misses scatter around the lead.
	map.set_battle_paused(true)
	var frozen_velocity := victim.velocity
	victim.target += Vector2(0,200)
	advance(map,0.5)
	assert(victim.velocity == frozen_velocity)
	map.set_battle_paused(false)
	advance(map,0.1)
	shooter.accuracy = 0.0
	var miss: BattleArrow = map.combat.ranged.fire(shooter,victim)
	assert(miss.aim_snapshot.y > victim.contact_box().get_center().y)
	assert(miss.landing.distance_to(miss.aim_snapshot) >= 11.9 and miss.landing.distance_to(miss.aim_snapshot) <= 24.1)
	map.combat.ranged.step(miss.duration)
	print("PASS: measured motion leads horizontal/vertical/diagonal targets into actual impacts; stationary/arrival aims, frozen stops/turns, paused velocity and miss scatter")

func art_check() -> void:
	var catalog := Art.data()
	var config := Art.archer_appearance(true,0)
	var infantry := Art.infantry_appearance(true,0)
	for key in infantry:
		if key not in ["equipped_weapon", "offhand", "offhand_item"]: assert(config[key] == infantry[key])
	assert(Art.equipped_weapon(config).id == "bow/1" and config.offhand == -1)
	var frames := Art.infantry_frames(config,true)
	assert(frames.get_frame_count("attack") == 12 and frames.get_animation_speed("attack") == 10)
	for movement in ["idle", "walk", "run"]:
		for i in Art.FRAME_COUNTS[movement]:
			assert(Art.weapon_position(config,movement,i) + Vector2i(16,16) == Art.weapon_anchor(config,movement,i))
	var strip := Image.create(Art.FRAME_SIZE.x*6,Art.FRAME_SIZE.y*2,false,Image.FORMAT_RGBA8)
	for i in range(12):
		assert(Art.weapon_anchor(config,"attack",i) == Art.NON_MELEE_WEAPON_ANCHOR + Vector2i(1, 0))
		var source := Art.part_image(catalog.bow_shot,i)
		assert(Art.weapon_position(config,"attack",i) + source.get_size()/2 == Art.weapon_anchor(config,"attack",i))
		var occupied := source.get_used_rect()
		occupied.position += Art.weapon_position(config,"attack",i)
		assert(Rect2i(Vector2i.ZERO,Art.FRAME_SIZE).encloses(occupied), "Original bow shot must not be clipped")
		var actual := frames.get_frame_texture("attack",i).get_image()
		strip.blit_rect(actual,Rect2i(Vector2i.ZERO,Art.FRAME_SIZE),Vector2i((i%6)*Art.FRAME_SIZE.x,(i/6)*Art.FRAME_SIZE.y))
		assert(Art.pose("attack",i,"bow_shot",3).body_frame == 0)
	assert(Art.part_image(catalog.arrow,0).get_data() == Image.load_from_file("res://art/medieval/sprites/weapons/projectiles/arrow/arrow_01.png").get_data())
	strip.save_png("/workspace/outputs/archer-shot-strip.png")
	print("PASS: infantry appearance, two-handed bow/1, all 12 native bow_shot poses, original arrow_01")

func run() -> void:
	seed(20261116)
	root.size = Vector2i(1280,800)
	art_check()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var map := fresh()
	await process_frame
	assert(map.archers.size() == 20 and map.friendlies.size() == 41 and map.enemies.size() == 20)
	assert(Combat.center(map.archers) == Combat.center(map.infantry)+Vector2(0,160))
	for unit in map.archers:
		assert(unit.allied and unit.ranged and unit.hp == 6 and unit.max_hp == 6 and unit.attack_damage == 4 and unit.accuracy == 0.6)
	for unit in map.infantry + map.enemies: assert(unit.accuracy == 0.75 and not unit.ranged)
	assert(map.hero_group[0].accuracy == 0.8)
	click(map,map.archers[0])
	assert(map.selection.size() == 20 and map.selection.has(map.archers[0]) and not map.selection.has(map.infantry[0]))
	click(map,map.infantry[0])
	assert(map.selection.size() == 20 and not map.selection.has(map.archers[0]))
	map.selection.assign(map.infantry+map.archers)
	var separation := Combat.center(map.archers)-Combat.center(map.infantry)
	map.issue_move(Combat.center(map.selection)+Vector2(80,0))
	advance(map,3.0)
	assert((Combat.center(map.archers)-Combat.center(map.infantry)).distance_to(separation) < 0.1)
	for unit in map.selection: assert(unit.position.distance_to(unit.target)<0.1)
	print("PASS: 20 allied archers below infantry, independent selection and mixed-formation marching")
	# Actual attack order approaches, halts at range and releases a varied volley.
	map.selection.assign(map.archers)
	map.issue_attack(map.enemies[0])
	advance(map,1.0)
	assert(map.archers.all(func(unit: BattleUnit) -> bool: return unit.shots_fired == 0))
	for i in range(1200):
		map._physics_process(1.0/60.0)
		if not map.combat.ranged.projectiles.is_empty(): break
	assert(map.combat.engaged("archers") and map.combat.ranged.projectiles.size() == 20)
	var victims: Dictionary = {}
	for arrow: BattleArrow in map.combat.ranged.projectiles:
		victims[arrow.intended] = true
		assert(arrow.shooter.position.distance_to(arrow.intended.position) <= Ranged.RANGE)
		assert(arrow.elapsed == 0.0 and arrow.aim_snapshot == arrow.intended.contact_box().get_center())
	assert(victims.size() > 5, "Individual archers choose random targets")
	var first: BattleArrow = map.combat.ranged.projectiles[0]
	var frozen := [first.position,first.elapsed,first.sprite.position,map.archers[0].cooldown,map.archers[0].shot_time,map.archers[0].frame]
	map.set_battle_paused(true)
	advance(map,8.0)
	assert(frozen == [first.position,first.elapsed,first.sprite.position,map.archers[0].cooldown,map.archers[0].shot_time,map.archers[0].frame])
	map.issue_move(Combat.center(map.archers)+Vector2(0,90))
	var before := map.archers[0].position
	advance(map,1.0)
	assert(map.archers[0].position == before and first.elapsed == 0.0)
	map.set_battle_paused(false)
	advance(map,0.3)
	assert(map.archers[0].position != before and first.elapsed > 0)
	assert(not map.combat.orders.has("archers"))
	print("PASS: range-limited approach, random target volley, paused arrows/draw/cooldowns and queued movement")
	# Isolate projectile impacts from enemy AI movement.
	map = fresh()
	await process_frame
	var shooter := map.archers[0]
	var victim := map.enemies[0]
	shooter.position = Vector2(1100,800)
	shooter.target = shooter.position
	victim.position = Vector2(900,800)
	var left_shot: BattleArrow = map.combat.ranged.fire(shooter, victim)
	assert(not shooter.flip_h and left_shot.launch == shooter.position + Vector2(-16,-13))
	map.combat.ranged.projectiles.erase(left_shot)
	left_shot.queue_free()
	victim.position = Vector2(1300,800)
	victim.target = victim.position+Vector2(1,0) # Explicit move prevents auto retaliation in this fixture.
	shooter.accuracy = 1.0
	var arrow: BattleArrow = map.combat.ranged.fire(shooter,victim)
	assert(shooter.flip_h and arrow.launch == shooter.position + Vector2(16,-13))
	# Keep a visible but low arc at short/long distances in every firing direction.
	# Compare orientation to actual neighboring positions instead of forcing a down-facing tip.
	for offset in [Vector2(40,0),Vector2(320,0),Vector2(640,0),Vector2(-640,0),Vector2(0,-640),Vector2(0,640),Vector2(400,-400)]:
		var probe := BattleArrow.new()
		probe.configure(shooter.position,shooter.position+offset,shooter,victim,true)
		probe.advance(probe.duration*0.5)
		var rise := -probe.sprite.position.y
		assert(rise > 0 and rise <= 160)
		assert(rise < maxf(48.0,offset.length()*0.65)*0.4, "Arc must be substantially lower than the former steep flight")
		for fraction in [0.1,0.5,0.9]:
			probe.elapsed = probe.duration*(fraction-0.001)
			probe.update_pose()
			var path_before := probe.position+probe.sprite.position
			probe.elapsed = probe.duration*(fraction+0.001)
			probe.update_pose()
			var path_after := probe.position+probe.sprite.position
			probe.elapsed = probe.duration*fraction
			probe.update_pose()
			assert(Vector2.RIGHT.rotated(probe.sprite.rotation).dot((path_after-path_before).normalized()) > 0.999)
		probe.advance(probe.duration)
		assert(probe.position.is_equal_approx(probe.landing) and probe.sprite.position.is_zero_approx())
		if offset == Vector2(0,-640):
			assert(Vector2.RIGHT.rotated(probe.sprite.rotation).y < 0, "Do not force downward orientation against the actual path")
		probe.free()
	# At maximum range retain the raised 160px arc / horizontal launch angle.
	# Nearer shots must become progressively flatter, without the old minimum loft.
	var previous_angle := -1.0
	for distance in [40.0,80.0,160.0,320.0,480.0,640.0]:
		var distance_probe := BattleArrow.new()
		distance_probe.configure(shooter.position,shooter.position+Vector2(distance,0),shooter,victim,true,Ranged.RANGE)
		var launch_tip := Vector2.RIGHT.rotated(distance_probe.sprite.rotation)
		var launch_angle := absf(launch_tip.angle())
		assert(launch_angle > previous_angle, "Closer shots must use a smaller launch angle")
		previous_angle = launch_angle
		if distance <= 160.0: assert(launch_angle < deg_to_rad(15))
		if distance == 640.0:
			assert(is_equal_approx(distance_probe.arc_height,160.0))
			assert(absf(launch_angle-atan(1.0)) < 0.005)
		distance_probe.free()
	print("PASS: raised maximum-range arc; progressively flatter launch angles from 640px to 40px")
	# Measure visual travel, including the arc, rather than only the ground projection.
	for offset in [Vector2(20,0),Vector2(80,0),Vector2(160,0),Vector2(320,0),Vector2(640,0),Vector2(0,-640),Vector2(0,640),Vector2(400,-400)]:
		var speed_probe := BattleArrow.new()
		speed_probe.configure(shooter.position,shooter.position+offset,shooter,victim,true,Ranged.RANGE)
		assert(is_equal_approx(speed_probe.duration,BattleArrow.flight_time(speed_probe.launch,speed_probe.landing,Ranged.RANGE)))
		var sample_delta := speed_probe.duration/200.0
		var traveled_length := 0.0
		for sample in range(200):
			var visual_before := speed_probe.position+speed_probe.sprite.position
			speed_probe.advance(sample_delta)
			var traveled := visual_before.distance_to(speed_probe.position+speed_probe.sprite.position)
			traveled_length += traveled
			assert(absf(traveled/sample_delta-BattleArrow.FLIGHT_SPEED) < 2.0, "Visible arrow speed must stay constant near/far and throughout the arc")
		assert(absf(traveled_length/speed_probe.duration-BattleArrow.FLIGHT_SPEED) < 0.5)
		assert(speed_probe.position.distance_to(speed_probe.landing) < 0.01)
		speed_probe.free()
	print("PASS: 480px/s visual arc travel at short/long distances and all directions; shared flight times")
	var endpoint := arrow.landing
	map.combat.ranged.step(arrow.duration*0.5)
	assert(arrow.landing == endpoint and arrow.sprite.position.y < -10 and victim.hp == 10)
	victim.position += Vector2(0,40)
	map.combat.ranged.step(arrow.duration)
	assert(victim.hp == 10, "Moving off the sampled impact point must dodge the arrow")
	arrow = map.combat.ranged.fire(shooter,victim)
	map.combat.ranged.step(arrow.duration)
	assert(victim.hp == 6 and victim.health_bar.visible and victim.health_time == 4.0)
	shooter.accuracy = 0.0
	for i in range(10):
		arrow = map.combat.ranged.fire(shooter,victim)
		assert(not arrow.accurate and arrow.landing.distance_to(arrow.aim_snapshot) >= 11.9)
		map.combat.ranged.step(arrow.duration)
	assert(victim.hp == 6, "Failed accuracy rolls never apply damage")
	shooter.accuracy = 1.0
	arrow = map.combat.ranged.fire(shooter,victim)
	shooter.take_damage(1000)
	map.combat.ranged.step(arrow.duration)
	assert(victim.hp == 2, "Already-fired arrows survive the shooter's death")
	print("PASS: parabolic non-homing flight, movement dodge, damage only at impact, missed shots and posthumous flight")
	# The firing loop has a four-second cadence; keep stationary durable targets.
	map = fresh()
	await process_frame
	var shift := Combat.center(map.archers)+Vector2(230,0)-Combat.center(map.enemies)
	for enemy in map.enemies:
		enemy.position += shift
		enemy.target = enemy.position+Vector2(1,0)
		enemy.hp = 10000
	for unit in map.archers: unit.accuracy = 0.0
	map.combat.command(map.archers,map.enemies[0])
	var releases: Array[float] = []
	var count := 0
	for i in range(660):
		map.combat.prepare(1.0/60.0)
		map.combat.ranged.step(1.0/60.0)
		if map.archers[0].shots_fired != count:
			count = map.archers[0].shots_fired
			releases.append(i/60.0)
	assert(releases.size() == 3)
	for i in range(1,releases.size()): assert(absf(releases[i]-releases[i-1]-4.0) <= 0.02)
	for unit in map.archers: assert(unit.shots_fired == 3)
	# Check the configured Bernoulli rolls independently of target movement.
	for sample: BattleUnit in [map.archers[0],map.infantry[0]]:
		sample.accuracy = 0.6 if sample.ranged else 0.75
		var hits := 0
		for i in range(10000): hits += int(sample.roll_hit())
		assert(absf(hits/10000.0-sample.accuracy) < 0.02)
	print("PASS: 4-second cadence and seeded 60%/75% hit-roll distributions")
	# A melee miss still animates but applies no damage; a hit applies four.
	map = fresh()
	await process_frame
	shooter = map.infantry[0]
	victim = map.enemies[0]
	for unit in map.combat.all_units():
		if unit != shooter and unit != victim: unit.take_damage(1000)
	victim.position = shooter.position+Vector2(12,0)
	victim.target = victim.position
	shooter.accuracy = 0.0
	victim.accuracy = 0.0
	map.selection.assign([shooter])
	map.issue_attack(victim)
	advance(map,0.4)
	assert(shooter.animation == &"attack" and shooter.hp == 10 and victim.hp == 10)
	shooter.accuracy = 1.0
	advance(map,1.0)
	assert(victim.hp == 6)
	print("PASS: infantry misses animate without damage and successful strikes apply four damage")
	prediction_check(fresh())
	quit()
