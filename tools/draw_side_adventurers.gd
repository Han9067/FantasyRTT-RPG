extends SceneTree
## Lossless source-resolution extraction. Never resample or quantize the approved poses.
const REFERENCE := "res://tools/references/approved_male_01.png"
const FRAME_SIZE := Vector2i(512,704)
const HEAD_END := 380
const ORIGINS := [157,835,1514]
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

var poses: Array[Image] = []

func extract_reference() -> void:
	var source := Image.load_from_file(REFERENCE)
	assert(source.get_size() == Vector2i(2172,724))
	for origin in ORIGINS:
		# Translation only: same crop size and y origin, no individual fitting/scaling.
		poses.append(source.get_region(Rect2i(origin,17,FRAME_SIZE.x,FRAME_SIZE.y)))
	# Keep the requested minimal near-boot adjustment in SOURCE pixels only.
	# Shift the right-hand contour left by one source pixel on the boot/toe rows.
	for y in range(623,670):
		for x in range(350,180,-1):
			if poses[0].get_pixel(x,y).a > 0.5:
				poses[0].set_pixel(x-1,y,poses[0].get_pixel(x,y))
				poses[0].set_pixel(x,y,Color.TRANSPARENT)
				break

func tint(color: Color, target: Color, base: Color) -> Color:
	# Continuous colour ratios retain source shading instead of mapping to a fixed palette.
	return Color(clampf(color.r*target.r/base.r,0,1),clampf(color.g*target.g/base.g,0,1),clampf(color.b*target.b/base.b,0,1),color.a)

func variant_pixel(color: Color, gender: int, look: int, is_head: bool) -> Color:
	if color.a == 0 or (gender==0 and look==0): return color
	var v: Array = VARIANTS[gender*4+look]
	if is_head and color.r > color.g*1.15 and color.g > color.b*1.05 and color.v > 0.2 and color.v < 0.77:
		return tint(color,Color(v[0]),Color("69432f"))
	if not is_head and color.g > color.r*1.02 and color.g > color.b*1.2:
		return tint(color,Color(v[3]),Color("788a43"))
	return color

func stamp(image: Image, origin: Vector2i, rows: Array, colors: Dictionary) -> void:
	# Retain the existing variant-specific hair accessories in the source coordinate system.
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var key: String = rows[y].substr(x,1)
			if not colors.has(key): continue
			var start := Vector2i(roundi(40+(origin.x+x-7)*22.1),roundi(16+(origin.y+y-2)*22.1))
			var end := Vector2i(roundi(40+(origin.x+x-6)*22.1),roundi(16+(origin.y+y-1)*22.1))
			image.fill_rect(Rect2i(start,end-start),colors[key])

func make_layers(gender: int, look: int, pose_index: int) -> Array[Image]:
	var body := Image.create(FRAME_SIZE.x,FRAME_SIZE.y,false,Image.FORMAT_RGBA8)
	var head := Image.create(FRAME_SIZE.x,FRAME_SIZE.y,false,Image.FORMAT_RGBA8)
	var pose := poses[pose_index]
	head.blit_rect(pose,Rect2i(0,0,FRAME_SIZE.x,HEAD_END),Vector2i.ZERO)
	body.blit_rect(pose,Rect2i(0,HEAD_END,FRAME_SIZE.x,FRAME_SIZE.y-HEAD_END),Vector2i(0,HEAD_END))
	if gender==0 and look==0: return [body,head]
	for part in [head,body]:
		for y in range(FRAME_SIZE.y):
			for x in range(FRAME_SIZE.x):
				var pixel: Color = part.get_pixel(x,y)
				if pixel.a > 0: part.set_pixel(x,y,variant_pixel(pixel,gender,look,part==head))
	var v: Array = VARIANTS[gender*4+look]
	var colors := {"o":Color("302923"),"h":Color(v[0]),"H":Color(v[1]),"r":Color("b75f66"),"g":Color("c9ab70")}
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
	return [body,head]

func _initialize() -> void:
	extract_reference()
	for gender in range(2):
		for look in range(4):
			var target := "res://assets/adventurers_side/%s/%02d" % ["male" if gender==0 else "female",look+1]
			for animation in ["idle","walk"]:
				var count := 1 if animation=="idle" else 2
				var sheets: Array[Image] = [Image.create(FRAME_SIZE.x*count,FRAME_SIZE.y,false,Image.FORMAT_RGBA8),Image.create(FRAME_SIZE.x*count,FRAME_SIZE.y,false,Image.FORMAT_RGBA8)]
				for frame in range(count):
					var layers := make_layers(gender,look,0 if animation=="idle" else frame+1)
					for part in range(2):
						sheets[part].blit_rect(layers[part],Rect2i(Vector2i.ZERO,FRAME_SIZE),Vector2i(frame*FRAME_SIZE.x,0))
				for part in range(2):
					assert(sheets[part].save_png(target+"/%s_%s_sheet.png" % [animation,"body" if part==0 else "head"])==OK)
	print("Generated 8 source-resolution appearances: separate head/body, 1 idle + 2 walk")
	quit()
