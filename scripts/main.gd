extends Control

var game_version: String = ProjectSettings.get_setting("application/config/version", "0.0.30")
const CharacterArt = preload("res://scripts/character_art.gd")

const GOLD = Color("c9ab70")
const INK = Color("e6dfce")
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
var battle_status: Label
var battle_hud: CanvasLayer
var world: WorldMap
var world_status: Label
var world_overview: Control
var battle_button: Button
var travel_state: Dictionary = {}
var screen: VBoxContainer
var selected_gender := 0
var player_name := ""
var player_age := 20
var portrait: TextureRect
var genders: Array[Button] = []
var age_label: Label
var name_input: LineEdit
var age_slider: HSlider
var create_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/NotoSansCJK-Regular.ttc")
	t.default_font_size = 18
	for kind in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color("333d3a") if kind == "normal" else Color("52604e")
		s.border_color = GOLD if kind != "normal" else Color("756b50")
		s.set_border_width_all(2)
		s.content_margin_left = 20
		s.content_margin_right = 20
		s.content_margin_top = 10
		s.content_margin_bottom = 10
		t.set_stylebox(kind, "Button", s)
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_color", "LineEdit", INK)
	theme = t
	character_frames = CharacterArt.animations(appearance)
	show_menu()

func _draw() -> void:
	if current_screen in ["battle", "world"]: return
	draw_rect(Rect2(Vector2.ZERO, size), Color("171f22"))
	# Quiet silhouettes of a fortified city, drawn on an integer pixel grid.
	var base := size.y * 0.80
	for i in range(24):
		var x := float(i) * size.x / 23.0
		var h := float(40 + (i * 37 % 110))
		draw_rect(Rect2(x, base - h, 48, size.y), Color("212e30"))
		if i % 3 == 0:
			for j in range(3):
				draw_rect(Rect2(x + j * 18, base - h - 10, 10, 12), Color("212e30"))
	draw_line(Vector2(0, size.y - 30), Vector2(size.x, size.y - 30), Color("514c3c"), 2)

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
	overline.modulate = GOLD
	overline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(overline)
	var title := label_text("분열의 시대", 64)
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
	footer.modulate = GOLD
	screen.add_child(footer)

func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color("252e30")
	s.border_color = Color("756b50")
	s.set_border_width_all(2)
	s.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", s)
	return p

