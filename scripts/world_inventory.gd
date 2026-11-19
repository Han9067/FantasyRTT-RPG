extends ColorRect
## Screen-space inventory. Layout uses native pixels and scales down on small viewports.
class ItemIcon extends TextureRect:
	func _ready() -> void:
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(update_fit)
		update_fit()

	func update_fit() -> void:
		if texture != null and (texture.get_width() > size.x or texture.get_height() > size.y):
			stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		else:
			stretch_mode = TextureRect.STRETCH_KEEP_CENTERED

class ItemSlot extends Panel:
	var item: Dictionary = {}

const INITIAL_FAMILIES := ["one_axe", "one_blunt", "two_sword", "two_axe", "two_blunt",
	"two_spear", "two_polearm", "bow", "crossbow"]
const EQUIPMENT_SIZE := Vector2(64, 64)
const WEAPON_ICON_SCALE := 1.4
var item_textures: Dictionary = {}
var sheet := PanelContainer.new()
var slot_style := GameUITheme.paper_style(GameUITheme.IVORY, GameUITheme.BUTTON_BORDER, 5)
var section_style := GameUITheme.panel_style(10)
var slot_grid := GridContainer.new()
var item_popup := PanelContainer.new()
var item_title := Label.new()
var hovered_slot: ItemSlot

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
	var avatar := CharacterArt.compose(appearance, "idle", 0, false)
	var head := CharacterArt.part_image(CharacterArt.human_data().heads[appearance.skin], appearance.face)
	var face_center := CharacterArt.BODY_ORIGIN + head.get_used_rect().get_center()
	face_center.y += CharacterArt.pose("idle", 0).bob
	var closeup := Rect2i(face_center - Vector2i(12, 12), Vector2i(25, 25))
	card.add_child(portrait_icon(avatar.get_region(closeup)))

	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 10)
	columns.add_child(middle)
	var gear := GridContainer.new()
	gear.columns = 3
	section(middle, gear)
	var primary := CharacterArt.equipped_weapon(appearance)
	var secondary := CharacterArt.equipped_offhand(appearance)
	for label in ["무기1", "투구", "무기2", "장갑", "갑옷", "신발", "악세사리", "악세사리", "악세사리"]:
		var cell := add_item_slot(gear)
		var item: Dictionary = {}
		if label == "무기1": item = primary
		if label == "무기2": item = secondary
		cell.item = item
		var contents: Control
		if item.is_empty():
			var empty_label := caption(label, 15)
			empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			contents = empty_label
		else:
			var image := ItemIcon.new()
			image.texture = inventory_item_texture(item)
			contents = image
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(contents)
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		var slot := add_item_slot(slot_grid)
		var item_icon := ItemIcon.new()
		slot.add_child(item_icon)
		item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in INITIAL_FAMILIES.size():
		var id: String = CharacterArt.primary_items(INITIAL_FAMILIES[index])[0]
		set_slot_item(index, CharacterArt.data().weapon_items[id])
	build_item_popup()
	visibility_changed.connect(clear_hover)
	resized.connect(layout_sheet)
	hide()

func add_item_slot(grid: GridContainer) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.custom_minimum_size = EQUIPMENT_SIZE
	slot.add_theme_stylebox_override("panel", slot_style)
	grid.add_child(slot)
	slot.mouse_entered.connect(func():
		hovered_slot = slot
		update_item_popup())
	slot.mouse_exited.connect(func():
		if hovered_slot == slot: clear_hover())
	return slot

func build_item_popup() -> void:
	item_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_popup.custom_minimum_size = Vector2(240, 112)
	item_popup.add_theme_stylebox_override("panel", GameUITheme.panel_style(14))
	add_child(item_popup)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 10)
	item_popup.add_child(content)
	item_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(item_title)
	var divider := HSeparator.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := StyleBoxLine.new()
	line.color = GameUITheme.BUTTON_BORDER
	line.thickness = 1
	divider.add_theme_stylebox_override("separator", line)
	content.add_child(divider)
	item_popup.hide()

