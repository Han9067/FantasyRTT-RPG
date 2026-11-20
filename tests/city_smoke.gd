extends SceneTree
var game: Control

func _initialize() -> void:
	call_deferred("run")

func mouse(map: WorldMap, point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = true
	map._unhandled_input(event)

func walk_to_city(map: WorldMap) -> void:
	for i in range(3600):
		var before := map.unit_position
		map._physics_process(1.0/60.0)
		assert(map.navigation.segment_clear(before,map.unit_position), "City orders must follow walkable terrain")
		if not map.current_city.is_empty(): return
		assert(map.party_marker.visible and not map.city_panel.visible, "Do not enter before arrival")
	assert(false, "City order failed to arrive")

func run() -> void:
	root.size = Vector2i(1280,800)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.show_world()
	await process_frame
	var map: WorldMap = game.world
	map.set_physics_process(false)
	map.set_process(false)
	assert(not map.city_panel.visible and map.current_city.is_empty())
	for index in range(4):
		var action: Button = map.menu_bar.get_child(index)
		assert(action.text.is_empty() and action.icon != null)
		assert(action.accessibility_name == ["캐릭터", "인벤토리", "부대", "저널"][index])
		assert(action.size == Vector2(48, 48))
		assert(not map.can_interact_at(action.get_global_rect().get_center()))
		if index != 1:
			action.pressed.emit()
			assert(not map.inventory.visible)
	map.enter_city(map.cities[0])
	map.menu_bar.get_child(1).pressed.emit()
	await process_frame
	await process_frame
	assert(map.inventory.visible and map.inventory.slot_grid.columns == 8)
	assert(map.inventory.slot_grid.get_child_count() == 64)
	for slot in map.inventory.slot_grid.get_children(): assert(slot.size == Vector2(64, 64))
	assert(map.inventory.sheet.get_global_rect().get_center().distance_to(Vector2(640, 400)) < 1)
	assert(not map.can_interact_at(Vector2(640, 400)))
	for slot in map.inventory.slot_grid.get_children():
		assert(slot.item.is_empty() and slot.get_child(0).texture == null)
		slot.mouse_entered.emit()
		assert(not map.inventory.item_popup.visible)
		slot.mouse_exited.emit()
	# Exercise populated slots explicitly without giving the player test weapons.
	for id in ["bow/1", "crossbow_01"]:
		var item: Dictionary = CharacterArt.data().weapon_items[id]
		map.inventory.set_slot_item(0, item)
		var ranged_slot = map.inventory.slot_grid.get_child(0)
		var art := CharacterArt.part_image(item.sheet, item.slot)
		var diagonal := map.inventory.weapon_icon_image(art, PI / 4)
		assert(ranged_slot.get_child(0).texture.get_image().get_data() == diagonal.get_data())
		ranged_slot.mouse_entered.emit()
		assert(map.inventory.item_popup.visible and not map.inventory.item_title.text.is_empty())
		assert(map.inventory.get_global_rect().encloses(map.inventory.item_popup.get_global_rect()))
		ranged_slot.mouse_exited.emit()
		assert(not map.inventory.item_popup.visible)
	var view: TextureRect = map.inventory.slot_grid.get_child(0).get_child(0)
	for dimensions in [Vector2i(32, 32), Vector2i(32, 64), Vector2i(96, 48)]:
		var texture := ImageTexture.create_from_image(Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8))
		map.inventory.set_slot_texture(0, texture)
		assert(view.texture == texture and view.size == Vector2(64, 64))
		var mode := TextureRect.STRETCH_KEEP_ASPECT_CENTERED if dimensions.x > 64 else TextureRect.STRETCH_KEEP_CENTERED
		assert(view.stretch_mode == mode)
	# Check the bag path against the equipped icons, including a two-handed spear.
	var gear: GridContainer = map.inventory.sheet.find_children("*", "GridContainer", true, false)[0]
	for i in range(9):
		var cell := gear.get_child(i) as Panel
		assert(cell.size == Vector2(64, 64))
		if i == 0 or i == 2:
			var equipment := cell.get_child(0) as TextureRect
			var art := CharacterArt.equipped_weapon(map.character_appearance) if i == 0 else CharacterArt.equipped_offhand(map.character_appearance)
			cell.mouse_entered.emit()
			assert(map.inventory.item_popup.visible)
			assert(not map.inventory.quantity_text.visible and not map.inventory.quantity_rule.visible)
			assert(map.inventory.item_title.text == "%s%d" % [CharacterArt.TYPE_LABELS[art.family].replace(" ", ""), art.number])
			cell.mouse_exited.emit()
			map.inventory.set_slot_item(0, art)
			assert(view.texture == equipment.texture)
		else:
			var empty := cell.get_child(0) as Label
			assert(empty.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and empty.vertical_alignment == VERTICAL_ALIGNMENT_CENTER)
	map.inventory.set_slot_item(0, CharacterArt.data().weapon_items["two_spear/13"])
	assert(view.texture.get_width() <= 64 and view.texture.get_height() <= 64)
	map.inventory.set_slot_item(0, CharacterArt.data().weapon_items["one_sword/1"], 40)
	assert(map.inventory.slot_grid.get_child(0).quantity == 1 and map.inventory.slot_grid.get_child(0).count_text.text == "")
	var arrow := {"id": "arrow_01", "name": "화살", "family": "arrow", "sheet": CharacterArt.data().arrow, "slot": 0}
	map.inventory.set_slot_item(0, arrow, 40)
	var stack = map.inventory.slot_grid.get_child(0)
	stack.mouse_entered.emit()
	assert(stack.count_text.text == "40" and map.inventory.quantity_text.text == "수량 : 40")
	assert(map.inventory.item_title.text == "화살" and map.inventory.quantity_rule.visible)
	map.inventory.set_slot_item(0, {})
	assert(view.texture == null)
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	map._unhandled_input(cancel)
	assert(not map.inventory.visible and map.current_city == map.cities[0])
	map.exit_city()

	# The drawn frame has exactly three extra native pixels, not a scaled texture.
	var frame := GameUITheme.panel_style().texture.get_image()
	for y in range(5): assert(frame.get_pixel(16,y) == GameUITheme.BORDER)
	assert(frame.get_pixel(16,5) != GameUITheme.BORDER)
	for zoom in [1.0,3.0]:
		for city: Dictionary in map.cities:
			var center := Vector2(city.position[0],city.position[1])
			map.restore_travel(map.spawn_position,center,zoom)
			var point := map.world_to_screen(center)
			map.update_city_hover(point)
			map.update_world_cursor(point)
			assert(map.entrance_cursor_active and not map.blocked_cursor)
			assert(map.city_popup.visible)
			var motion := InputEventMouseMotion.new()
			motion.position = point
			map._unhandled_input(motion)
			assert(map.entrance_cursor_active and not map.attack_cursor_active, "World motion must preserve entrance hover; actual cursor is checked in Chromium")
			mouse(map,point)
			assert(map.pending_city.id == city.id and map.moving and map.party_marker.visible)
			assert(map.city_bounds(city).has_point(map.destination))
			walk_to_city(map)
			assert(map.current_city.id == city.id and not map.party_marker.visible and map.city_panel.visible)
			assert(not map.moving and map.pending_city.is_empty() and not map.city_popup.visible)
			assert(map.city_panel.size.x == 400 and map.city_panel.position == Vector2(18, game.world_overview.get_global_rect().end.y + 8))
			assert(map.city_panel_title.text == map.display_city_name(city))
			map.update_city_hover(point)
			map.update_world_cursor(point)
			assert(not map.city_popup.visible and not map.entrance_cursor_active)
	print("PASS: all four cities at 1x/3x, entrance cursor, walkable routes, arrival-only entry and 400px panel")
	await process_frame
	assert(map.city_actions.size() == 4)
	for action in map.city_actions:
		assert(action.size.x == 285, "City buttons must use 80% of the original 356px content width")
		assert(absf(action.get_global_rect().get_center().x - map.city_panel.get_global_rect().get_center().x) <= 0.5, "Centering may round by half a pixel for an odd button width")
	assert(map.city_actions[3].text == "나가기" and map.city_actions[3].position.y > map.city_actions[2].position.y)
	var original := map.unit_position
	var current := map.current_city
	for i in range(3):
		assert(map.city_actions[i].text == ["내성","길드","시장"][i])
		if i>0: assert(map.city_actions[i].position.y > map.city_actions[i-1].position.y)
		map.city_actions[i].pressed.emit()
		assert(map.current_city == current and map.unit_position == original and not map.party_marker.visible)
	assert(map.inventory.visible and map.inventory.market_city == current.id)
	var inv = map.inventory
	assert(inv.market_grid.columns == 8 and inv.market_grid.get_child_count() == 64)
	assert(not inv.people_section.visible and not inv.middle.visible)
	for i in current.products.size():
		var cell = inv.market_grid.get_child(i)
		assert(cell.item.id == current.products[i] and cell.quantity == map.economy.markets[current.id].stock[cell.item.id] and cell.count_text.text == str(cell.quantity))
	var first = inv.market_grid.get_child(0)
	var bag_slot = inv.slot_grid.get_child(0)
	var initial_stock: int = first.quantity
	var balance := 300
	var price := map.economy.quote(current.id, first.item.id, true, map.economy.skill())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	balance -= price
	first.gui_input.emit(click)
	balance -= map.economy.quote(current.id, first.item.id, true, map.economy.skill())
	first.gui_input.emit(click)
	assert(map.crowns == balance and first.quantity == initial_stock - 2 and bag_slot.quantity == 2)
	balance += map.economy.quote(current.id, bag_slot.item.id, false, map.economy.skill())
	bag_slot.gui_input.emit(click)
	assert(map.crowns == balance and first.quantity == initial_stock - 1 and bag_slot.quantity == 1)
	first.mouse_entered.emit()
	assert(inv.item_popup.visible and inv.item_title.text == first.item.name and inv.quantity_text.text == "수량 : %d" % (initial_stock - 1))
	assert(inv.quantity_rule.visible and inv.quantity_text.visible)
	map.crowns = 0
	first.gui_input.emit(click)
	assert(map.crowns == 0 and first.quantity == initial_stock - 1 and bag_slot.quantity == 1)
	map.crowns = balance
	map._unhandled_input(cancel)
	assert(not inv.visible and map.current_city.id == current.id)
	map.open_inventory()
	bag_slot.mouse_entered.emit()
	assert(inv.item_title.text == first.item.name and inv.quantity_text.visible and inv.middle.visible)
	inv.hide()
	map.city_actions[3].pressed.emit()
	assert(map.current_city.is_empty() and map.party_marker.visible and not map.city_panel.visible)
	assert(map.unit_position == original and not map.moving, "Exit button must restore the party without issuing travel")
	map.enter_city(current)
	mouse(map,Vector2(200,400),MOUSE_BUTTON_RIGHT)
	assert(map.current_city == current and map.unit_position == original, "Panel clicks cannot issue map orders")
	map.update_world_cursor(Vector2(200,400))
	assert(not map.entrance_cursor_active and not map.blocked_cursor)
	root.size = Vector2i(960,720)
	await process_frame
	await process_frame
	assert(map.city_panel.size.x == 400 and map.city_panel.get_global_rect().end.y == 702)
	for action in map.city_actions: assert(action.size.x == 285)
	# A battle round trip preserves the occupied city and hidden party.
	game.enter_battle_from_world()
	await process_frame
	game.show_world()
	await process_frame
	map = game.world
	map.set_process(false)
	map.set_physics_process(false)
	assert(map.current_city.id == current.id and map.city_panel.visible and not map.party_marker.visible)
	map.open_market()
	assert(map.inventory.market_grid.get_child(0).quantity == initial_stock - 1 and map.inventory.slot_grid.get_child(0).quantity == 1)
	assert(map.crowns == balance)
	map.inventory.hide()
	print("PASS: city stock, shared bag and tooltip quantities, purchase/sale prices, insufficient funds and battle continuity")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	map._unhandled_input(escape)
	assert(map.current_city.is_empty() and map.party_marker.visible and not map.city_panel.visible)
	print("PASS: 80%-width centered buttons, Exit button/Escape parity, placeholder button order/no effects, UI input isolation, panel resize, battle return and Escape exit")
	# A new valid travel order cancels entry; invalid terrain preserves the valid order.
	map.restore_travel(map.spawn_position,map.spawn_position,3)
	map.issue_city_entry(map.cities[1])
	var pending := map.pending_city
	var destination := map.destination
	map.issue_move(Vector2(1264,624)) # River.
	assert(map.pending_city == pending and map.destination == destination)
	var field := map.spawn_position+Vector2(80,0)
	map.issue_move(field)
	assert(map.pending_city.is_empty())
	for i in range(180): map._physics_process(1.0/60.0)
	assert(map.unit_position.is_equal_approx(field) and map.current_city.is_empty() and map.party_marker.visible)
	map.issue_city_entry(map.cities[1])
	walk_to_city(map)
	map.issue_move(field)
	assert(map.current_city.is_empty() and not map.city_panel.visible and map.party_marker.visible and map.moving)
	# A city already at the current position opens immediately; ordinary travel through it does not.
	map.restore_travel(map.city_entry_point(map.cities[1]),map.spawn_position,3)
	map.issue_city_entry(map.cities[1])
	assert(not map.current_city.is_empty() and not map.moving)
	map.update_world_cursor(Vector2(640,42),true)
	assert(not map.entrance_cursor_active)
	game.show_creation()
	await process_frame
	print("PASS: replacement/cancelled entry orders, no premature entry, immediate same-position entry and cursor cleanup")
	quit()
