extends ColorRect
## Screen-space inventory. Layout uses native pixels and scales down on small viewports.
signal trade_requested(slot: ItemSlot)

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
	var quantity := 0
	var count_text: Label

const EQUIPMENT_SIZE := Vector2(64, 64)
const WEAPON_ICON_SCALE := 1.4
var item_textures: Dictionary = {}
const GOODS_ART := preload("res://assets/world/trade_icons.png")
const GRID_SIDE := 8
const Economy = preload("res://scripts/campaign_economy.gd")

var goods_by_id: Dictionary = {}
var economy: Economy
var market_city := ""
var market_grid := GridContainer.new()
var market_section: PanelContainer
var people_section: PanelContainer
var middle := VBoxContainer.new()
var window_title := Label.new()
var bag_title := Label.new()
var trade_hint := Label.new()
var quantity_text := Label.new()
var quantity_rule := HSeparator.new()
var sheet := PanelContainer.new()
var slot_style := GameUITheme.paper_style(GameUITheme.IVORY, GameUITheme.BUTTON_BORDER, 5)
var section_style := GameUITheme.panel_style(10)
var slot_grid := GridContainer.new()
var item_popup := PanelContainer.new()
var item_title := Label.new()
var hovered_slot: ItemSlot

func setup(appearance: Dictionary, hero_hp := BattleUnit.HERO_HP) -> void:
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
	window_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	window_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	window_title.add_theme_font_size_override("font_size", 26)
	header.add_child(window_title)
	window_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	people_section = section(columns, people)
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
		cell.quantity = 0 if item.is_empty() else 1
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
	for line in ["HP  %d" % hero_hp, "공격력  %d" % BattleUnit.HERO_DAMAGE,
			"명중률  %d%%" % roundi(BattleUnit.HERO_ACCURACY * 100)]:
		var stat := caption(line, 18)
		stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats.add_child(stat)

	var stock := VBoxContainer.new()
	market_section = section(columns, stock)
	stock.add_child(caption("시장 재고", 18))
	build_grid(stock, market_grid)
	var bag := VBoxContainer.new()
	section(columns, bag)
	bag_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bag.add_child(bag_title)
	build_grid(bag, slot_grid)
	trade_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(trade_hint)
	set_market_mode("")
	build_item_popup()
	visibility_changed.connect(clear_hover)
	resized.connect(layout_sheet)
	hide()

func build_grid(parent: Control, grid: GridContainer) -> void:
	grid.columns = GRID_SIDE
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(grid)
	for index in GRID_SIDE * GRID_SIDE:
		var slot := add_item_slot(grid)
		var icon := ItemIcon.new()
		slot.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.count_text = caption("", 16)
		slot.count_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.count_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slot.count_text.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		slot.count_text.add_theme_color_override("font_color", GameUITheme.IVORY)
		slot.count_text.add_theme_color_override("font_outline_color", GameUITheme.INK)
		slot.count_text.add_theme_constant_override("outline_size", 4)
		slot.add_child(slot.count_text)
		slot.count_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.count_text.offset_right = -6
		slot.count_text.offset_bottom = -4
		slot.gui_input.connect(func(event: InputEvent):
			if not market_city.is_empty() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not slot.item.is_empty():
				slot.accept_event()
				trade_requested.emit(slot))

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
	var space := Control.new()
	space.custom_minimum_size.y = 30
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(space)
	quantity_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity_rule.add_theme_stylebox_override("separator", line)
	content.add_child(quantity_rule)
	quantity_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(quantity_text)
	item_popup.hide()

func clear_hover() -> void:
	hovered_slot = null
	item_popup.hide()

func update_item_popup() -> void:
	if hovered_slot == null or hovered_slot.item.is_empty() or not is_visible_in_tree():
		item_popup.hide()
		return
	var item := hovered_slot.item
	if item.has("name"):
		item_title.text = item.name
	else:
		var type_name: String = CharacterArt.TYPE_LABELS.get(item.get("family", ""), "장비")
		item_title.text = "%s%d" % [type_name.replace(" ", ""), int(item.get("number", 1))]
	quantity_text.visible = is_stackable(item)
	quantity_rule.visible = quantity_text.visible
	quantity_text.text = "수량 : %d" % hovered_slot.quantity
	if not market_city.is_empty() and item.has("price"):
		trade_hint.text = "%s · 기본 %d · 구매 %d / 판매 %d 크라운" % [
			item_title.text, int(item.price), economy.quote(market_city, item.id, true, economy.skill()),
			economy.quote(market_city, item.id, false, economy.skill())]
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
static func is_stackable(item: Dictionary) -> bool:
	if item.is_empty(): return false
	if item.get("family", "") == "arrow": return true
	return item.has("image") or item.get("stackable", false)

func set_slot_item(index: int, item: Dictionary, count := 1) -> void:
	if index < 0 or index >= slot_grid.get_child_count(): return
	fill_slot(slot_grid.get_child(index), item, count)

