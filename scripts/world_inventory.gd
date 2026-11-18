extends ColorRect
## Screen-space inventory. Layout uses native pixels and scales down on small viewports.
var sheet := PanelContainer.new()
var slot_style := GameUITheme.paper_style(GameUITheme.IVORY, GameUITheme.BUTTON_BORDER, 5)
var section_style := GameUITheme.panel_style(10)
var slot_grid := GridContainer.new()

func setup(appearance: Dictionary) -> void:
	theme = GameUITheme.build()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	color = Color(0.12, 0.08, 0.04, 0.48)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sheet)
	sheet.add_theme_stylebox_override("panel", GameUITheme.panel_style(16))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	sheet.add_child(content)
	var header := Control.new()
	header.custom_minimum_size.y = 44
	content.add_child(header)
	var title := caption("인벤토리", 26)
	header.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var close := Button.new()
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	header.add_child(close)
	close.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	close.offset_left = -80
	close.pressed.connect(hide)
	content.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	content.add_child(columns)

	var people := VBoxContainer.new()
	section(columns, people)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(60, 60)
	card.add_theme_stylebox_override("panel", slot_style)
	people.add_child(card)
	var avatar := CharacterArt.compose(appearance)
	card.add_child(icon(avatar.get_region(avatar.get_used_rect())))

	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 10)
	columns.add_child(middle)
	var gear := GridContainer.new()
	gear.columns = 3
	section(middle, gear)
	var primary := CharacterArt.equipped_weapon(appearance)
	var secondary := CharacterArt.equipped_offhand(appearance)
	for label in ["무기1", "투구", "무기2", "장갑", "갑옷", "신발", "악세사리", "악세사리", "악세사리"]:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(78, 100)
		cell.add_theme_stylebox_override("panel", slot_style)
		gear.add_child(cell)
		var stack := VBoxContainer.new()
		cell.add_child(stack)
		stack.add_child(caption(label, 16))
		var item: Dictionary = {}
		if label == "무기1": item = primary
		if label == "무기2": item = secondary
		if not item.is_empty():
			var art := CharacterArt.part_image(item.sheet, item.slot)
			var image := icon(art.get_region(art.get_used_rect()))
			image.size_flags_vertical = Control.SIZE_EXPAND_FILL
			stack.add_child(image)
	var stats := VBoxContainer.new()
	section(middle, stats)
	stats.add_child(caption("능력치", 19))
	stats.add_child(HSeparator.new())
	for line in ["HP  %d" % BattleUnit.HERO_HP, "공격력  %d" % BattleUnit.HERO_DAMAGE,
			"명중률  %d%%" % roundi(BattleUnit.HERO_ACCURACY * 100)]:
		var stat := caption(line, 18)
		stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats.add_child(stat)

	slot_grid.columns = 8
	slot_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	section(columns, slot_grid)
	for index in range(64):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.add_theme_stylebox_override("panel", slot_style)
		slot_grid.add_child(slot)
	resized.connect(layout_sheet)
	hide()

func open() -> void:
	show()
	layout_sheet()

func layout_sheet() -> void:
	sheet.size = sheet.get_combined_minimum_size()
	var usable := (size - Vector2(16, 16)).max(Vector2.ONE)
	var factor := minf(1.0, minf(usable.x / sheet.size.x, usable.y / sheet.size.y))
	sheet.scale = Vector2.ONE * factor
	sheet.position = ((size - sheet.size * factor) * 0.5).round()

func caption(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label

func section(parent: Control, contents: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", section_style)
	parent.add_child(panel)
	panel.add_child(contents)

func icon(image: Image) -> TextureRect:
	var view := TextureRect.new()
	view.texture = ImageTexture.create_from_image(image)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return view
