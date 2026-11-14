class_name BattleUnit
extends AnimatedSprite2D

const CONTACT_SIZE := Vector2(5, 5)
const BODY_CENTER_FROM_FEET := Vector2(0, -13)
var target := Vector2.ZERO
var allied := true
var max_hp := 10
var hp := 10
var attack_damage := 4
var health_time := 0.0
var health_bar: Node2D
var opponent: BattleUnit
var swing_target: BattleUnit
var swing_time := -1.0
var impact_done := false
var cooldown := 0.0
var combat_slot := Vector2.ZERO
var avoid_side := 1.0
var damage_dealt := 0

class HealthBar extends Node2D:
	func _draw() -> void:
		var unit: BattleUnit = get_parent()
		draw_rect(Rect2(-10, -39, 20, 5), Color("211a1b"))
		draw_rect(Rect2(-9, -38, 18, 3), Color("572629"))
		draw_rect(Rect2(-9, -38, 18.0 * unit.hp / unit.max_hp, 3), Color("ed4545"))

func _ready() -> void:
	health_bar = HealthBar.new()
	health_bar.z_index = 2
	health_bar.hide()
	add_child(health_bar)

func alive() -> bool:
	return hp > 0

func tick_health(delta: float) -> void:
	health_time = maxf(0.0, health_time - delta)
	health_bar.visible = alive() and health_time > 0.0

func take_damage(amount: int) -> void:
	if not alive(): return
	hp = maxi(0, hp - amount)
	health_time = 4.0
	health_bar.visible = hp > 0
	health_bar.queue_redraw()
	if hp == 0:
		target = position
		swing_time = -1.0
		opponent = null
		swing_target = null
		stop()
		hide()

func enter_idle() -> void:
	if not alive(): return
	# Repeated idle orders preserve the existing animation phase.
	if animation == &"idle" and is_playing(): return
	play(&"idle")
	frame = randi_range(0, sprite_frames.get_frame_count(&"idle") - 1)

func contact_box() -> Rect2:
	return Rect2(position + BODY_CENTER_FROM_FEET - CONTACT_SIZE * 0.5, CONTACT_SIZE)
