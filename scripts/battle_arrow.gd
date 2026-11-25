class_name BattleArrow
extends Node2D
## A fixed parabola traversed at constant world-pixel speed; never tracks its target.
const FLIGHT_SPEED := 480.0
const MAX_ARC_HEIGHT := 160.0
const PATH_SEGMENTS := 128
var launch := Vector2.ZERO
var landing := Vector2.ZERO
var aim_snapshot := Vector2.ZERO
var duration := 1.0
var elapsed := 0.0
var arc_height := 40.0
var damage := 4
var allied := true
var accurate := false
var shooter: BattleUnit
var intended: BattleUnit
var sprite: Sprite2D
var path_points := PackedVector2Array()
var path_lengths := PackedFloat64Array()
static var arrow_texture: Texture2D

static func path_profile(from: Vector2, to: Vector2, shot_range := 640.0) -> Dictionary:
	var range_fraction := clampf(from.distance_to(to)/maxf(shot_range,1.0),0.0,1.0)
	var height := MAX_ARC_HEIGHT*range_fraction*range_fraction
	var points := PackedVector2Array([Vector2.ZERO])
	var lengths := PackedFloat64Array([0.0])
	for i in range(1,PATH_SEGMENTS+1):
		var t := float(i)/PATH_SEGMENTS
		var point := (to-from)*t + Vector2(0,-4.0*height*t*(1.0-t))
		lengths.append(lengths[-1]+points[-1].distance_to(point))
		points.append(point)
	return {"height":height,"points":points,"lengths":lengths}

static func flight_time(from: Vector2, to: Vector2, shot_range := 640.0) -> float:
	var profile := path_profile(from,to,shot_range)
	return maxf(profile.lengths[-1]/FLIGHT_SPEED,0.000001)

func configure(from: Vector2, to: Vector2, source: BattleUnit, target: BattleUnit, hit: bool, shot_range := 640.0) -> void:
	launch = from
	landing = to
	aim_snapshot = target.contact_box().get_center()
	shooter = source
	intended = target
	damage = source.attack_damage
	allied = source.allied
	accurate = hit
	var profile := path_profile(from,to,shot_range)
	arc_height = profile.height
	path_points = profile.points
	path_lengths = profile.lengths
	duration = maxf(path_lengths[-1]/FLIGHT_SPEED,0.000001)
	if arrow_texture == null:
		arrow_texture = ImageTexture.create_from_image(CharacterArt.part_image(CharacterArt.data().arrow, 0))
	sprite = Sprite2D.new()
	sprite.texture = arrow_texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(arrow_texture.get_size())*0.5-Vector2(arrow_texture.get_image().get_used_rect().get_center())
	z_index = 1
	add_child(sprite)
	update_pose()

func update_pose() -> void:
	var traveled := clampf(elapsed*FLIGHT_SPEED,0.0,path_lengths[-1])
	var index := clampi(path_lengths.bsearch(traveled),1,PATH_SEGMENTS)
	var segment_length := path_lengths[index]-path_lengths[index-1]
	var fraction := (traveled-path_lengths[index-1])/segment_length if segment_length > 0.0 else 1.0
	var t := (index-1+fraction)/PATH_SEGMENTS
	position = launch.lerp(landing,t)
	sprite.position = path_points[index-1].lerp(path_points[index],fraction)-(landing-launch)*t
	# The source arrow points right in its untouched source PNG. Follow the actual segment.
	var tangent := path_points[index]-path_points[index-1]
	sprite.rotation = tangent.angle()

func advance(delta: float) -> bool:
	elapsed = minf(duration, elapsed+delta)
	update_pose()
	return elapsed >= duration
