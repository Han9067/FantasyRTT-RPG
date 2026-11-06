class_name BattleGround
extends Node2D
## A static native-pixel ground texture, baked only when the viewport changes.
## Broad grass/dirt masses and small dither clusters echo the supplied battle reference.
var ground: ImageTexture
var extent := Vector2i.ZERO

func road_y(x: float, height: float) -> float:
	return height * 0.61 + sin(x * 0.006) * 32.0 + sin(x * 0.017) * 6.0

func road_distance(x: float, y: float, width: float, height: float) -> float:
	var main := absf(y - road_y(x, height))
	var branch := absf(x - (width * 0.64 + sin(y * 0.009) * 20.0))
	return minf(main, branch * 1.45) if y < road_y(x, height) else main

func generate(dimensions: Vector2i) -> void:
	if dimensions == extent: return
	extent = dimensions
	var img := Image.create(extent.x, extent.y, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 73194
	noise.frequency = 0.008
	noise.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 27391
	var grass := [Color("939774"), Color("979a76"), Color("9c9d78"), Color("a0a17c"), Color("a6a57f")]
	var dirt := [Color("b8a174"), Color("c1a87a"), Color("c8ae7f"), Color("ccb383")]
	# Two-pixel clusters, not enlarged terrain tiles. Noise is sampled in world pixels.
	for y in range(0, extent.y, 2):
		for x in range(0, extent.x, 2):
			var n := noise.get_noise_2d(x, y)
			var variation := rng.randf_range(-0.11, 0.11)
			var tone := clampi(int((n + variation + 0.5) * 4.0), 0, 4)
			var color: Color = grass[tone]
			var distance := road_distance(x, y, extent.x, extent.y)
			var edge := 19.0 + n * 12.0 + rng.randf_range(-3.0, 3.0)
			if distance < edge:
				color = dirt[clampi(int((n + 0.6) * 3.0), 0, 3)]
			elif distance < edge + 7.0 and rng.randf() < 0.5:
				color = Color("aaa17a")
			img.fill_rect(Rect2i(x,y,mini(2,extent.x-x),mini(2,extent.y-y)), color)
	# Sparse, broken dither rather than a regular visible grid.
	for i in range(int(extent.x * extent.y / 40)):
		var x := rng.randi_range(3, extent.x - 5)
		var y := rng.randi_range(3, extent.y - 5)
		var on_road := road_distance(x, y, extent.x, extent.y) < 16.0
		var color := Color("ad936b") if on_road else Color("878d6b")
		if i % 3 == 0: color = Color("d4ba8b") if on_road else Color("b0b08a")
		img.fill_rect(Rect2i(x,y,rng.randi_range(1,3),1), color)
		if i % 4 == 0:
			img.set_pixel(x+1,y+2,color)
	for i in range(int(extent.x * extent.y / 2400)):
		var p := Vector2i(rng.randi_range(12,extent.x-12),rng.randi_range(12,extent.y-12))
		if road_distance(p.x,p.y,extent.x,extent.y) < 27: continue
		# Tiny grass tufts and occasional buttercups, scaled to a ~24px soldier.
		img.fill_rect(Rect2i(p.x-2,p.y,6,1),Color("858c64"))
		img.fill_rect(Rect2i(p.x-1,p.y-2,1,2),Color("b7b88b"))
		img.fill_rect(Rect2i(p.x+2,p.y-3,1,3),Color("bec095"))
		if i % 9 == 0:
			img.fill_rect(Rect2i(p.x,p.y-3,2,2),Color("e0cd8d"))
			img.set_pixel(p.x+1,p.y-4,Color("eee0a8"))
	# Low stones; keep the spawn and main track open.
	for i in range(int(extent.x * extent.y / 18000)):
		var p := Vector2i(rng.randi_range(20,extent.x-20),rng.randi_range(95,extent.y-75))
		if Vector2(p).distance_to(Vector2(extent)*0.5) < 65 or road_distance(p.x,p.y,extent.x,extent.y) < 32: continue
		var w := rng.randi_range(4,9)
		img.fill_rect(Rect2i(p.x-1,p.y+2,w+3,2),Color("818364"))
		img.fill_rect(Rect2i(p.x,p.y,w,3),Color("706c58"))
		img.fill_rect(Rect2i(p.x+1,p.y-1,w-2,3),Color("a5a18b"))
		img.fill_rect(Rect2i(p.x+1,p.y-1,w-3,1),Color("cac3a2"))
	# A few pale, winding worn-grass seams, like the reference's field details.
	for i in range(18):
		var p := Vector2i(rng.randi_range(40,extent.x-80),rng.randi_range(90,extent.y-75))
		if road_distance(p.x,p.y,extent.x,extent.y) < 36: continue
		for j in range(rng.randi_range(14,30)):
			var yy := p.y + int(sin(j*0.23)*2)
			if j % 5 != 0: img.set_pixel(p.x+j,yy,Color("bfc09a"))
	ground = ImageTexture.create_from_image(img)
	queue_redraw()

func _draw() -> void:
	if ground: draw_texture(ground,Vector2.ZERO)
