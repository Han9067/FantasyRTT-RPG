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
	player_sprite.position = Vector2(358, 288)
	player_sprite.centered = false
	add_child(player_sprite)
	player_sprite.play("idle")

func box(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(color))

func poly(points: Array, color: String) -> void:
	draw_colored_polygon(PackedVector2Array(points), Color(color))

func mountain(x: float, y: float, height: float, width: float) -> void:
	# Broken rock silhouette and stepped, pixel-sized strata at the original footprint.
	var ridge := [Vector2(x-width,y),Vector2(x-width*.7,y-height*.3),Vector2(x-width*.49,y-height*.39),Vector2(x-width*.28,y-height*.7),Vector2(x-6,y-height*.83),Vector2(x,y-height),Vector2(x+9,y-height*.79),Vector2(x+width*.35,y-height*.6),Vector2(x+width*.53,y-height*.5),Vector2(x+width*.7,y-height*.23),Vector2(x+width,y)]
	poly([Vector2(x-width-2,y+4),Vector2(x+width+10,y+5),Vector2(x+9,y-height+8)], "52644f")
	poly(ridge, "566661")
	poly([Vector2(x-width,y),Vector2(x-width*.7,y-height*.3),Vector2(x-width*.49,y-height*.39),Vector2(x-width*.28,y-height*.7),Vector2(x-6,y-height*.83),Vector2(x,y-height),Vector2(x+1,y-height*.67),Vector2(x-9,y-height*.45),Vector2(x-4,y-height*.26),Vector2(x-17,y)], "92977e")
	poly([Vector2(x,y-height),Vector2(x+9,y-height*.79),Vector2(x+width*.35,y-height*.6),Vector2(x+width*.53,y-height*.5),Vector2(x+12,y-height*.42),Vector2(x+6,y-height*.64)], "738477")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x*73+y)
	for i in range(150):
		var point := Vector2(rng.randi_range(int(x-width),int(x+width)),rng.randi_range(int(y-height),int(y)))
		if Geometry2D.is_point_in_polygon(point, PackedVector2Array(ridge)):
			var light := point.x < x-4
			box(point.x,point.y,rng.randi_range(2,5),1,"b1b295" if light else "718579")
			if i % 4 == 0:
				box(point.x+1,point.y+1,3,2,"76836f" if light else "465953")
	for i in range(6):
		var yy := y-height+9+i*7
		var xx := x-2-(i%3)*3
		box(xx,yy,3,5,"c0bda0")
		box(xx-3,yy+4,5,2,"a8ad90")
	for i in range(8):
		box(x-width+8+i*9,y-(i%3)*3-2,7,2,"71855b")

func tree(x: int, y: int, variant: int) -> void:
	box(x-6,y+4,17,3,"5c714d")
	box(x,y-5,4,12,"514939")
	box(x+1,y-4,2,10,"a18559")
	if variant == 0:
		# Layered evergreen boughs: dark undersides, warm foliage tips.
		for tier in range(3):
			var yy := y-tier*7
			var w := 11-tier*3
			poly([Vector2(x-w,yy),Vector2(x+1,yy-13),Vector2(x+w+1,yy)],"354d42")
			poly([Vector2(x-w+2,yy-2),Vector2(x+1,yy-12),Vector2(x+w-1,yy-2)],"547653")
			box(x-2,yy-8,3,2,"92a56c")
			box(x-w+3,yy-3,w-2,1,"7f995e")
			box(x+2,yy-3,w-3,1,"648659")
	else:
		# Rounded foliage clusters with a coherent upper-left light source.
		for pos in [Vector2(-7,-15),Vector2(1,-17),Vector2(-3,-22),Vector2(-4,-11)]:
			box(x+pos.x-1,y+pos.y+2,11,8,"354e40")
			box(x+pos.x+1,y+pos.y,7,11,"354e40")
			box(x+pos.x,y+pos.y+2,9,6,"5e8052")
			box(x+pos.x+2,y+pos.y+1,5,7,"74915c")
			box(x+pos.x+1,y+pos.y+2,4,2,"a0ac70")
			box(x+pos.x+6,y+pos.y+6,2,2,"436845")