func clear_hover() -> void:
	hovered_slot = null
	item_popup.hide()

func update_item_popup() -> void:
	if hovered_slot == null or hovered_slot.item.is_empty() or not is_visible_in_tree():
		item_popup.hide()
		return
	var item := hovered_slot.item
	var type_name: String = CharacterArt.TYPE_LABELS[item.family]
	item_title.text = "%s%d" % [type_name.replace(" ", ""), int(item.number)]
	item_popup.size = item_popup.get_combined_minimum_size()
	item_popup.scale = sheet.scale
	var bounds := hovered_slot.get_global_rect()
	var extent := item_popup.size * item_popup.scale
	var area := get_global_rect()
	var pos := bounds.end + Vector2(6, 6)
	if pos.x + extent.x > area.end.x - 6: pos.x = bounds.position.x - extent.x - 6
	if pos.y + extent.y > area.end.y - 6: pos.y = bounds.position.y - extent.y - 6
	item_popup.global_position = pos.clamp(area.position, (area.end - extent).max(area.position))
	item_popup.show()

# The bag and equipment slots share the same catalog art. Cache only visited items.
func set_slot_item(index: int, item: Dictionary) -> void:
	set_slot_texture(index, null if item.is_empty() else inventory_item_texture(item), item)

func inventory_item_texture(item: Dictionary) -> Texture2D:
	if item_textures.has(item.id): return item_textures[item.id]
	var art := CharacterArt.part_image(item.sheet, item.slot)
	var shield: bool = item.family == "one_shield"
	if shield or CharacterArt.is_primary_melee(item.family):
		art = weapon_icon_image(art, 0.0 if shield else PI / 4.0)
	var texture := ImageTexture.create_from_image(art)
	item_textures[item.id] = texture
	return texture

func weapon_icon_image(source: Image, angle: float) -> Image:
	# Sample at pixel centers onto a padded canvas, then center the visible artwork in the slot.
	var side := ceili(Vector2(source.get_size()).length() * WEAPON_ICON_SCALE) + 2
	var canvas := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var inverse_basis := Transform2D(-angle, Vector2.ZERO)
	var center := Vector2(source.get_size()) * 0.5
	var origin := Vector2.ONE * (0.5 - side * 0.5)
	var bounds := Rect2i(Vector2i.ZERO, source.get_size())
	for y in range(side):
		for x in range(side):
			var point := center + inverse_basis * (Vector2(x, y) + origin) / WEAPON_ICON_SCALE
			var pixel := Vector2i(point.floor())
			if bounds.has_point(pixel):
				canvas.set_pixel(x, y, source.get_pixelv(pixel))
	return canvas.get_region(canvas.get_used_rect())

func set_slot_texture(index: int, texture: Texture2D, item: Dictionary = {}) -> void:
	if index < 0 or index >= slot_grid.get_child_count(): return
	var slot: ItemSlot = slot_grid.get_child(index)
	slot.item = item
	var view: ItemIcon = slot.get_child(0)
	view.texture = texture
	view.update_fit()
	if slot == hovered_slot: update_item_popup()

func open() -> void:
	show()
	layout_sheet()

func layout_sheet() -> void:
	sheet.size = sheet.get_combined_minimum_size()
	var usable := (size - Vector2(16, 16)).max(Vector2.ONE)
	var factor := minf(1.0, minf(usable.x / sheet.size.x, usable.y / sheet.size.y))
	sheet.scale = Vector2.ONE * factor
	sheet.position = ((size - sheet.size * factor) * 0.5).round()
	if hovered_slot != null: update_item_popup()

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

func portrait_icon(image: Image) -> TextureRect:
	var view := TextureRect.new()
	view.texture = ImageTexture.create_from_image(image)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return view
