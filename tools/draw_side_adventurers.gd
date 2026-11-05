extends SceneTree
## Rasterize the approved male-01 concept on a fixed 32×36 grid, with common head/root alignment.
## Preserve separate head/body sheets; other appearances share the approved pose masks.
const REFERENCE := "res://tools/references/approved_male_01.png"
const GRID_PALETTE := ["302923","69432f","9c603c","f1bd83","d99b67","fff7dc","e8dfb0","788a43","53642f","624032","815136","563629"]
const VARIANTS := [
	["69432f","9c603c","f1bd83","788a43","53642f"],
	["292c35","555867","f5e1d4","aa6454","673c35"],
	["be913e","f1d57f","ecc698","809653","465b38"],
	["3e302a","766047","e5b98c","52738b","304453"],
	["75452f","aa704b","f3cea0","698d9b","3d586e"],
	["a04b35","d78048","efc293","a27b54","6c4935"],
	["adb6b1","e0e0cb","e8bb9e","9181a4","594d6d"],
	["643c2b","a46c44","edbe90","8c657e","523c4b"]
]
var base_poses: Array[Image] = []
var palette: Array[Color] = []

func sample_reference() -> void:
	var source := Image.load_from_file(REFERENCE)
	assert(source.get_size() == Vector2i(2172,724))
	for color in GRID_PALETTE: palette.append(Color(color))
	# Each reference cell has a different margin. Align by the identical head silhouette,
	# then use ONE uniform scale for every pose (no per-frame fitting or leg scaling).
	for pose in range(3):
		var origin: int = [197,151,106][pose] + 724*pose
		var canvas := Image.create(32,36,false,Image.FORMAT_RGBA8)
		for y in range(2,32):
			for x in range(7,26):
				var pixel := source.get_pixel(int(origin+(x-7+0.5)*22.1),int(33+(y-2+0.5)*22.1))
				if pixel.a < 0.7: continue
				var closest := palette[0]
				var distance := INF
				for color in palette:
					var d := Vector3(pixel.r-color.r,pixel.g-color.g,pixel.b-color.b).length_squared()
					if d < distance:
						distance = d
						closest = color
				canvas.set_pixel(x,y,closest)
		base_poses.append(canvas)
	# Approved idle boot: remove exactly the foremost one-pixel column (x=18)
	# from its two sole/toe rows. Restore the contour at x=17, without shortening the leg.
	for y in [30,31]:
		base_poses[0].set_pixel(18,y,Color.TRANSPARENT)
		base_poses[0].set_pixel(17,y,palette[0])
	# Two shaded pixels reveal the opposite boot behind the near leg.
	base_poses[0].set_pixel(12,30,palette[0])
	base_poses[0].set_pixel(13,30,palette[11])
	base_poses[0].set_pixel(12,31,palette[0])
	base_poses[0].set_pixel(13,31,palette[0])

func stamp(image: Image, origin: Vector2i, rows: Array, colors: Dictionary) -> void:
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var key: String = rows[y].substr(x,1)
			if colors.has(key): image.set_pixel(origin.x+x,origin.y+y,colors[key])

func appearance_pixel(color: Color, gender: int, look: int, is_head: bool) -> Color:
	if color.a == 0 or (gender==0 and look==0): return color
	var v: Array = VARIANTS[gender*4+look]
	if color == palette[3]: return Color(v[2])
	if color == palette[4]: return Color(v[2]).darkened(0.16)
	if is_head:
		if color == palette[1] or color == palette[10]: return Color(v[0])
		if color == palette[2]: return Color(v[1])
		if color == palette[9] or color == palette[11]: return Color(v[0]).darkened(0.15)
	else:
		if color == palette[7]: return Color(v[3])
		if color == palette[8]: return Color(v[4])
	return color

