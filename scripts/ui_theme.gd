class_name GameUITheme
extends RefCounted
## Shared native-pixel paper frames. Textures are generated once, then tiled by nine-slice.
const BORDER_WIDTH := 5 # Previously 2px; user requested +3px.
const PAPER := Color("ead4a4")
const BORDER := Color("533721")
const BUTTON_BORDER := Color("b58a5b")
const IVORY := Color("fff5df")
const INK := Color("3f2a1b")
const MUTED := Color("785b3d")
const PAUSE := Color("ffd54a")
static var shared: Theme
static var textures: Dictionary = {}

static func paper_texture(fill: Color, edge: Color, dimensions := Vector2i(32,32)) -> Texture2D:
	var key := str([fill,edge,dimensions])
	if textures.has(key): return textures[key]
	var img := Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_RGBA8)
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			var dy := mini(y,dimensions.y-1-y)
			var inset := 4 if dy < 2 else (2 if dy < 4 else 0)
			if x < inset or x >= dimensions.x-inset: continue
			var color := fill
			if dy < BORDER_WIDTH or x < inset+BORDER_WIDTH or x >= dimensions.x-inset-BORDER_WIDTH:
				color = edge
			elif y == BORDER_WIDTH or x == BORDER_WIDTH:
				color = fill.lightened(0.25)
			elif y >= dimensions.y-7 or x >= dimensions.x-7:
				color = fill.darkened(0.12)
			elif (x*17+y*31)%83 == 0:
				color = fill.darkened(0.045)
			elif (x*29+y*13)%97 == 0:
				color = fill.lightened(0.12)
			img.set_pixel(x,y,color)
	var texture := ImageTexture.create_from_image(img)
	textures[key] = texture
	return texture

static func paper_style(fill: Color, edge: Color, margin := 14.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = paper_texture(fill,edge)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_texture_margin(side,8)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.set_content_margin_all(margin)
	return style

static func panel_style(margin := 22.0) -> StyleBoxTexture:
	return paper_style(PAPER,BORDER,margin)

static func button_style(state: String, pause := false) -> StyleBoxTexture:
	var fill := IVORY
	var edge := BUTTON_BORDER
	if state in ["hover","hover_pressed"]: fill = Color("fffaf0")
	if state in ["pressed","hover_pressed"]: fill = Color("e9d8b3")
	if state == "disabled":
		fill = Color("e3d9c4")
		edge = Color("c3ac8b")
	if pause and state in ["pressed","hover_pressed"]: edge = PAUSE
	var style := paper_style(fill,edge,10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	return style

static func build() -> Theme:
	if shared != null: return shared
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/NotoSansCJK-Regular.ttc")
	t.default_font_size = 18
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		t.set_stylebox(state,"Button",button_style(state))
	# Focus is a transparent outline, so it never hides a pressed/disabled fill.
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("8e602f")
	focus.set_border_width_all(4)
	focus.set_expand_margin_all(4)
	focus.anti_aliasing = false
	t.set_stylebox("focus","Button",focus)
	for control in ["Button","LineEdit","Label","TooltipLabel","PopupMenu"]:
		for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_selected_color"]:
			t.set_color(state,control,INK)
		t.set_color("font_disabled_color",control,Color("927e62"))
	for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
		t.set_color("icon_"+state+"_color","Button",INK if state != "disabled" else MUTED)
	for control in ["Panel","PanelContainer","PopupPanel","PopupMenu","TooltipPanel"]:
		t.set_stylebox("panel",control,panel_style(14 if control == "TooltipPanel" else 22))
	t.set_font_size("font_size","TooltipLabel",14)
	for state in ["normal","read_only"]:
		t.set_stylebox(state,"LineEdit",paper_style(IVORY,BUTTON_BORDER,10))
	t.set_stylebox("focus","LineEdit",focus)
	t.set_color("font_placeholder_color","LineEdit",MUTED)
	t.set_color("caret_color","LineEdit",INK)
	t.set_color("selection_color","LineEdit",Color("d6b47c"))
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("c8ab79")
	rail.border_color = BORDER
	rail.set_border_width_all(4)
	rail.content_margin_top = 6
	rail.content_margin_bottom = 6
	rail.anti_aliasing = false
	t.set_stylebox("slider","HSlider",rail)
	var filled := rail.duplicate() as StyleBoxFlat
	filled.bg_color = BUTTON_BORDER
	t.set_stylebox("grabber_area","HSlider",filled)
	t.set_stylebox("grabber_area_highlight","HSlider",filled)
	t.set_icon("grabber","HSlider",paper_texture(IVORY,BUTTON_BORDER,Vector2i(20,26)))
	t.set_icon("grabber_highlight","HSlider",paper_texture(Color("fffaf0"),BORDER,Vector2i(20,26)))
	t.set_icon("grabber_disabled","HSlider",paper_texture(PAPER,BUTTON_BORDER,Vector2i(20,26)))
	var separator := StyleBoxLine.new()
	separator.color = BUTTON_BORDER
	separator.thickness = 2
	t.set_stylebox("separator","HSeparator",separator)
	shared = t
	return t
