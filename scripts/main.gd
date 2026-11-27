extends Control

var game_version: String = ProjectSettings.get_setting("application/config/version", "0.0.92")
const PresetStore = preload("res://scripts/character_presets.gd")
const CharacterArt = preload("res://scripts/character_art.gd")

const GOLD = GameUITheme.MUTED
const INK = GameUITheme.INK
const BattleMapScene = preload("res://scripts/battle_map.gd")
const WorldMapScene = preload("res://scripts/world_map.gd")
var character_frames: SpriteFrames
var appearance: Dictionary = CharacterArt.defaults()
var part_controls: Dictionary = {}
var parts_columns: Array[VBoxContainer] = []
var top_panel: PanelContainer
var bottom_panel: PanelContainer
var last_preview_frame := -1
var preview_animation := "idle"
var animation_time := 0.0
var current_screen := ""
var battle: BattleMap
var battle_hud: CanvasLayer
var world: WorldMap
var world_overview: Control
var battle_button: Button
var travel_state: Dictionary = {}
var screen: VBoxContainer
var selected_gender: int:
	get: return appearance.gender
var player_name := ""
var player_age := 20
var portrait: TextureRect
var genders: Array[Button] = []
var age_label: Label
var name_input: LineEdit
var age_slider: HSlider
var create_button: Button
var paper_background: StyleBoxTexture
var preset_store = PresetStore.new()
var preset_save_button: Button
var preset_buttons: Array[Button] = []
var preset_popup: PopupPanel
var preset_choices: Array[Button] = []
var preset_message: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = GameUITheme.build()
	paper_background = GameUITheme.panel_style(0)
	character_frames = CharacterArt.animations(appearance)
	show_menu()

func _draw() -> void:
	if current_screen in ["battle", "world"]: return
	paper_background.draw(get_canvas_item(),Rect2(Vector2.ZERO,size))
	# Quiet silhouettes of a fortified city, drawn on an integer pixel grid.
	var base := size.y * 0.80
	for i in range(24):
		var x := float(i) * size.x / 23.0
		var h := float(40 + (i * 37 % 110))
		draw_rect(Rect2(x, base - h, 48, size.y), Color("d7bd8d"))
		if i % 3 == 0:
			for j in range(3):
				draw_rect(Rect2(x + j * 18, base - h - 10, 10, 12), Color("d7bd8d"))
	draw_line(Vector2(0, size.y - 30), Vector2(size.x, size.y - 30), GameUITheme.BUTTON_BORDER, 2)

func label_text(value: String, font_size := 18) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	return l

