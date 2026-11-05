class_name WorldMap
extends Node2D
## Decorative world prototype. No input handlers, navigation, or city interaction.
var player_sprite: AnimatedSprite2D
var character_name := "여행자"
var character_frames: SpriteFrames

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_sprite = AnimatedSprite2D.new()
	player_sprite.sprite_frames = character_frames
	player_sprite.position = Vector2(358, 284)
	player_sprite.centered = false
	add_child(player_sprite)
	player_sprite.play("idle")

func box(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(color))

func poly(points: Array, color: String) -> void:
	draw_colored_polygon(PackedVector2Array(points), Color(color))

func mountain(x: float, y: float, height: float, width: float) -> void:
	poly([Vector2(x-width,y+4), Vector2(x+width+12,y+5), Vector2(x+9,y-height+8)], "65724f")
	poly([Vector2(x-width,y), Vector2(x,y-height), Vector2(x+width,y)], "6b7568")
	poly([Vector2(x,y-height), Vector2(x+width,y), Vector2(x+8,y-9), Vector2(x-6,y-height*0.48)], "495b58")
	poly([Vector2(x-width,y), Vector2(x,y-height), Vector2(x-13,y-16), Vector2(x-25,y-8)], "959b7d")
	poly([Vector2(x,y-height), Vector2(x-15,y-height+24), Vector2(x-5,y-height+19), Vector2(x+1,y-height+26), Vector2(x+8,y-height+18)], "c1bfa0")
	for i in range(4):
		box(x-width+9+i*9, y-i*6-3, 8, 2, "7b8665")

func tree(x: int, y: int, variant: int) -> void:
	box(x-5,y+4,15,3,"64784d")
	box(x,y-3,3,10,"66543c")
	if variant == 0:
		poly([Vector2(x-9,y),Vector2(x+1,y-23),Vector2(x+12,y)],"385e4d")
		poly([Vector2(x-6,y-8),Vector2(x+1,y-25),Vector2(x+8,y-8)],"517b54")
		poly([Vector2(x-4,y-15),Vector2(x+1,y-25),Vector2(x+2,y-15)],"82965c")
	else:
		box(x-7,y-14,16,13,"42674b")
		box(x-5,y-20,12,17,"60834f")
		box(x-7,y-14,8,6,"82985b")
		box(x-3,y-22,8,6,"82985b")

func house(x: float, y: float, large := false) -> void:
	var w := 23.0 if large else 15.0
	box(x+3,y+10,w+3,7,"53584b")
	box(x,y,w,14,"c0b08a")
	box(x+w-5,y,5,14,"8e8066")
	poly([Vector2(x-3,y+2),Vector2(x+w/2,y-10),Vector2(x+w+3,y+2)],"6d493f")
	poly([Vector2(x-3,y+2),Vector2(x+w/2,y-10),Vector2(x+w/2,y+2)],"aa7050")
	box(x+3,y+4,3,4,"504d45")
	box(x+w-9,y+6,4,8,"625140")
	box(x+2,y+11,6,1,"e0cba0")

func tower(x: float, y: float) -> void:
	box(x+3,y+4,17,27,"4b5854")
	box(x,y,17,26,"aaa78b")
	box(x+12,y,5,26,"747f73")
	box(x+2,y+4,10,2,"d2c5a0")
	box(x+7,y+12,3,6,"3c4d4b")
	for k in range(3):
		box(x+k*6,y-4,5,6,"c0b89a")
	for k in range(3):
		box(x+1,y+10+k*6,11,1,"8c9680")

func city() -> void:
	# A square fortified town: continuous four-sided walls, four corner towers, one south gate.
	box(282,188,115,98,"536b4c")
	box(278,182,112,92,"8e9070")
	box(288,190,92,74,"a39b75")
	box(323,190,15,75,"bcac80")
	box(290,222,91,10,"bcac80")
	house(297,206)
	house(348,208,true)
	house(297,242)
	house(349,244)
	# Keep within the town, sharing its walls rather than a separate settlement.
	box(315,192,28,21,"b5ae90")
	box(337,192,6,21,"818775")
	poly([Vector2(311,193),Vector2(329,177),Vector2(347,193)],"755548")
	poly([Vector2(311,193),Vector2(329,177),Vector2(330,193)],"b08057")
	box(325,201,5,12,"535b52")
	# Rear, side and front ramparts.
	box(281,183,106,7,"bcb495")
	box(281,190,7,74,"a3a489")
	box(380,190,7,74,"7f8a79")
	box(281,258,106,17,"939c85")
	box(281,255,106,5,"c2bb9a")
	for i in range(15):
		box(281+i*7,179,4,5,"c6be9e")
		box(281+i*7,252,4,5,"d0c6a3")
	for i in range(10):
		box(279,189+i*7,5,4,"c6be9e")
		box(380,189+i*7,5,4,"a3ad90")
	for i in range(12):
		box(284+i*8,265,6,1,"717f71")
	# Gate opening and bridge to the road.
	box(323,258,15,17,"354945")
	box(325,257,11,3,"485c50")
	box(326,261,2,14,"74674b")
	box(331,261,2,14,"74674b")
	box(320,275,21,7,"bfa87a")
	for pos in [Vector2(275,180), Vector2(377,180), Vector2(275,251), Vector2(377,251)]:
		tower(pos.x,pos.y)
	box(386,159,2,24,"5b5140")
	box(388,160,14,8,"9b5949")
	box(388,160,3,8,"c9996b")

func _draw() -> void:
	box(0,0,640,400,"80925d")
	var rng := RandomNumberGenerator.new()
	rng.seed = 48317
	# Low contrast meadow patches with hard pixel edges.
	for i in range(130):
		var x := rng.randi_range(0,630)
		var y := rng.randi_range(0,400)
		box(x,y,rng.randi_range(10,50),rng.randi_range(3,13), ["85965f","8c9b65","788b56","91a06a"][i%4])
	for i in range(2200):
		var x := rng.randi_range(0,639)
		var y := rng.randi_range(0,399)
		box(x,y,1 if i%3 else 2,1,["a5ac70","6f8453","92a167","bbc085"][i%4])
	# A winding ochre track across the grassland, with a spur into the city gate.
	var road := PackedVector2Array([Vector2(-10,352),Vector2(125,332),Vector2(231,347),Vector2(324,309),Vector2(427,311),Vector2(535,280),Vector2(650,291)])
	draw_polyline(road,Color("9c9566"),17,false)
	draw_polyline(road,Color("c2ad79"),11,false)
	draw_polyline(PackedVector2Array([Vector2(330,310),Vector2(330,272)]),Color("c2ad79"),12,false)
	for i in range(5):
		mountain(35+i*48,158+(i%2)*12,58+(i%3)*19,44)
	for i in range(4):
		mountain(474+i*52,133+(i%2)*18,57+(i%3)*15,46)
	for i in range(38):
		var x := rng.randi_range(15,620)
		var y := rng.randi_range(174,282)
		if x < 250 or x > 420:
			tree(x,y,i%2)
	for i in range(12):
		tree(40+i*48,385+(i%3)*6,i%2)
	city()
	# Handful of stones, a field edge, and fence posts establish human scale.
	for i in range(6):
		box(207+i*6,285,2,9,"6d6248")
	box(207,288,33,2,"94805a")
	for i in range(8):
		box(427+(i%4)*9,236+(i/4)*6,7,2,"b4a270")
	for pos in [Vector2(235,211),Vector2(416,321),Vector2(167,300)]:
		box(pos.x,pos.y,6,3,"6e7a68")
		box(pos.x+1,pos.y-2,4,3,"b1b29a")
