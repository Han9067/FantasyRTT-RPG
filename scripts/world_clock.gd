extends HBoxContainer
## Campaign time advances only while the world map is active.
signal pause_changed(paused: bool)

const SECONDS_PER_DAY := 120.0
const SPEEDS := [0, 1, 2, 4]
const DATE_WIDTH := 172

var elapsed := 0.0
var speed := 1
var date_label := Label.new()
var time_panel := PanelContainer.new()
var time_label := Label.new()
var gauge := ProgressBar.new()
var speed_buttons: Array[Button] = []
var shown_hour := -1
var first_midnight := Time.get_unix_time_from_datetime_dict({"year":436, "month":3, "day":1})

func _ready() -> void:
	theme = GameUITheme.build()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_constant_override("separation", 8)
	var calendar := VBoxContainer.new()
	add_child(calendar)
	calendar.add_child(label_panel(date_label, DATE_WIDTH, 38))
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 4)
	calendar.add_child(controls)
	var group := ButtonGroup.new()
	for index in SPEEDS.size():
		var rate: int = SPEEDS[index]
		var action := Button.new()
		action.icon = speed_icon(index)
		action.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		action.custom_minimum_size = Vector2(40, 40)
		action.toggle_mode = true
		action.button_group = group
		action.focus_mode = Control.FOCUS_NONE
		action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		action.tooltip_text = "일시정지" if rate == 0 else "%d배속" % rate
		action.accessibility_name = action.tooltip_text
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var style := GameUITheme.button_style(state, true)
			style.set_content_margin_all(5)
			action.add_theme_stylebox_override(state, style)
		controls.add_child(action)
		speed_buttons.append(action)
		action.pressed.connect(set_speed.bind(rate))
	var day := VBoxContainer.new()
	add_child(day)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(172, 38)
	frame.add_theme_stylebox_override("panel", GameUITheme.panel_style(8))
	day.add_child(frame)
	gauge.show_percentage = false
	gauge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gauge.custom_minimum_size.y = 22
	gauge.step = 0
	gauge.max_value = SECONDS_PER_DAY
	for part in ["background", "fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("c4a777") if part == "background" else Color("896125")
		gauge.add_theme_stylebox_override(part, style)
	frame.add_child(gauge)
	time_panel.custom_minimum_size = Vector2(DATE_WIDTH, 40)
	time_panel.add_theme_stylebox_override("panel", GameUITheme.panel_style(6))
	day.add_child(time_panel)
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 0)
	time_panel.add_child(time_row)
	var time_title := Label.new()
	time_title.text = "현재 시간"
	time_row.add_child(time_title)
	var divider := ColorRect.new()
	divider.custom_minimum_size.x = 2
	divider.color = GameUITheme.BUTTON_BORDER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_row.add_child(divider)
	time_row.add_child(time_label)
	for label in [time_title, time_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_speed(speed)
	refresh_time()

func label_panel(label: Label, width: int, height: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, height)
	panel.add_theme_stylebox_override("panel", GameUITheme.panel_style(5))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel

func speed_icon(index: int) -> ImageTexture:
	var image := Image.create(24, 16, false, Image.FORMAT_RGBA8)
	if index == 0:
		image.fill_rect(Rect2i(6, 2, 4, 12), Color.WHITE)
		image.fill_rect(Rect2i(14, 2, 4, 12), Color.WHITE)
	else:
		var start := 12 - index * 4
		for arrow in index:
			for x in 7:
				image.fill_rect(Rect2i(start + arrow * 8 + x, 1 + x, 1, 13 - 2 * x), Color.WHITE)
	return ImageTexture.create_from_image(image)

func set_speed(rate: int) -> void:
	speed = rate
	speed_buttons[SPEEDS.find(rate)].set_pressed_no_signal(true)
	pause_changed.emit(rate == 0)

func advance(simulation_delta: float) -> void:
	elapsed += simulation_delta
	refresh_time()

func refresh_time() -> void:
	var hour := floori(elapsed * 24.0 / SECONDS_PER_DAY)
	gauge.value = fmod(elapsed, SECONDS_PER_DAY)
	if hour == shown_hour: return
	@warning_ignore("integer_division")
	var day := hour / 24
	@warning_ignore("integer_division")
	if shown_hour < 0 or day != shown_hour / 24:
		var date := Time.get_date_dict_from_unix_time(first_midnight + day * 86400)
		date_label.text = "%d년 %d월 %d일" % [date.year, date.month, date.day]
	shown_hour = hour
	var hour_24 := hour % 24
	time_label.text = "%d %s" % [(hour_24 + 11) % 12 + 1, "AM" if hour_24 < 12 else "PM"]
