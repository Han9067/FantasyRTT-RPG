class_name CharacterArt
extends RefCounted
## Original young-adult side profiles, 32×48 pixels. Right-facing, shared foot baseline.
## Pixel patterns are layered back to front; dots are transparent.

static func stamp(image: Image, origin: Vector2i, rows: Array, palette: Dictionary) -> void:
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var key := row.substr(x, 1)
			if palette.has(key):
				image.set_pixel(origin.x + x, origin.y + y, palette[key])

static func texture(gender: int, look: int, animation := "idle", frame := 0) -> Texture2D:
	var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	var styles := [
		["65816b", "91a781", "40594d", "694735", "97694a", "423329", "e2b38c"],
		["677f9e", "98adba", "45586f", "c19a5b", "e0bd7c", "88683e", "ecc8a2"],
		["9b6556", "c29571", "684b47", "3b363b", "66606a", "282932", "ca9b78"],
		["998961", "c3b185", "695f49", "995f3e", "c28958", "653e31", "e6b994"],
		["648a85", "9db6a1", "435e61", "634735", "987453", "3c302d", "e5b996"],
		["8e728c", "b8a1ae", "604f6c", "c3a066", "e6c78c", "8e6b44", "edc6a4"],
		["7c8860", "adb48a", "535e47", "39353d", "62586a", "282731", "c99b7d"],
		["737f9f", "a5b2c6", "50596e", "98593f", "c17e53", "633d30", "e5b995"]
	]
	var colors: Array = styles[gender * 4 + look]
	var p := {
		"o": Color("394047"), "c": Color(colors[0]), "C": Color(colors[1]),
		"d": Color(colors[2]), "h": Color(colors[3]), "H": Color(colors[4]),
		"j": Color(colors[5]), "s": Color(colors[6]),
		"S": Color(colors[6]).lightened(0.12), "t": Color(colors[6]).darkened(0.16),
		"l": Color("d4c8ab"), "L": Color("f0dfba"), "b": Color("795b46"),
		"B": Color("aa8660"), "q": Color("514138"), "g": Color("d2b77a"),
		"n": Color("545b60"), "N": Color("7b8181"), "e": Color("34323c")
	}
	var walking := animation == "walk"
	var step_cycle := [-3, 0, 3, 0]
	var stride: int = step_cycle[frame % 4] if walking else 0
	var lift := 1 if (walking and frame % 2 == 1) or (not walking and frame == 1) else 0
	stamp(image, Vector2i(9, 42), ["..xxxxxxxxxxxx..", "...xxxxxxxxxx..."], {"x": Color(0.06, 0.09, 0.11, 0.3)})
	leg(image, Vector2i(12, 35), -stride, walking and frame == 1, true, p)
	arm(image, Vector2i(18, 26 - lift), -stride, true, p)
	# Broad cloth planes and a rounded belly: coloured edges, eight interior pixels.
	stamp(image, Vector2i(10, 24 - lift), [
		"...dtssdd...", "..ddllLCcd..", ".ddccCCCCcd.", ".dccCCCCCCcd",
		"ddcccCCCCCcd", "ddccccCCCCcd", "ddccccCCCCcd", ".dqqBBBgqqd.",
		".ddcccCCCcd.", "..ddccCCCdd.", "...ddddddd.."
	], p)
	if look == 0:
		stamp(image, Vector2i(17, 26 - lift), ["Bl..", ".Bl.", "..Bl"], p)
	elif look == 1:
		stamp(image, Vector2i(18, 26 - lift), ["lCC", "lcC", "lcC", "lcC"], p)
	elif look == 2:
		stamp(image, Vector2i(17, 26 - lift), ["BllC", "bllC", "BllC", "bllC", "BllC"], p)
	elif look == 3:
		stamp(image, Vector2i(12, 32 - lift), ["dccCCCCcd", "dccCCCCcd", "ddccCCcdd", ".ddddddd."], p)
	leg(image, Vector2i(15, 35), stride, walking and frame == 3, false, p)
	arm(image, Vector2i(12, 26 - lift), stride, false, p)
	# Same face dimensions as 0.0.2, with a shortened body and overlapping shoulders.
	stamp(image, Vector2i(12, 14 - lift), [
		"..oooooo..", ".ojhhHHho.", "ojhhHHHhho", "ojhhhhhsSo", "ojhhhssSSo",
		"ojhhstseSo", ".ojhstSSSso", "..otssSSSo", "...otssSo.", "....oooo.."
	], p)
	if not walking and frame == 1:
		image.set_pixel(19, 19 - lift, p["t"])
	# Hair silhouettes: all eight are youthful, uncovered faces.
	if gender == 0:
		match look:
			0: # Soft chestnut fringe.
				stamp(image, Vector2i(12, 14 - lift), ["..o.oooo..", ".ohhHHHho.", "ohhhHHhhho", "ojhhh.hho.", ".ojh......"], p)
			1: # Short, gently swept blonde hair.
				stamp(image, Vector2i(12, 14 - lift), ["...ooooo..", "..ohHHHho.", ".ohHHHhhho", "ojhHhhhho.", "ojhh......"], p)
			2: # Dark, tousled crop.
				stamp(image, Vector2i(12, 13 - lift), ["...o.oo...", "..ohhHho..", ".ohhHHHho.", "ohhHhhHhho", "ojhhh.hhho", ".ojh......"], p)
			3: # Short side-parted auburn hair.
				stamp(image, Vector2i(12, 14 - lift), ["..oooooo..", ".ohHHjhho.", "ohHHhHhhho", "ojhh..hho.", "ojhh......"], p)
	else:
		match look:
			0: # Loose shoulder-length hair.
				stamp(image, Vector2i(10, 17 - lift), ["..ojh", "..ojH", ".ojhH", ".ojhH", ".ojhH", "ojhhH", "ojhHh", "ojhhH", ".ojhh", "..ooo"], p)
			1: # Small low ponytail.
				stamp(image, Vector2i(9, 18 - lift), ["..ooo", ".ohHo", "ohHgo", "ohho.", "ojho.", "ojho.", ".oho.", "..o.."], p)
			2: # Rounded chin-length bob.
				stamp(image, Vector2i(11, 16 - lift), ["ojhhH", "ojhHh", "ojhHh", "ojhHh", "ojhhH", "ojhhH", ".ojhh", "..ooo"], p)
			3: # A light braid, tied at the shoulder.
				stamp(image, Vector2i(10, 18 - lift), ["..ojh", ".ojhH", ".ojhH", "..ohh", "..ojH", "..ohh", "..ojH", "..oggo", "...oo"], p)
	return ImageTexture.create_from_image(image)