func masonry(x: float, y: float, w: int, h: int, dark := false) -> void:
	for row in range(h / 4):
		for col in range(w / 6):
			var xx := x+col*6+(3 if row%2 else 0)
			if xx+5 <= x+w:
				box(xx,y+row*4,5,3,"7a887e" if dark else "b0b29a")
				box(xx,y+row*4,4,1,"97a291" if dark else "d1c9a7")
				box(xx+4,y+row*4+2,1,1,"53665f" if dark else "7e8d7b")

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

	# Timber frame, lit window and staggered clay roof tiles.
	box(x,y+3,2,11,"6d5743")
	box(x+w-5,y+3,1,11,"6d5743")
	box(x,y+9,w-5,1,"93734f")
	box(x+3,y+4,3,4,"393f3c")
	box(x+4,y+5,1,2,"ddbc77")
	for tile_y in range(4):
		var half := (tile_y+1)*w/10
		for tile_x in range(int(half*2/4)):
			box(x+w/2-half+tile_x*4,y-8+tile_y*3,3,1,"c99568")
	box(x+w-5,y-8,3,7,"777e6c")
	box(x+w-6,y-9,5,2,"b5b392")

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

	masonry(x+1,y+7,11,18)
	masonry(x+13,y+7,4,18,true)
	box(x+6,y+11,4,7,"495b54")
	box(x+7,y+12,2,5,"263c38")
	box(x+5,y+18,6,1,"d1c9a7")
	box(x-1,y+23,19,3,"758578")
	box(x-1,y+23,14,1,"c5c1a1")

func city() -> void:
	# A square fortified town: continuous four-sided walls, four corner towers, one south gate.
	box(282,188,115,98,"536b4c")
	box(278,182,112,92,"8e9070")
	box(288,190,92,74,"a39b75")
	box(323,190,15,75,"bcac80")
	box(290,222,91,10,"bcac80")
	for i in range(24):
		box(325+(i%2)*6,192+(i/2)*6,4,2,"d1c3a0")
	for i in range(15):
		box(290+i*6,225,4,2,"d1c3a0")
	house(297,206)
	house(348,208,true)
	house(297,242)
	house(349,244)
	# Keep within the town, sharing its walls rather than a separate settlement.
	box(315,192,28,21,"b5ae90")
	box(337,192,6,21,"818775")
	poly([Vector2(311,193),Vector2(329,177),Vector2(347,193)],"755548")
	poly([Vector2(311,193),Vector2(329,177),Vector2(330,193)],"b08057")
	masonry(316,194,20,18)
	box(325,201,5,12,"394d45")
	box(326,202,2,9,"876e4d")
	for roof_y in range(4):
		for roof_x in range(roof_y+1):
			box(327-roof_y*3+roof_x*6,181+roof_y*3,4,1,"d2a473")
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
	masonry(283,260,102,15)
	masonry(281,191,7,60)
	masonry(380,191,7,60,true)
	# Gate opening and bridge to the road.
	box(323,258,15,17,"354945")
	box(325,257,11,3,"485c50")
	box(326,261,2,14,"74674b")
	box(331,261,2,14,"74674b")
	box(320,275,21,7,"bfa87a")
	for i in range(5):
		box(320+i*4,275,1,7,"8e7753")
	box(322,257,2,18,"d3c5a0")
	box(338,257,2,18,"748273")
	for pos in [Vector2(275,180), Vector2(377,180), Vector2(275,251), Vector2(377,251)]:
		tower(pos.x,pos.y)
	box(386,159,2,24,"5b5140")
	box(388,160,14,8,"9b5949")
	box(388,160,3,8,"c9996b")

func _draw() -> void:
	box(0,0,640,400,"7c8d5d")
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
	# Small grass tufts echo the sprites' clustered highlights rather than single noisy pixels.
	for i in range(220):
		var x := rng.randi_range(0,635)
		var y := rng.randi_range(0,396)
		box(x,y,5,1,"647c50")
		box(x+1,y-2,1,2,"a5b179")
		box(x+3,y-3,1,3,"9cab70")
		if i%11 == 0:
			box(x+1,y-3,2,1,"dfc88c")
	# A winding ochre track across the grassland, with a spur into the city gate.
	var road := PackedVector2Array([Vector2(-10,352),Vector2(125,332),Vector2(231,347),Vector2(324,309),Vector2(427,311),Vector2(535,280),Vector2(650,291)])
	draw_polyline(road,Color("9c9566"),17,false)
	draw_polyline(road,Color("c2ad79"),11,false)
	draw_polyline(PackedVector2Array([Vector2(330,310),Vector2(330,272)]),Color("c2ad79"),12,false)
	for i in range(100):
		var point := road[rng.randi_range(0,road.size()-2)]
		var index := road.find(point)
		point = point.lerp(road[index+1],rng.randf())
		box(floor(point.x),floor(point.y)+rng.randi_range(-4,4),rng.randi_range(1,3),1,"aa9367")
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
