extends HBoxContainer
## Three small, screen-space cards; portraits reuse the original idle texture.
const CARD_SIZE := Vector2(112, 162)
const GAP := 12
var battle: BattleMap
var cards: Dictionary = {}
var counts: Dictionary = {}

func _ready() -> void:
	theme = GameUITheme.build()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("separation", GAP)
	for key: String in ["hero", "infantry", "archers"]:
		var members: Array[BattleUnit] = battle.combat.group(key)
		var card := VBoxContainer.new()
		card.custom_minimum_size = CARD_SIZE
		card.add_theme_constant_override("separation", 0)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.tooltip_text = battle.character_name if key == "hero" else ("보병" if key == "infantry" else "궁병")
		add_child(card)
		cards[key] = card
		var portrait_panel := PanelContainer.new()
		portrait_panel.custom_minimum_size = Vector2(CARD_SIZE.x, 120)
		portrait_panel.add_theme_stylebox_override("panel", GameUITheme.panel_style(8))
		portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait_panel)
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_panel.add_child(holder)
		var portrait := TextureRect.new()
		var texture := members[0].sprite_frames.get_frame_texture(&"idle", 0)
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
		count_panel.add_theme_stylebox_override("panel", GameUITheme.panel_style(6))
		count_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(count_panel)
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 20)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_panel.add_child(count)
		counts[key] = count
	get_viewport().size_changed.connect(layout_cards)
	layout_cards()
	refresh_counts()

func layout_cards() -> void:
	if not is_inside_tree(): return
	var width := CARD_SIZE.x * cards.size() + GAP * (cards.size() - 1)
	size = Vector2(width, CARD_SIZE.y)
	position = Vector2(roundf((get_viewport_rect().size.x - width) * 0.5), get_viewport_rect().size.y - CARD_SIZE.y - 18)

func refresh_counts() -> void:
	for key: String in counts:
		var alive := BattleMap.Combat.living(battle.combat.group(key)).size()
		var value := str(alive) if alive > 0 else ""
		if counts[key].text != value: counts[key].text = value

func _process(_delta: float) -> void:
	refresh_counts()
