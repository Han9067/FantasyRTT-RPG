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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = GameUITheme.build()
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var style := GameUITheme.button_style(state,true)
		style.set_content_margin_all(12)
		add_theme_stylebox_override(state,style)
	show_pause_state(false)

func show_pause_state(paused: bool) -> void:
	set_pressed_no_signal(paused)
	tooltip_text = "전투 재개" if paused else "전투 일시정지"