func show_creation() -> void:
	clear_screen()
	current_screen = "creation"
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
	fields.add_child(label_text("인물 정보", 20))
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
	for i in range(2):
		var b := button(["남", "여"][i], select_gender.bind(i))
		b.toggle_mode = true
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
	preview_column.add_child(label_text("외형 미리보기", 20))
	var frame := panel()
	frame.name = "PortraitFrame"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(330, 210)
	preview_column.add_child(frame)
	portrait = TextureRect.new()
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(portrait)
	var previews := HBoxContainer.new()
	previews.add_theme_constant_override("separation", 6)
	preview_column.add_child(previews)
	for entry in [["idle", "대기"], ["walk", "걷기"], ["attack", "공격"]]:
		var b := button(entry[1], set_preview_animation.bind(entry[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		previews.add_child(b)
	var note := label_text("성별과 관계없이 파츠 조합 가능", 13)
	note.modulate = GOLD
	preview_column.add_child(note)

	var selector_column := VBoxContainer.new()
	selector_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector_column.add_theme_constant_override("separation", 10)
	content.add_child(selector_column)
	selector_column.add_child(label_text("외형 파츠", 20))
	selector_column.add_child(label_text("좌우 버튼으로 외형과 무기 선택", 14))
	var columns := HBoxContainer.new()
	columns.name = "PartColumns"
	columns.add_theme_constant_override("separation", 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selector_column.add_child(columns)
	for i in range(2):
		var rows := VBoxContainer.new()
		rows.name = "BodyParts" if i == 0 else "BeardAndWeapon"
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
		parts_columns[1 if key in ["beard", "beard_color", "weapon"] else 0].add_child(row)
		var title := label_text(entry[1], 16)
		title.custom_minimum_size.x = 88
		row.add_child(title)
		var left := part_button("◀", change_part.bind(key, -1))
		left.accessibility_name = entry[1] + " 이전"
		row.add_child(left)
		var number := label_text("", 17)
		number.custom_minimum_size.x = 52
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(number)
		var right := part_button("▶", change_part.bind(key, 1))
		right.accessibility_name = entry[1] + " 다음"
		row.add_child(right)
		var detail := label_text("", 13)
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.clip_text = true
		detail.custom_minimum_size.x = 64
		detail.modulate = GOLD
		row.add_child(detail)
		part_controls[key] = {"left": left, "right": right, "number": number, "detail": detail}
	create_button = button("캐릭터 생성", start_journey)
	create_button.custom_minimum_size.y = 50
	screen.add_child(create_button)
	select_gender(selected_gender)
	refresh_part_controls()
	_process(0.0)

func part_button(value: String, callback: Callable) -> Button:
	var result := button(value, callback)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := theme.get_stylebox(state, "Button").duplicate() as StyleBoxFlat
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
	selected_gender = value
	for i in range(genders.size()):
		genders[i].button_pressed = i == value

func change_part(key: String, direction: int) -> void:
	appearance[key] = posmod(int(appearance[key]) + direction, CharacterArt.count(appearance, key))
	CharacterArt.normalize(appearance)
	character_frames = CharacterArt.animations(appearance)
	last_preview_frame = -1
	refresh_part_controls()
	_process(0.0)

func refresh_part_controls() -> void:
	for entry in CharacterArt.PARTS:
		var key: String = entry[0]
		var total := CharacterArt.count(appearance, key)
		var controls: Dictionary = part_controls[key]
		controls.number.text = "%d/%d" % [int(appearance[key]) + 1, total]
		controls.detail.text = CharacterArt.description(appearance, key)
		controls.detail.tooltip_text = controls.detail.text
		controls.left.disabled = total <= 1
		controls.right.disabled = total <= 1

func start_journey() -> void:
	travel_state.clear()
	show_world()

func show_world() -> void:
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
	world.character_name = player_name if not player_name.is_empty() else "여행자"
	world.character_frames = character_frames
	add_child(world)
	move_child(world,0)
	if not travel_state.is_empty():
		world.restore_travel(travel_state.position,travel_state.camera,travel_state.zoom)
	var header := Control.new()
	header.custom_minimum_size.y = 50
	screen.add_child(header)
	var left := label_text("분열된 제국  /  월드맵",20)
	header.add_child(left)
	left.anchor_right = 0.33
	left.offset_top = 10
	left.offset_bottom = 42
	left.clip_text = true
	battle_button = button("전투맵 이동", enter_battle_from_world)
	header.add_child(battle_button)
	battle_button.focus_mode = Control.FOCUS_NONE
	battle_button.anchor_left = 0.5
	battle_button.anchor_right = 0.5
	battle_button.offset_left = -100
	battle_button.offset_right = 100
	battle_button.offset_bottom = 48
	var back := button("← 캐릭터",show_creation)
	header.add_child(back)
	back.focus_mode = Control.FOCUS_NONE
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.offset_left = -160
	back.offset_right = 0
	back.offset_bottom = 48
	spacer(screen)
	var info := panel()
	var style := info.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.set_content_margin_all(10)
	style.bg_color = Color("252e30e8")
	info.add_theme_stylebox_override("panel",style)
	screen.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	info.add_child(row)
	world_status = label_text("",14)
	world_status.custom_minimum_size.x = 215
	world_status.clip_text = true
	row.add_child(world_status)
	var instructions := label_text("우클릭 : 이동   방향키/WASD : 카메라   휠 : 확대",13)
	instructions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(instructions)
	row.add_child(label_text("버전 : " + game_version,13))
	world.status_changed.connect(refresh_world_status)
	refresh_world_status()
	var overview := preload("res://scripts/world_overview.gd").new()
	overview.world = world
	world_overview = overview
	# Kept outside container layout; a draggable camera overview in the upper right.
	battle_hud.add_child(overview)
	overview.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	overview.offset_left = -244
	overview.offset_right = -24
	overview.offset_top = 92
	overview.offset_bottom = 260
	ignore_battle_overlay_input(screen)

func refresh_world_status() -> void:
	if not is_instance_valid(world_status) or not is_instance_valid(world): return
	world_status.text = world.character_name + (" · 이동 중" if world.moving else " · 대기") + " · %d%%" % int(world.zoom_level*100)
	world_status.tooltip_text = world_status.text

func enter_battle_from_world() -> void:
	if is_instance_valid(world):
		travel_state = {"position":world.unit_position,"camera":world.camera.position,"zoom":world.zoom_level}
	show_battle()


func ignore_battle_overlay_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_STOP if node is Button else Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): ignore_battle_overlay_input(child)

func show_battle() -> void:
	clear_screen()
	current_screen = "battle"
	battle_hud = CanvasLayer.new()
	battle_hud.layer = 10
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
	var title := label_text("서부 초원  /  전투 시험장", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(button("← 월드맵", show_world))
	spacer(screen)
	var info := panel()
	var style := info.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.set_content_margin_all(10)
	style.bg_color = Color("252e30e8")
	info.add_theme_stylebox_override("panel",style)
	screen.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	info.add_child(row)
	battle_status = label_text("",14)
	battle_status.custom_minimum_size.x = 220
	battle_status.clip_text = true
	row.add_child(battle_status)
	var instructions := label_text("클릭·드래그 : 선택   우클릭 : 이동   WASD : 카메라   휠 : 확대",13)
	instructions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(instructions)
	row.add_child(label_text("버전 : " + game_version,13))
	battle.status_changed.connect(refresh_battle_status)
	refresh_battle_status()
	ignore_battle_overlay_input(screen)

func refresh_battle_status() -> void:
	if not is_instance_valid(battle_status) or not is_instance_valid(battle): return
	var state := "선택되지 않음"
	if battle.selected: state = "이동 중" if battle.moving else "선택됨 · 대기"
	battle_status.text = battle.character_name + " · " + state + " · %d%%" % int(battle.zoom_level*100)
	battle_status.tooltip_text = battle_status.text