func make_layers(gender: int, look: int, animation: String, frame: int) -> Array[Image]:
	var body := Image.create(32,36,false,Image.FORMAT_RGBA8)
	var head := Image.create(32,36,false,Image.FORMAT_RGBA8)
	var pose: Image = base_poses[frame+1] if animation=="walk" else base_poses[0]
	for y in range(36):
		for x in range(32):
			# Reuse one head mask for every walking frame: no changing face, scale or position.
			if y < 18:
				head.set_pixel(x,y,appearance_pixel(base_poses[0].get_pixel(x,y),gender,look,true))
			else:
				body.set_pixel(x,y,appearance_pixel(pose.get_pixel(x,y),gender,look,false))
	var v: Array = VARIANTS[gender*4+look]
	var colors := {"o":palette[0],"h":Color(v[0]),"H":Color(v[1]),"r":Color("b75f66"),"g":Color("c9ab70")}
	if gender == 0:
		match look:
			1: stamp(head,Vector2i(15,4),["HhhH","HhhH","hhhH"],colors)
			2: stamp(head,Vector2i(15,1),[".oo.","ohHo","hHhh"],colors)
			3: stamp(head,Vector2i(12,5),["HHHHhh","hhhhhh"],colors)
	else:
		match look:
			0:
				stamp(head,Vector2i(6,11),["..ohho",".ohHho",".ohHho","ohHHho","ohHhho","ohhhho",".ohhho","..ooo."],colors)
				stamp(head,Vector2i(8,11),["rr","rr"],colors)
			1:
				stamp(head,Vector2i(7,12),["ohHho","ohHho","ohHho","ohHho","ohhho",".ooo."],colors)
				stamp(head,Vector2i(9,10),["gg"],colors)
			2: stamp(head,Vector2i(6,12),[".ohHho",".ohHho",".ohHho",".ohHho","ohHHho","ohHHho","ohhhho",".oooo."],colors)
			3: stamp(head,Vector2i(7,12),[".ohHho",".ohHho","..ohho",".ohHho","..ohho",".ohHho","..oggo","...oo."],colors)
	# A restrained second idle breathing pose; feet remain planted and unchanged.
	if animation=="idle" and frame==1:
		var raised := Image.create(32,36,false,Image.FORMAT_RGBA8)
		raised.blit_rect(head,Rect2i(0,1,32,35),Vector2i.ZERO)
		head = raised
		var upper := body.get_region(Rect2i(0,18,32,8))
		body.fill_rect(Rect2i(0,17,32,8),Color.TRANSPARENT)
		body.blit_rect(upper,Rect2i(0,0,32,8),Vector2i(0,17))
	return [body,head]

func _initialize() -> void:
	sample_reference()
	var overview := Image.create(128,72,false,Image.FORMAT_RGBA8)
	var motion := Image.create(96,36,false,Image.FORMAT_RGBA8)
	for gender in range(2):
		for look in range(4):
			var target := "res://assets/adventurers_side/%s/%02d" % ["male" if gender==0 else "female",look+1]
			DirAccess.make_dir_recursive_absolute(target)
			for animation in ["idle","walk"]:
				var sheets: Array[Image] = [Image.create(64,36,false,Image.FORMAT_RGBA8),Image.create(64,36,false,Image.FORMAT_RGBA8)]
				for frame in range(2):
					var layers := make_layers(gender,look,animation,frame)
					for part in range(2):
						sheets[part].blit_rect(layers[part],Rect2i(0,0,32,36),Vector2i(frame*32,0))
						if animation=="idle" and frame==0:
							overview.blend_rect(layers[part],Rect2i(0,0,32,36),Vector2i(look*32,gender*36))
						if gender==0 and look==0 and (animation=="walk" or frame==0):
							motion.blend_rect(layers[part],Rect2i(0,0,32,36),Vector2i((frame+1)*32 if animation=="walk" else 0,0))
				for part in range(2):
					assert(sheets[part].save_png(target+"/%s_%s_sheet.png" % [animation,"body" if part==0 else "head"])==OK)
	overview.resize(768,432,Image.INTERPOLATE_NEAREST)
	overview.save_png("/tmp/adventurers-007.png")
	motion.resize(960,360,Image.INTERPOLATE_NEAREST)
	motion.save_png("/tmp/adventurer-motion-007.png")
	print("Generated 8 appearances, separate head/body, 2 idle + 2 walk frames")
	quit()
