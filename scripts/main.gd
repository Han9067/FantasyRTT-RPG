extends Control

var game_version: String = ProjectSettings.get_setting("application/config/version", "0.0.7")
const CharacterArt = preload("res://scripts/character_art.gd")

const GOLD = Color("c9ab70")
const INK = Color("e6dfce")
const WorldMapScene = preload("res://scripts/world_map.gd")
var animations: Array[SpriteFrames] = []
var preview_animation := "idle"
var animation_time := 0.0
var current_screen := ""
var world: Node2D
var screen: VBoxContainer
var selected_gender := 0
var selected_looks := [0, 0]
var player_name := ""
var player_age := 20
var portrait: TextureRect
var choices: HBoxContainer
var genders: Array[Button] = []
var age_label: Label
var name_input: LineEdit
var age_slider: HSlider
var create_button: Button
var textures: Array[Texture2D] = []

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
	for gender in range(2):
		for look in range(4):
			var frames := CharacterArt.animations(gender, look)
			animations.append(frames)
			textures.append(frames.get_frame_texture("idle", 0))
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
		var frames := animations[selected_gender * 4 + selected_looks[selected_gender]]
		var index := int(animation_time * frames.get_animation_speed(preview_animation)) % frames.get_frame_count(preview_animation)
		portrait.texture = frames.get_frame_texture(preview_animation, index)

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
	screen.offset_left = 100
	screen.offset_right = -100
	screen.offset_top = 40
	screen.offset_bottom = -48
	screen.add_theme_constant_override("separation", 18)
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
	genders.clear()
	var header := HBoxContainer.new()
	screen.add_child(header)
	var heading := label_text("새로운 인물", 32)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(button("← 메인 메뉴", show_menu))
	screen.add_child(label_text("당신의 이야기는 아직 쓰이지 않았습니다.", 16))
	var top := panel()
	screen.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	top.add_child(row)
	var frame := panel()
	frame.custom_minimum_size = Vector2(180, 220)
	row.add_child(frame)
	portrait = TextureRect.new()
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(portrait)
	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", 14)
	row.add_child(fields)
	fields.add_child(label_text("인물 정보", 22))
	var inputs := HBoxContainer.new()
	inputs.add_theme_constant_override("separation", 18)
	fields.add_child(inputs)
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inputs.add_child(name_box)
	name_box.add_child(label_text("이름", 15))
	name_input = LineEdit.new()
	name_input.placeholder_text = "이름을 입력하세요"
	name_input.text = player_name
	name_input.max_length = 24
	name_input.custom_minimum_size.y = 48
	name_input.text_changed.connect(func(value: String): player_name = value)
	name_box.add_child(name_input)
	var gender_box := VBoxContainer.new()
	inputs.add_child(gender_box)
	gender_box.add_child(label_text("성별", 15))
	var gender_row := HBoxContainer.new()
	gender_box.add_child(gender_row)
	for i in range(2):
		var b := button(["남", "여"][i], select_gender.bind(i))
		b.toggle_mode = true
		gender_row.add_child(b)
		genders.append(b)
	age_label = label_text("나이  ·  %d세" % player_age, 16)
	fields.add_child(age_label)
	age_slider = HSlider.new()
	age_slider.min_value = 16
	age_slider.max_value = 40
	age_slider.step = 1
	age_slider.value = player_age
	age_slider.custom_minimum_size.y = 28
	age_slider.value_changed.connect(func(value: float):
		player_age = int(value)
		age_label.text = "나이  ·  %d세" % player_age)
	fields.add_child(age_slider)
	fields.add_child(label_text("16세                                                        40세", 13))
	var bottom := panel()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(bottom)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	bottom.add_child(content)
	content.add_child(label_text("외형 선택", 22))
	var preview_row := HBoxContainer.new()
	content.add_child(preview_row)
	var hint := label_text("성별마다 네 가지 외형 · 액자에서 동작 확인", 14)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.add_child(hint)
	preview_row.add_child(button("대기 · 2프레임", func(): preview_animation = "idle"; animation_time = 0.0))
	preview_row.add_child(button("이동 · 2프레임", func(): preview_animation = "walk"; animation_time = 0.0))
	choices = HBoxContainer.new()
	choices.add_theme_constant_override("separation", 16)
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(choices)
	create_button = Button.new()
	create_button.text = "캐릭터 생성"
	create_button.pressed.connect(show_world)
	create_button.custom_minimum_size.y = 54
	screen.add_child(create_button)
	select_gender(selected_gender)

func select_gender(value: int) -> void:
	selected_gender = value
	for i in range(genders.size()):
		genders[i].button_pressed = i == value
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	for i in range(4):
		var b := button("", select_look.bind(i))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = textures[value * 4 + i]
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 110)
		b.tooltip_text = "%s 모험가 %02d" % ["남성" if value == 0 else "여성", i + 1]
		b.accessibility_name = b.tooltip_text
		choices.add_child(b)
	select_look(selected_looks[value])

func select_look(value: int) -> void:
	selected_looks[selected_gender] = value
	portrait.texture = textures[selected_gender * 4 + value]
	for i in range(choices.get_child_count()):
		choices.get_child(i).button_pressed = i == value

func make_character(gender: int, look: int) -> Texture2D:
	return CharacterArt.texture(gender, look)

func show_world() -> void:
	clear_screen()
	current_screen = "world"
	world = WorldMapScene.new()
	world.character_name = player_name if not player_name.is_empty() else "여행자"
	world.character_frames = animations[selected_gender * 4 + selected_looks[selected_gender]]
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
