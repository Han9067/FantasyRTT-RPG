extends Control
## Modal input surface shared by the slot actions and the quantity picker.
signal action_chosen
signal quantity_chosen(count: int)

var actions := PanelContainer.new()
var quantity_panel := PanelContainer.new()
var action_button := Button.new()
var confirm_button := Button.new()
var slider := HSlider.new()
var one_button := Button.new()
var max_button := Button.new()
var amount := Label.new()
var title := Label.new()
var anchor_point := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var choices := VBoxContainer.new()
	actions.custom_minimum_size.x = 120
	actions.add_theme_stylebox_override("panel", GameUITheme.panel_style(6))
	add_child(actions)
	actions.add_child(choices)
	choices.add_child(action_button)
	action_button.pressed.connect(func(): action_chosen.emit())
	add_cancel(choices)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	quantity_panel.add_theme_stylebox_override("panel", GameUITheme.panel_style(16))
	add_child(quantity_panel)
	quantity_panel.add_child(content)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	content.add_child(HSeparator.new())
	var slider_row := HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", 8)
	content.add_child(slider_row)
	one_button.text = "1"
	max_button.text = "최대"
	slider_row.add_child(one_button)
	slider_row.add_child(slider)
	slider_row.add_child(max_button)
	for button in [one_button, max_button]:
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var style := GameUITheme.button_style(state)
			style.content_margin_left = 8
			style.content_margin_right = 8
			button.add_theme_stylebox_override(state, style)
	one_button.custom_minimum_size = max_button.get_combined_minimum_size()
	one_button.pressed.connect(func(): slider.value = slider.min_value)
	max_button.pressed.connect(func(): slider.value = slider.max_value)
	slider.custom_minimum_size.x = 268
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = 1
	slider.step = 1
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(amount)
	slider.value_changed.connect(func(value): amount.text = str(int(value)))
	var buttons := HBoxContainer.new()
	var button_margin := MarginContainer.new()
	button_margin.add_theme_constant_override("margin_top", 5)
	content.add_child(button_margin)
	button_margin.add_child(buttons)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(confirm_button)
	confirm_button.pressed.connect(func(): quantity_chosen.emit(int(slider.value)))
	add_cancel(buttons)
	resized.connect(layout)
	hide()

func add_cancel(parent: Container) -> void:
	var cancel := Button.new()
	cancel.text = "취소"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(cancel)
	cancel.pressed.connect(hide)

func show_actions(at: Vector2, verb: String) -> void:
	anchor_point = at
	action_button.text = verb
	confirm_button.text = verb
	quantity_panel.hide()
	actions.show()
	show()
	layout()

func show_quantity(item_name: String, maximum: int) -> void:
	title.text = item_name + " " + confirm_button.text
	slider.max_value = maximum
	slider.value = 1
	amount.text = "1"
	actions.hide()
	quantity_panel.show()
	layout()
	slider.grab_focus()

func layout() -> void:
	if not visible: return
	var panel := actions if actions.visible else quantity_panel
	panel.reset_size()
	var factor := minf(1.0, minf(size.x / panel.size.x, size.y / panel.size.y))
	panel.scale = Vector2.ONE * factor
	var limit := (size - panel.size * factor).max(Vector2.ZERO)
	panel.position = anchor_point.clamp(Vector2.ZERO, limit) if actions.visible else (limit * 0.5).round()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		hide()
