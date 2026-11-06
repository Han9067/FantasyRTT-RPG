extends Control

var game_version: String = ProjectSettings.get_setting("application/config/version", "0.0.13")
const CharacterArt = preload("res://scripts/character_art.gd")

const GOLD = Color("c9ab70")
const INK = Color("e6dfce")
const WorldMapScene = preload("res://scripts/world_map.gd")
var character_frames: SpriteFrames
var appearance: Dictionary = CharacterArt.defaults()
var part_controls: Dictionary = {}
var parts_scroll: ScrollContainer
var top_panel: PanelContainer
var bottom_panel: PanelContainer
var last_preview_frame := -1
var preview_animation := "idle"
var animation_time := 0.0
var current_screen := ""
var world: Node2D
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
	resized.connect(func():
		queue_redraw()
		if is_instance_valid(world): world.scale = size / Vector2(640, 400))
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
		var index := int(animation_time * character_frames.get_animation_speed(preview_animation)) % character_frames.get_frame_count(preview_animation)
		if index != last_preview_frame:
			portrait.texture = CharacterArt.preview_texture(character_frames.get_frame_texture(preview_animation, index))
			last_preview_frame = index

func clear_screen() -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
		world = null
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
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
	preview_column.custom_minimum_size.x = 258
	preview_column.add_theme_constant_override("separation", 10)
	content.add_child(preview_column)
	preview_column.add_child(label_text("외형 미리보기", 20))
	var frame := panel()
	frame.name = "PortraitFrame"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(258, 210)
	preview_column.add_child(frame)
	portrait = TextureRect.new()
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(portrait)
	var previews := HBoxContainer.new()
	previews.add_theme_constant_override("separation", 6)
	preview_column.add_child(previews)
	for entry in [["idle", "대기"], ["walk", "걷기"], ["run", "달리기"]]:
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
	selector_column.add_child(label_text("좌우 버튼으로 선택 · 아래에서 무기 선택", 14))
	parts_scroll = ScrollContainer.new()
	parts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	parts_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parts_scroll.follow_focus = true
	selector_column.add_child(parts_scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	parts_scroll.add_child(rows)
	for entry in CharacterArt.PARTS:
		var key: String = entry[0]
		var row := HBoxContainer.new()
		row.name = key
		row.add_theme_constant_override("separation", 8)
		rows.add_child(row)
		var title := label_text(entry[1], 16)
		title.custom_minimum_size.x = 156
		row.add_child(title)
		var left := button("◀", change_part.bind(key, -1))
		left.accessibility_name = entry[1] + " 이전"
		row.add_child(left)
		var number := label_text("", 17)
		number.custom_minimum_size.x = 70
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(number)
		var right := button("▶", change_part.bind(key, 1))
		right.accessibility_name = entry[1] + " 다음"
		row.add_child(right)
		var detail := label_text("", 13)
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.clip_text = true
		detail.modulate = GOLD
		row.add_child(detail)
		part_controls[key] = {"left": left, "right": right, "number": number, "detail": detail}
	create_button = button("캐릭터 생성", show_world)
	create_button.custom_minimum_size.y = 50
	screen.add_child(create_button)
	select_gender(selected_gender)
	refresh_part_controls()
	_process(0.0)

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

func show_world() -> void:
	clear_screen()
	current_screen = "world"
	world = WorldMapScene.new()
	world.character_name = player_name if not player_name.is_empty() else "여행자"
	world.character_frames = character_frames
	world.scale = size / Vector2(640, 400)
	add_child(world)
	move_child(world, 0)
	var header := HBoxContainer.new()
	screen.add_child(header)
	var title := label_text("서부 변경  /  월드맵", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(button("← 캐릭터", show_creation))
	screen.add_child(label_text("넓은 초원과 산맥 사이, 제국의 작은 요새도시", 16))
	spacer(screen)
	var info := panel()
	screen.add_child(info)
	var row := HBoxContainer.new()
	info.add_child(row)
	var description := label_text("그레이워치  ·  요새도시\n" + world.character_name + "의 여정이 시작되는 곳", 18)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(description)
	row.add_child(label_text("지형 미리보기  ·  상호작용 없음\n버전 : " + game_version, 14))
