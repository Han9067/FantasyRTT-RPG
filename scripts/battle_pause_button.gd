extends Button
## A tactical pause toggle; the yellow outline is visible only while paused.

func _init() -> void:
	name = "PauseButton"
	icon = preload("res://assets/ui/pause.svg")
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(48, 48)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	accessibility_name = "전투 일시정지"
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var active: bool = state in ["pressed", "hover_pressed"]
		var style := StyleBoxFlat.new()
		style.bg_color = Color("414d46") if state.begins_with("hover") else Color("333d3a")
		style.border_color = Color("ffd54a") if active else Color("756b50")
		style.set_border_width_all(3 if active else 2)
		style.set_content_margin_all(12)
		if active:
			style.shadow_color = Color(1.0, 0.78, 0.16, 0.3)
			style.shadow_size = 4
		add_theme_stylebox_override(state, style)
	show_pause_state(false)

func show_pause_state(paused: bool) -> void:
	set_pressed_no_signal(paused)
	tooltip_text = "전투 재개" if paused else "전투 일시정지"
