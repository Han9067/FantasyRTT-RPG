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

static func texture(gender: int, look: int) -> Texture2D:
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
		"o": Color("2c3038"), "c": Color(colors[0]), "C": Color(colors[1]),
		"d": Color(colors[2]), "h": Color(colors[3]), "H": Color(colors[4]),
		"j": Color(colors[5]), "s": Color(colors[6]),
		"S": Color(colors[6]).lightened(0.12), "t": Color(colors[6]).darkened(0.16),
		"l": Color("d4c8ab"), "L": Color("f0dfba"), "b": Color("795b46"),
		"B": Color("aa8660"), "q": Color("514138"), "g": Color("d2b77a"),
		"n": Color("545b60"), "N": Color("7b8181"), "e": Color("34323c")
	}
	stamp(image, Vector2i(10, 44), [".xxxxxxxxxxx.", "..xxxxxxxxx.."], {"x": Color(0.06, 0.09, 0.11, 0.35)})
	# Upright resting stance: short boots, straight knees, modest overlap of the legs.
	stamp(image, Vector2i(11, 31), [
		".onnnonnNo.", ".onnnonnNo.", ".onnnonnNo.", ".onnnonnNo.",
		".onno.onNo.", ".onno.onNo.", ".onno.onNo.", ".onno.onNo.",
		".oqbo.obBo.", ".obbo.obBo.", ".obbo.obBo.", ".obbb.obBbo", ".oooo.ooooo"
	], p)
	# Body tapers gently at the waist; collar sits directly underneath the head.
	stamp(image, Vector2i(10, 19), [
		"...olllo...", "..odcLCco..", ".odccCccCo.", ".odccCccCo.",
		".odccCccCo.", "..odcCccCo.", "..odcCccCo.", "..odcCccCo.",
		"..odccccCo.", "..oqbbgqqo.", "..odccCcco.", "..odccCcco.",
		"..odccCcco.", "...oodooo.."
	], p)
	# Different tailoring, with restrained details visible at the native resolution.
	match look:
		0:
			stamp(image, Vector2i(13, 21), ["B....", ".B...", "..B..", "...B.", "....B"], p)
		1:
			stamp(image, Vector2i(13, 21), ["ll....", "lc....", "lc....", "lc....", "lc....", "lc...."], p)
		2:
			stamp(image, Vector2i(12, 21), ["bBlL..", "bbll..", "bBll..", "bbll..", "bBll..", "bbll..", "bbll.."], p)
		3:
			stamp(image, Vector2i(12, 29), ["dcCcccCo", "dcCcccCo", "dcCcccCo", "dcCcccCo", "odccCco.", ".ooooo.."], p)
	# Near arm lies naturally alongside the torso, with a small hand at hip height.
	stamp(image, Vector2i(17, 21), [
		".CCo", "cCCo", "ccCo", "dcCo", "dcCo", "dcCo", "dcCo", "qlLo", "tsSo", "tsso", ".oo."
	], p)
	# Neck and compact, smooth face: one eye and a one-pixel nose, no beard or wrinkles.
	stamp(image, Vector2i(15, 17), ["tso", "tSo", "lLo"], p)
	stamp(image, Vector2i(12, 8), [
		"..oooooo..", ".ojhhHHho.", "ojhhHHHhho", "ojhhhhhsSo", "ojhhhssSSo",
		"ojhhstseSo", ".ojhstSSSso", "..otssSSSo", "...otssSo.", "....oooo.."
	], p)
	# Hair silhouettes: all eight are youthful, uncovered faces.
	if gender == 0:
		match look:
			0: # Soft chestnut fringe.
				stamp(image, Vector2i(12, 8), ["..o.oooo..", ".ohhHHHho.", "ohhhHHhhho", "ojhhh.hho.", ".ojh......"], p)
			1: # Short, gently swept blonde hair.
				stamp(image, Vector2i(12, 8), ["...ooooo..", "..ohHHHho.", ".ohHHHhhho", "ojhHhhhho.", "ojhh......"], p)
			2: # Dark, tousled crop.
				stamp(image, Vector2i(12, 7), ["...o.oo...", "..ohhHho..", ".ohhHHHho.", "ohhHhhHhho", "ojhhh.hhho", ".ojh......"], p)
			3: # Short side-parted auburn hair.
				stamp(image, Vector2i(12, 8), ["..oooooo..", ".ohHHjhho.", "ohHHhHhhho", "ojhh..hho.", "ojhh......"], p)
	else:
		match look:
			0: # Loose shoulder-length hair.
				stamp(image, Vector2i(10, 11), ["..ojh", "..ojH", ".ojhH", ".ojhH", ".ojhH", "ojhhH", "ojhHh", "ojhhH", ".ojhh", "..ooo"], p)
			1: # Small low ponytail.
				stamp(image, Vector2i(9, 12), ["..ooo", ".ohHo", "ohHgo", "ohho.", "ojho.", "ojho.", ".oho.", "..o.."], p)
			2: # Rounded chin-length bob.
				stamp(image, Vector2i(11, 10), ["ojhhH", "ojhHh", "ojhHh", "ojhHh", "ojhhH", "ojhhH", ".ojhh", "..ooo"], p)
			3: # A light braid, tied at the shoulder.
				stamp(image, Vector2i(10, 12), ["..ojh", ".ojhH", ".ojhH", "..ohh", "..ojH", "..ohh", "..ojH", "..oggo", "...oo"], p)
	return ImageTexture.create_from_image(image)
