extends HBoxContainer
## Three screen-space cards composed from original idle artwork.
const Art = preload("res://scripts/character_art.gd")
const CARD_SIZE := Vector2(112, 162)
const GAP := 12
var battle: BattleMap
var cards: Dictionary = {}
var counts: Dictionary = {}
var selected_cards: Dictionary = {}
var normal_panels: Array[StyleBoxTexture] = []
var selected_panels: Array[StyleBoxTexture] = []

func _ready() -> void:
	theme = GameUITheme.build()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("separation", GAP)
	for margin in [8.0,6.0]:
		normal_panels.append(GameUITheme.panel_style(margin))
		selected_panels.append(GameUITheme.paper_style(GameUITheme.PAPER.lightened(0.12),GameUITheme.PAUSE,margin))
	for key: String in ["hero", "infantry", "archers"]:
		var members: Array[BattleUnit] = battle.combat.group(key)
		var card := VBoxContainer.new()
		card.custom_minimum_size = CARD_SIZE
		card.add_theme_constant_override("separation", 0)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(on_card_input.bind(key))
		card.tooltip_text = battle.character_name if key == "hero" else ("보병" if key == "infantry" else "궁병")
		add_child(card)
		cards[key] = card
		var portrait_panel := PanelContainer.new()
		portrait_panel.custom_minimum_size = Vector2(CARD_SIZE.x, 120)
		portrait_panel.add_theme_stylebox_override("panel", normal_panels[0])
		portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait_panel)
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_panel.add_child(holder)
		var portrait := TextureRect.new()
		var texture := members[0].sprite_frames.get_frame_texture(&"idle", 0)
		if key != "hero":
			# Card-only appearance: first skin for both troop types, original equipment.
			var appearance := Art.archer_appearance(true, 0) if key == "archers" else Art.infantry_appearance(true, 0)
			appearance.skin = 0
			texture = ImageTexture.create_from_image(Art.compose(appearance))
		var region := texture.get_image().get_used_rect()
		var crop := AtlasTexture.new()
		crop.atlas = texture
		crop.region = region
		portrait.texture = crop
		# Integer nearest scaling makes the original small sprite readable, without clipping equipment.
		var factor := maxi(1, mini(3, floori(minf(96.0 / region.size.x, 104.0 / region.size.y))))
		portrait.custom_minimum_size = Vector2(region.size) * factor
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(portrait)
		var count_panel := PanelContainer.new()
		count_panel.custom_minimum_size.y = 42
		count_panel.add_theme_stylebox_override("panel", normal_panels[1])
		count_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(count_panel)
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 20)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_panel.add_child(count)
		counts[key] = count
	battle.status_changed.connect(refresh_counts)
	get_viewport().size_changed.connect(layout_cards)
	layout_cards()
	refresh_counts()

func layout_cards() -> void:
	if not is_inside_tree(): return
	var width := CARD_SIZE.x * cards.size() + GAP * (cards.size() - 1)
	size = Vector2(width, CARD_SIZE.y)
	position = Vector2(roundf((get_viewport_rect().size.x - width) * 0.5), get_viewport_rect().size.y - CARD_SIZE.y - 18)

func on_card_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton:
		cards[key].accept_event()
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			select_card(key,event.shift_pressed)

func select_card(key: String, additive := false) -> void:
	var members: Array[BattleUnit] = BattleMap.Combat.living(battle.combat.group(key))
	if members.is_empty(): return
	if not additive: battle.selection.clear()
	for unit in members:
		if not battle.selection.has(unit): battle.selection.append(unit)
	battle.dragging = false
	battle.refresh_selection()

func refresh_counts() -> void:
	for key: String in counts:
		var alive := 0
		var marked := false
		for unit: BattleUnit in battle.combat.group(key):
			if not unit.alive(): continue
			alive += 1
			if battle.selection.has(unit): marked = true
		var value := str(alive) if alive > 0 else ""
		if counts[key].text != value: counts[key].text = value
		cards[key].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if alive > 0 else Control.CURSOR_ARROW
		if selected_cards.get(key,null) != marked:
			selected_cards[key] = marked
			for panel in range(2):
				cards[key].get_child(panel).add_theme_stylebox_override("panel",selected_panels[panel] if marked else normal_panels[panel])

func _process(_delta: float) -> void:
	refresh_counts()