func button(value: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = value
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	return b

func _process(delta: float) -> void:
	animation_time += delta
	if current_screen == "creation" and is_instance_valid(portrait):
		var index := CharacterArt.frame_at_time(character_frames, preview_animation, animation_time)
		if index != last_preview_frame:
			portrait.texture = CharacterArt.preview_texture(character_frames.get_frame_texture(preview_animation, index))
			last_preview_frame = index

func clear_screen() -> void:
	queue_redraw()
	if is_instance_valid(preset_popup):
		preset_popup.hide()
		remove_child(preset_popup)
		preset_popup.queue_free()
		preset_popup = null
	preset_buttons.clear()
	preset_choices.clear()
	if is_instance_valid(battle):
		battle.set_process_unhandled_input(false)
		battle.set_physics_process(false)
		remove_child(battle)
		battle.queue_free()
		battle = null
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if is_instance_valid(world):
		world.set_process_unhandled_input(false)
		world.set_physics_process(false)
		remove_child(world)
		world.queue_free()
		world = null
	if is_instance_valid(screen):
		screen.get_parent().remove_child(screen)
		screen.queue_free()
	if is_instance_valid(battle_hud):
		remove_child(battle_hud)
		battle_hud.queue_free()
		battle_hud = null
	screen = VBoxContainer.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.offset_left = 60
	screen.offset_right = -60
	screen.offset_top = 28
	screen.offset_bottom = -28
	screen.add_theme_constant_override("separation", 14)
	add_child(screen)

func spacer(parent: Control) -> void:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(c)

func show_menu() -> void:
	clear_screen()
	current_screen = "menu"
	spacer(screen)
	var overline := label_text("F A N T A S Y R T T  ·  R P G", 16)
	overline.add_theme_color_override("font_color",GOLD)
	overline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(overline)
	var title := label_text("중세 전략 RPG", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(title)
	var subtitle := label_text("무너진 제국, 당신의 깃발 아래 다시 하나로.", 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(subtitle)
	var center := CenterContainer.new()
	screen.add_child(center)
	var menu := VBoxContainer.new()
	menu.custom_minimum_size.x = 320
	menu.add_theme_constant_override("separation", 12)
	center.add_child(menu)
	menu.add_child(button("새 게임", show_creation))
	menu.add_child(button("게임 종료", func(): get_tree().quit()))
	spacer(screen)
	var footer := label_text("버전 : " + game_version, 14)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color",GOLD)
	screen.add_child(footer)

func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel",GameUITheme.panel_style())
	return p

func show_creation() -> void:
	if current_screen == "menu":
		var defaults := CharacterArt.defaults()
		if appearance.body != defaults.body or appearance.hair != defaults.hair:
			appearance.body = defaults.body
			appearance.hair = defaults.hair
			character_frames = CharacterArt.animations(appearance)
	clear_screen()
	current_screen = "creation"
	screen.add_theme_constant_override("separation", 10)
	preview_animation = "idle"
	animation_time = 0.0
	last_preview_frame = -1
	genders.clear()
	part_controls.clear()
	parts_columns.clear()
	var header := HBoxContainer.new()
	screen.add_child(header)
	var heading := label_text("새로운 인물", 30)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(button("← 메인 메뉴", show_menu))

	top_panel = panel()
	top_panel.name = "PersonalDetails"
	screen.add_child(top_panel)
	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 10)
	top_panel.add_child(fields)
	var details_header := HBoxContainer.new()
	details_header.add_theme_constant_override("separation", 8)
	fields.add_child(details_header)
	var details_title := label_text("인물 정보", 20)
	details_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_header.add_child(details_title)
	preset_save_button = button("저장", open_preset_popup)
	preset_save_button.custom_minimum_size = Vector2(64, 36)
	details_header.add_child(preset_save_button)
	for i in range(PresetStore.SLOT_COUNT):
		var slot := button("%d번" % (i + 1), apply_preset.bind(i))
		slot.custom_minimum_size = Vector2(64, 36)
		details_header.add_child(slot)
		preset_buttons.append(slot)
	create_preset_popup()
	refresh_preset_buttons()
	var inputs := HBoxContainer.new()
	inputs.add_theme_constant_override("separation", 18)
	fields.add_child(inputs)
	inputs.add_child(label_text("이름", 16))
	name_input = LineEdit.new()
	name_input.placeholder_text = "이름을 입력하세요"
	name_input.text = player_name
	name_input.max_length = 24
	name_input.custom_minimum_size.y = 44
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.text_changed.connect(func(value: String): player_name = value)
	inputs.add_child(name_input)
	inputs.add_child(label_text("성별", 16))
	var selected_style := GameUITheme.button_style("normal")
	selected_style.texture = GameUITheme.paper_texture(GameUITheme.PAUSE, GameUITheme.BUTTON_BORDER)
	for i in range(2):
		var b := button(["남", "여"][i], select_gender.bind(i))
		b.toggle_mode = true
		b.add_theme_stylebox_override("hover", GameUITheme.build().get_stylebox("normal", "Button"))
		for state in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, selected_style)
		inputs.add_child(b)
		genders.append(b)
	var ages := HBoxContainer.new()
	ages.add_theme_constant_override("separation", 16)
	fields.add_child(ages)
	age_label = label_text("나이  ·  %d세" % player_age, 16)
	age_label.custom_minimum_size.x = 112
	ages.add_child(age_label)
	ages.add_child(label_text("16세", 14))
	age_slider = HSlider.new()
	age_slider.min_value = 16
	age_slider.max_value = 40
	age_slider.step = 1
	age_slider.value = player_age
	age_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	age_slider.custom_minimum_size.y = 28
	age_slider.value_changed.connect(func(value: float):
		player_age = int(value)
		age_label.text = "나이  ·  %d세" % player_age)
	ages.add_child(age_slider)
	ages.add_child(label_text("40세", 14))

	bottom_panel = panel()
	bottom_panel.name = "AppearanceEditor"
	bottom_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_panel.custom_minimum_size.y = 320
	screen.add_child(bottom_panel)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	bottom_panel.add_child(content)
	var preview_column := VBoxContainer.new()
	preview_column.custom_minimum_size.x = 330
	preview_column.add_theme_constant_override("separation", 10)
	content.add_child(preview_column)
	var frame := panel()
	frame.name = "PortraitFrame"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(330, 210)
	preview_column.add_child(frame)
	var preview_center := CenterContainer.new()
	frame.add_child(preview_center)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(CharacterArt.PREVIEW_REGION.size) * CharacterArt.PREVIEW_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_center.add_child(portrait)
	var previews := HBoxContainer.new()
	previews.add_theme_constant_override("separation", 6)
	preview_column.add_child(previews)
	for entry in [["idle", "대기"], ["walk", "걷기"], ["attack", "공격"]]:
		var b := button(entry[1], set_preview_animation.bind(entry[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		previews.add_child(b)
	var columns := HBoxContainer.new()
	columns.name = "PartColumns"
	columns.add_theme_constant_override("separation", 20)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(columns)
	for i in range(2):
		var rows := VBoxContainer.new()
		rows.name = "BodyParts" if i == 0 else "Weapons"
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.size_flags_stretch_ratio = 1.0
		rows.add_theme_constant_override("separation", 6)
		columns.add_child(rows)
		parts_columns.append(rows)
	for entry in CharacterArt.PARTS:
		var key: String = entry[0]
		var row := HBoxContainer.new()
		row.name = key
		row.add_theme_constant_override("separation", 6)
		var right_column := key in ["weapon", "weapon_item", "offhand", "offhand_item"]
		parts_columns[1 if right_column else 0].add_child(row)
		var title := label_text(entry[1], 18)
		title.custom_minimum_size.x = 88
		row.add_child(title)
		var left := part_button("◀", change_part.bind(key, -1))
		left.accessibility_name = entry[1] + " 이전"
		row.add_child(left)
		var number := label_text("", 19)
		number.custom_minimum_size.x = 104 if right_column else 64
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(number)
		var right := part_button("▶", change_part.bind(key, 1))
		right.accessibility_name = entry[1] + " 다음"
		row.add_child(right)
		part_controls[key] = {"left": left, "right": right, "number": number, "title": title}
	create_button = button("캐릭터 생성", start_journey)
	create_button.custom_minimum_size.y = 50
	screen.add_child(create_button)
	select_gender(selected_gender)
	refresh_part_controls()
	_process(0.0)

func create_preset_popup() -> void:
	preset_popup = PopupPanel.new()
	preset_popup.name = "PresetSavePopup"
	preset_popup.theme = theme
	preset_popup.unresizable = true
	preset_popup.close_requested.connect(preset_popup.hide)
	add_child(preset_popup)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	preset_popup.add_child(content)
	preset_message = label_text("저장할 슬롯 선택", 20)
	preset_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(preset_message)
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 12)
	content.add_child(choices)
	for i in range(PresetStore.SLOT_COUNT):
		var choice := button(str(i + 1), save_preset.bind(i))
		choice.custom_minimum_size = Vector2(64, 64)
		choices.add_child(choice)
		preset_choices.append(choice)
	var hint := label_text("기존 프리셋은 덮어씁니다.", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)

func refresh_preset_buttons() -> void:
	for i in range(preset_buttons.size()):
		var empty: bool = preset_store.get_appearance(i).is_empty()
		preset_buttons[i].disabled = empty
		preset_buttons[i].tooltip_text = "빈 슬롯" if empty else "%d번 외형 불러오기" % (i + 1)

func open_preset_popup() -> void:
	preset_message.text = "저장할 슬롯 선택"
	preset_popup.popup_centered()
	preset_choices[0].grab_focus()

func save_preset(slot: int) -> void:
	if preset_store.save_appearance(slot, appearance) != OK:
		preset_message.text = "저장하지 못했습니다. 다시 시도해 주세요."
		return
	refresh_preset_buttons()
	preset_popup.hide()
	preset_buttons[slot].grab_focus()

func apply_preset(slot: int) -> void:
	var saved: Dictionary = preset_store.get_appearance(slot)
	if saved.is_empty(): return
	saved.gender = selected_gender
	# Old presets can contain a crossbow. Substitute the final visible ranged option on load.
	if CharacterArt.data().primary_types[saved.weapon] == "crossbow":
		saved.weapon = CharacterArt.data().primary_types.find("bow")
		saved.weapon_item = 0
	CharacterArt.normalize(saved)
	appearance = saved
	character_frames = CharacterArt.animations(appearance)
	refresh_part_controls()
	set_preview_animation(preview_animation)

func part_button(value: String, callback: Callable) -> Button:
	var result := button(value, callback)
	result.add_theme_font_size_override("font_size", 20)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var style := theme.get_stylebox(state, "Button").duplicate() as StyleBox
		style.content_margin_left = 8
		style.content_margin_right = 8
		result.add_theme_stylebox_override(state, style)
	return result

func set_preview_animation(value: String) -> void:
	preview_animation = value
	animation_time = 0.0
	last_preview_frame = -1
	_process(0.0)

func select_gender(value: int) -> void:
	if selected_gender != value:
		appearance.gender = value
		CharacterArt.normalize(appearance)
		refresh_part_controls()
		character_frames = CharacterArt.animations(appearance)
		set_preview_animation(preview_animation)
	for i in range(genders.size()):
		genders[i].button_pressed = i == value

func change_part(key: String, direction: int) -> void:
	var order := CharacterArt.selection_order(appearance, key)
	var total := order.size()
	if total <= 1: return
	appearance[key] = order[posmod(order.find(int(appearance[key])) + direction, total)]
	if key == "weapon":
		appearance.erase("equipped_weapon")
		appearance.weapon_item = 0
	elif key == "offhand":
		appearance.offhand_item = 0
	CharacterArt.normalize(appearance)
	character_frames = CharacterArt.animations(appearance)
	last_preview_frame = -1
	refresh_part_controls()
	_process(0.0)

func refresh_part_controls() -> void:
	for entry in CharacterArt.PARTS:
		var key: String = entry[0]
		var total := CharacterArt.selection_order(appearance, key).size()
		var controls: Dictionary = part_controls[key]
		var counter := "%d/%d" % [int(appearance[key]) + 1, total]
		controls.number.text = counter
		if total == 0:
			controls.number.text = "미장착"
		elif key in ["weapon", "offhand"]:
			controls.number.text = CharacterArt.description(appearance, key)
		if key in ["weapon_item", "offhand_item"]:
			var type_key := "weapon" if key == "weapon_item" else "offhand"
			var title := CharacterArt.description(appearance, type_key) if total > 0 else "무기2"
			controls.title.text = title
			controls.left.accessibility_name = title + " 이전"
			controls.right.accessibility_name = title + " 다음"
		controls.left.get_parent().modulate.a = 0.55 if total == 0 else 1.0
		controls.left.disabled = total <= 1
		controls.right.disabled = total <= 1

func start_journey() -> void:
	travel_state.clear()
	show_world()

func show_world() -> void:
	var current_hp := BattleUnit.HERO_HP
	if is_instance_valid(battle):
		current_hp = battle.hero_group[0].hp
	clear_screen()
	current_screen = "world"
	battle_hud = CanvasLayer.new()
	battle_hud.layer = 10
	add_child(battle_hud)
	remove_child(screen)
	battle_hud.add_child(screen)
	screen.theme = theme
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	screen.offset_left = 24
	screen.offset_right = -24
	screen.offset_top = 18
	screen.offset_bottom = -14
	world = WorldMapScene.new()
	world.economy = travel_state.get("economy")
	world.hero_hp = current_hp
	world.crowns = travel_state.get("crowns", WorldMap.STARTING_CROWNS)
	world.character_name = player_name if not player_name.is_empty() else "여행자"
	world.clock.elapsed = travel_state.get("elapsed", 0.0)
	world.clock.travel_speed = travel_state.get("speed", 1)
	world.character_frames = character_frames
	world.character_appearance = appearance.duplicate(true)
	add_child(world)
	move_child(world,0)
	if not travel_state.is_empty():
		world.inventory.restore_slots(world.inventory.slot_grid, travel_state.get("bag", {}))
		world.restore_travel(travel_state.position,travel_state.camera,travel_state.zoom,travel_state.get("city_id",""))
	battle_button = button("전투맵 이동", enter_battle_from_world)
	var overview := preload("res://scripts/world_overview.gd").new()
	overview.world = world
	world_overview = overview
	battle_hud.add_child(overview)
	var notice := create_pause_notice()
	var update_notice := func(paused: bool):
		# Keep city dialogs above the automatic pause notice.
		notice.get_parent().layer = battle_hud.layer if world.clock.city_paused else 20
		notice.visible = paused
	world.clock.pause_changed.connect(update_notice)
	update_notice.call(world.clock.speed == 0)
	world.setup_navigation(battle_button, overview)
	ignore_battle_overlay_input(screen)

func create_pause_notice() -> Label:
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	battle_hud.add_child(overlay)
	var notice := label_text("일시 정지", 64)
	notice.name = "PauseNotice"
	notice.theme = theme
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice.add_theme_color_override("font_color", GameUITheme.IVORY)
	notice.add_theme_color_override("font_outline_color", GameUITheme.BORDER)
	notice.add_theme_constant_override("outline_size", 8)
	overlay.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	notice.anchor_top = 0.44
	notice.anchor_bottom = 0.44
	notice.hide()
	return notice

func enter_battle_from_world() -> void:
	if is_instance_valid(world):
		travel_state = {"position":world.unit_position,"camera":world.camera.position,"zoom":world.zoom_level,"city_id":world.current_city.get("id",""),
			"elapsed":world.clock.elapsed, "speed":world.clock.travel_speed, "crowns":world.crowns,
			"economy":world.economy, "bag":world.inventory.snapshot(world.inventory.slot_grid)}
	show_battle()


func ignore_battle_overlay_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_STOP if node is Button else Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): ignore_battle_overlay_input(child)

func show_battle() -> void:
	clear_screen()
	current_screen = "battle"
	battle_hud = CanvasLayer.new()
	battle_hud.layer = BattleMapScene.HUD_LAYER
	add_child(battle_hud)
	remove_child(screen)
	battle_hud.add_child(screen)
	screen.theme = theme
	# Battle pixels map directly to viewport pixels; UI screens keep their responsive stretch.
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	screen.offset_left = 24
	screen.offset_right = -24
	screen.offset_top = 18
	screen.offset_bottom = -14
	battle = BattleMapScene.new()
	battle.character_name = player_name if not player_name.is_empty() else "여행자"
	battle.character_frames = character_frames
	add_child(battle)
	move_child(battle,0)
	var header := HBoxContainer.new()
	screen.add_child(header)
	header.add_theme_constant_override("separation", 14)
	var pause_button := preload("res://scripts/battle_pause_button.gd").new()
	header.add_child(pause_button)
	pause_button.toggled.connect(battle.set_battle_paused)
	battle.pause_changed.connect(pause_button.show_pause_state)
	battle.pause_changed.connect(create_pause_notice().set_visible)
	var title := label_text("서부 초원  /  전투 시험장", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color",GameUITheme.IVORY)
	title.add_theme_color_override("font_outline_color",GameUITheme.BORDER)
	title.add_theme_constant_override("outline_size",4)
	header.add_child(title)
	header.add_child(button("← 월드맵", show_world))
	spacer(screen)
	ignore_battle_overlay_input(screen)