func fill_slot(slot: ItemSlot, item: Dictionary, count: int) -> void:
	var occupied := not item.is_empty() and count > 0
	var texture: Texture2D = inventory_item_texture(item) if occupied else null
	write_slot(slot, texture, item if occupied else {}, count)

func inventory_item_texture(item: Dictionary) -> Texture2D:
	if item_textures.has(item.id): return item_textures[item.id]
	if item.has("image"):
		var atlas := AtlasTexture.new()
		atlas.atlas = GOODS_ART
		var index := int(item.slot)
		atlas.region = Rect2((index % 8) * 32, floori(index / 8.0) * 32, 32, 32)
		item_textures[item.id] = atlas
		return atlas
	var art := CharacterArt.part_image(item.sheet, item.slot)
	var shield: bool = item.family == "one_shield"
	if shield or CharacterArt.is_primary_melee(item.family) or item.family in ["bow", "crossbow"]:
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
	write_slot(slot_grid.get_child(index), texture, item, 1)

func write_slot(slot: ItemSlot, texture: Texture2D, item: Dictionary, count: int) -> void:
	slot.item = item
	if item.is_empty():
		slot.quantity = 0
	elif is_stackable(item):
		slot.quantity = count
	else:
		slot.quantity = 1
	slot.count_text.text = str(slot.quantity) if is_stackable(item) else ""
	var view: ItemIcon = slot.get_child(0)
	view.texture = texture
	view.update_fit()
	if slot == hovered_slot: update_item_popup()

func set_market_mode(city_id: String) -> void:
	market_city = city_id
	var trading := not city_id.is_empty()
	market_section.visible = trading
	bag_title.visible = trading
	trade_hint.visible = trading
	people_section.visible = not trading
	middle.visible = not trading
	clear_hover()

func open() -> void:
	set_market_mode("")
	window_title.text = "인벤토리"
	show()
	layout_sheet()

func open_market(city: Dictionary, crowns: int) -> void:
	set_market_mode(city.id)
	trade_hint.text = "아이템을 클릭하면 1개씩 거래합니다"
	update_balance(crowns)
	refresh_market()
	show()
	layout_sheet()

func refresh_market() -> void:
	var market: Dictionary = economy.markets[market_city]
	window_title.text = "%s 시장 · %s" % [market.name, Economy.CONDITION_NAMES[market.condition]]
	for i in market_grid.get_child_count():
		var cell: ItemSlot = market_grid.get_child(i)
		var id := int(market.order[i]) if i < market.order.size() else -1
		var count := int(market.stock.get(id, 0))
		if cell.quantity != count or (count > 0 and cell.item.get("id") != id):
			fill_slot(cell, goods_by_id.get(id, {}), count)
	if hovered_slot != null: update_item_popup()

func update_balance(crowns: int) -> void:
	bag_title.text = "소지품 · %d 크라운 · 교역 Lv.%d" % [crowns, economy.skill()]

func snapshot(grid: GridContainer) -> Dictionary:
	var entries := {}
	for cell: ItemSlot in grid.get_children():
		if not cell.item.is_empty():
			entries[cell.get_index()] = {"item": cell.item, "count": cell.quantity}
	return entries

func restore_slots(grid: GridContainer, entries: Dictionary) -> void:
	for cell: ItemSlot in grid.get_children():
		var entry: Dictionary = entries.get(cell.get_index(), {})
		if entry.is_empty():
			fill_slot(cell, {}, 0)
		else:
			fill_slot(cell, entry.item, int(entry.count))

func trade_one(source: ItemSlot, crowns: int) -> int:
	if not is_visible_in_tree() or market_city.is_empty() or source.item.is_empty(): return 0
	var buying := source.get_parent() == market_grid
	var item := source.item
	if not goods_by_id.has(item.id):
		trade_hint.text = "이 품목은 거래할 수 없습니다"
		return 0
	var price := economy.quote(market_city, item.id, buying, economy.skill())
	if buying:
		if crowns < price:
			trade_hint.text = "크라운이 부족합니다"
			return 0
		if economy.markets[market_city].stock[item.id] <= 0: return 0
		var destination: ItemSlot
		for cell: ItemSlot in slot_grid.get_children():
			if cell.item.get("id") == item.id:
				destination = cell
				break
			if destination == null and cell.item.is_empty(): destination = cell
		if destination == null:
			trade_hint.text = "빈 슬롯이 없습니다"
			return 0
		fill_slot(destination, item, destination.quantity + 1)
	else:
		fill_slot(source, item, source.quantity - 1)
	economy.change_stock(market_city, item.id, -1 if buying else 1)
	economy.trade_experience += 1
	refresh_market()
	var change := -price if buying else price
	update_balance(crowns + change)
	if hovered_slot == null or hovered_slot.item.is_empty():
		trade_hint.text = "%s 1개 %s · %d 크라운" % [item.name, "구매" if buying else "판매", price]
	return change

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

func section(parent: Control, contents: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", section_style)
	parent.add_child(panel)
	panel.add_child(contents)
	return panel

func portrait_icon(image: Image) -> TextureRect:
	var view := TextureRect.new()
	view.texture = ImageTexture.create_from_image(image)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return view