static func stroke(image: Image, points: Array[Vector2i], width: int, color: Color) -> void:
	for k in range(points.size() - 1):
		var distance := maxi(absi(points[k+1].x-points[k].x), absi(points[k+1].y-points[k].y))
		for i in range(distance + 1):
			var pos := Vector2(points[k]).lerp(Vector2(points[k+1]), float(i) / maxi(distance, 1))
			image.fill_rect(Rect2i(Vector2i(pos.round()), Vector2i(width, width)), color)

static func leg(image: Image, hip: Vector2i, stride: int, raised: bool, far: bool, p: Dictionary) -> void:
	var foot := Vector2i(hip.x + stride, 39 - (2 if raised else 0))
	var knee := Vector2i(hip.x + stride / 2, 37 - (1 if raised else 0))
	stroke(image, [hip, knee, foot], 5, p["n"].darkened(0.18))
	stroke(image, [hip + Vector2i.ONE, knee + Vector2i.ONE, foot + Vector2i.ONE], 3, p["n"] if far else p["N"])
	stamp(image, foot, ["qbbbq..", "bBBBbq.", "qbbbbbo", ".qqqqq."], p)

static func arm(image: Image, shoulder: Vector2i, swing: int, far: bool, p: Dictionary) -> void:
	var elbow := shoulder + Vector2i(swing / 2, 2)
	var hand := shoulder + Vector2i(swing, 4)
	stroke(image, [shoulder, elbow, hand], 5, p["d"])
	stroke(image, [shoulder + Vector2i.ONE, elbow + Vector2i.ONE, hand + Vector2i.ONE], 3, p["c"] if far else p["C"])
	stamp(image, hand + Vector2i(1, 1), ["lll", "tss", "tSs", ".tt"], p)

static func animations(gender: int, look: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation in ["idle", "walk"]:
		frames.add_animation(animation)
		frames.set_animation_loop(animation, true)
		frames.set_animation_speed(animation, 2.0 if animation == "idle" else 6.0)
		for i in range(2 if animation == "idle" else 4):
			frames.add_frame(animation, texture(gender, look, animation, i))
	return frames
