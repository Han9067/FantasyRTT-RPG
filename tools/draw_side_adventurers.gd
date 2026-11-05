extends SceneTree
## Reproducible side-profile pixel art, based on the uploaded adventurers' proportions/palettes.
## Outputs head/body sheets separately; never writes to the uploaded source directory.
const PALETTES = [
	["79462b","ad7444","ebbf88","688952","3f583b"],
	["292c35","555867","f5e1d4","aa6454","673c35"],
	["be913e","f1d57f","ecc698","809653","465b38"],
	["3e302a","766047","e5b98c","52738b","304453"],
	["75452f","aa704b","f3cea0","698d9b","3d586e"],
	["a04b35","d78048","efc293","a27b54","6c4935"],
	["adb6b1","e0e0cb","e8bb9e","9181a4","594d6d"],
	["643c2b","a46c44","edbe90","8c657e","523c4b"]
]

func stamp(image: Image, x: int, y: int, rows: Array, palette: Dictionary) -> void:
	for yy in range(rows.size()):
		for xx in range(rows[yy].length()):
			var key: String = rows[yy].substr(xx,1)
			if palette.has(key):
				image.set_pixel(x+xx,y+yy,palette[key])

func make_layers(gender: int, look: int, animation: String, frame: int) -> Array[Image]:
	var colors: Array = PALETTES[gender*4+look]
	var p := {"o":Color("202a26"), "h":Color(colors[0]), "H":Color(colors[1]),
		"s":Color(colors[2]), "t":Color("ca9470"), "w":Color("fff2c9"),
		"c":Color(colors[3]), "d":Color(colors[4]), "l":Color("d4c49c"),
		"b":Color("604c33"), "B":Color("776244"), "g":Color("d7b879"),
		"r":Color("e9a0a0"), "a":Color("a97659"), "f":Color("e04c52")}
	var head := Image.create(32,36,false,Image.FORMAT_RGBA8)
	var body := Image.create(32,36,false,Image.FORMAT_RGBA8)
	var walking := animation == "walk"
	var bob := frame % 2
	# Same broad head and small body as the reference. A single visible eye and tiny nose.
	stamp(head,8,3-bob,[
		"....oooooooooo...",
		"..oohhhhhhhhhhoo.",
		".ohHHHHHHHHhhhho.",
		".ohHHHHHHHHhhhho.",
		"ohhhhhhhhhhhhhho.",
		"ohhhhhhhhhhhssso.",
		"ohhhhhhhhsssssso.",
		"ohhhhhhsssssssso.",
		"ohhhhhsstsswosso.",
		"ohhhhssstssossso.",
		".ohhhsttsssosssso",
		"..ohhsstssssssso.",
		"...ohsssssssasoo.",
		"....ossssssssoo..",
		".....ooooooo....."
	],p)
	# Large simple highlight clusters and recognisable hair silhouettes from source 01–04.
	if gender == 0:
		match look:
			1:
				stamp(head,11,4-bob,["hhhhhohhhhh", "HHHHhoHHhhh", "HHHhhoHHhhh", "hhhhhohhhhh"],p)
			2:
				stamp(head,12,1-bob,["...oooo...", "..ohHHho..", ".ohHHHHho.", "ohHHHHhho.", "ohhhhhho.."],p)
			3:
				stamp(head,11,5-bob,["HHHHHHHHhhh", "hhhhhhhhhhh", "hhhhhhhssso", "hhhhhhsssso"],p)
	else:
		match look:
			0:
				stamp(head,6,9-bob,["..ohhho", "..ohHho", ".ohHHho", ".ohHhho", ".ohHhho", "ohHHhho", "ohHhhho", ".ohhho.", "..ooo.."],p)
				stamp(head,9,9-bob,["ff", "ff"],p)
			1:
				stamp(head,7,8-bob,[".ohHho", ".ohHho", "ohHHho", "ohHHho", "ohHhho", "ohHhho", "ohhhho", ".oooo."],p)
				stamp(head,9,9-bob,["gg","gg"],p)
			2:
				stamp(head,7,9-bob,[".ohHho", ".ohHho", ".ohHho", ".ohHho", ".ohHho", "ohHHho", "ohHHho", "ohhhho", ".oooo."],p)
			3:
				stamp(head,7,9-bob,["..ohHho", ".ohHHho", ".ohHhho", "..ohHho", ".ohHho.", "..ohHho", ".ohHho.", "..oggo.", "...oo.."],p)
		stamp(head,20,14-bob,["rr"],p)
	# Far-side leg and hand are partially hidden, so the body also reads as a profile.
	var far_step: int = [2,0,-2,0][frame] if walking else 0
	var near_step: int = [-2,0,2,0][frame] if walking else 0
	stamp(body,13+far_step,25-(1 if walking and frame==1 else 0),["oBBBo", "oBBBo", "obbbbo", ".ooooo"],p)
	stamp(body,19-(near_step/2),19-bob,["dco", "dco", "sso", "sso"],p)
	# Rounded back at left, chest at right, one collar, short tunic with side belt buckle.
	stamp(body,10,17-bob,[
		"...ddlllcdd..", "..ddclllccdo.", ".ddcccccccdo.", ".ddcccccccdo.",
		".ddcccccccdo.", ".ddcccccccdo.", "..dbbbbggbbo.", "..dbbbbggbbo.",
		"...ddcccddo..", "....ddddd...."
	],p)
	stamp(body,15+near_step,26-(1 if walking and frame==3 else 0),["oBBBo.","oBBBo.","obbbbo",".ooooo"],p)
	# Broad visible shoulder/upper arm overlays the centre, not the opposite front edge.
	stamp(body,12+near_step/2,19-bob,["dcccd", "dcccd", "dcccd", "dsssd", ".ssso", ".ssso", "..oo."],p)
	# Original cloth accent now sits on the visible shoulder.
	stamp(body,13+near_step/2,20-bob,["HH"],p)
	return [body,head]

func _initialize() -> void:
	var overview := Image.create(32*4,36*2,false,Image.FORMAT_RGBA8)
	for gender in range(2):
		for look in range(4):
			var target := "res://assets/adventurers_side/%s/%02d" % ["male" if gender==0 else "female",look+1]
			DirAccess.make_dir_recursive_absolute(target)
			for animation in ["idle","walk"]:
				var count := 2 if animation=="idle" else 4
				var sheets: Array[Image] = [Image.create(32*count,36,false,Image.FORMAT_RGBA8),Image.create(32*count,36,false,Image.FORMAT_RGBA8)]
				for frame in range(count):
					var layers := make_layers(gender,look,animation,frame)
					for part in range(2):
						sheets[part].blit_rect(layers[part],Rect2i(0,0,32,36),Vector2i(frame*32,0))
					if animation=="idle" and frame==0:
						overview.blend_rect(layers[0],Rect2i(0,0,32,36),Vector2i(look*32,gender*36))
						overview.blend_rect(layers[1],Rect2i(0,0,32,36),Vector2i(look*32,gender*36))
				for part in range(2):
					var error := sheets[part].save_png(target+"/%s_%s_sheet.png" % [animation,"body" if part==0 else "head"])
					assert(error==OK)
	overview.resize(768,432,Image.INTERPOLATE_NEAREST)
	overview.save_png("/tmp/side-adventurers-006.png")
	print("Generated 32 separate side-profile layer sheets")
	quit()
