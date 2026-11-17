class_name BattleArrow
extends Node2D
## A ballistic path stores its destination once; no target tracking in flight.
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
static var arrow_texture: Texture2D

func configure(from: Vector2, to: Vector2, source: BattleUnit, target: BattleUnit, hit: bool) -> void:
	launch = from
	landing = to
	aim_snapshot = target.contact_box().get_center()
	shooter = source
	intended = target
	damage = source.attack_damage
	allied = source.allied
	accurate = hit
	duration = clampf(from.distance_to(to)/240.0, 0.35, 1.5)
	# A modest, capped arc takes priority over forcing a downward-facing impact.
	arc_height = clampf(from.distance_to(to)*0.22, 18.0, 128.0)
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
	var t := clampf(elapsed/duration, 0.0, 1.0)
	position = launch.lerp(landing, t)
	sprite.position = Vector2(0, -4.0*arc_height*t*(1.0-t))
	var tangent := landing-launch+Vector2(0,-4.0*arc_height*(1.0-2.0*t))
	# arrow_01 points left in its untouched source PNG.
	sprite.rotation = tangent.angle()+PI

func advance(delta: float) -> bool:
	elapsed = minf(duration, elapsed+delta)
	update_pose()
	return elapsed >= duration
