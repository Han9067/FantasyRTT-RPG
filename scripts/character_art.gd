class_name CharacterArt
extends RefCounted
## Original 32×48 pixel figures. All face right; shared foot baseline for future animation.
## Palette keys: outline, hair/shade/light, skin/shade/light, cloth/shade/light,
## linen, leather/shade, iron/shade, brass. No antialiasing or image scaling.

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
		["526b59", "76917a", "344a43", "57392d", "896044", "302723", "c89d76"],
		["60788a", "8ba1a8", "3d4e61", "b48a4e", "d9b76e", "715633", "e4bb8d"],
		["89544a", "b57a60", "583d3b", "373334", "625352", "23262b", "aa795b"],
		["9b8761", "c0ad7e", "655e4a", "814c32", "b57547", "48302b", "d7a782"],
		["536f71", "83a19a", "354c58", "523b30", "926b45", "2e2929", "d7ad86"],
		["805463", "ae7b7d", "543d51", "b18b50", "dec17d", "765b3a", "e5bf98"],
		["6d7653", "a1a479", "424f40", "302d30", "60514e", "22262b", "b88666"],
		["756381", "a496a6", "494354", "884831", "bd7950", "4d302a", "d9ab89"]
	]
	var colors: Array = styles[gender * 4 + look]
	var p := {
		"o": Color("20262a"), "c": Color(colors[0]), "C": Color(colors[1]),
		"d": Color(colors[2]), "h": Color(colors[3]), "H": Color(colors[4]),
		"j": Color(colors[5]), "s": Color(colors[6]),
		"S": Color(colors[6]).lightened(0.18), "t": Color(colors[6]).darkened(0.22),
		"l": Color("d3c7a1"), "L": Color("eee0b6"),
		"b": Color("70503a"), "B": Color("a17a4e"), "q": Color("44372f"),
		"i": Color("8a9798"), "I": Color("c1c7b4"), "v": Color("515e69"),
		"g": Color("c5a66a"), "n": Color("4b5051"), "N": Color("74766a")
	}
	# A grounded shadow and offset legs make the profile readable at battle scale.
	stamp(image, Vector2i(6, 44), ["....oooooooooooooo....", "......oooooooooo......"], {"o": Color("131d22", 0.55)})
	stamp(image, Vector2i(10, 31), [
		".onnnnoonnnno.", ".onNno.onNNno.", ".onnno..onNno.",
		".onnno..onNno.", "onnno...onNno.", "onnno...obBbo.",
		"oqqqo...obBbo.", "obBbo...obBbo.", "obBbo...obbbo.",
		"obbbbo..obbbbo", "oqbbbbo.oqqbbbo", "ooooooo.ooooooo"
	], p)
	# Narrow torso, a back shoulder and a single near arm. Hem and seams differ by outfit.
	var bodies := [
		["....oooooo...", "..oodcllcCo..", ".odddclccCCo.", "oddddcCccCCo.",
		 "oddddcCcccCo.", ".odddcCcccCo.", ".oddddcCccCo.", ".oddddcCccCo.",
		 ".oddddcCccCo.", ".oddddcccccCo", ".oqqqqBgqqqqo", ".oddddcCcccdo",
		 ".oddddcCcccdo", ".oddddcCcccdo", "..odddcccddo.", "...ooooooo..."],
		["....oooooo...", "..oovIlllIo..", ".ovviiIiiIIo.", "ovviiiIiiIIo.",
		 "ovviivIiiIIo.", ".ovviiviiIIo.", ".ovviiviiIIo.", ".ovviiviiIIo.",
		 ".ovviiviiIIo.", ".ovviiviiIIo.", ".oqqqqBgqqqqo", ".oddddcCccCo.",
		 ".oddddcCccCo.", ".oddddcCccCo.", "..odddcccCo..", "...ooooooo..."],
		["....oooooo...", "..ooqlLLllo..", ".oqqqlLllLLo.", "oqqbblLllLLo.",
		 "oqqbblLllLLo.", ".oqqblLllLLo.", ".oqqblLllLLo.", ".oqqblLllLLo.",
		 ".oqqblLllLLo.", ".oqqblLllLLo.", ".oqqqqBgqqqqo", ".oddddcCccCo.",
		 ".oddddcCccCo.", ".oddddcCccCo.", "..odddcccCo..", "...ooooooo..."],
		["....oooooo...", "..oodcLllCo..", ".odddcCccCCo.", "oddddcCccCCo.",
		 "oddddcCccCCo.", ".odddcCccCCo.", ".odddcCccCCo.", ".odddcCccCCo.",
		 ".odddcCccCCo.", ".odddcCccCCo.", ".oqqqqBgqqqqo", ".oddddcCccCo.",
		 ".oddddcCccCo.", ".oddddcCccCo.", ".oddddccccCo.", ".oddddccccCo.",
		 "..odddcccCo..", "...ooooooo..."]
	]
	# Unrecognized letters in patterns intentionally stay transparent.
	stamp(image, Vector2i(8, 17), bodies[look], p)
	# A belt pouch at the back and a diagonal leather baldric on the traveller.
	stamp(image, Vector2i(8, 27), ["oo...", "obBo.", "obgo.", "obbo.", "oooo."], p)
	if look == 0:
		stamp(image, Vector2i(12, 19), ["Bb...", ".Bb..", "..Bb.", "...Bb", "....B"], p)
	# Near sleeve is forward of the torso, ending in a relaxed, visible hand.
	stamp(image, Vector2i(17, 19), [
		".oooo..", "ocCCCo.", "occCCo.", "odcCCo.", "odccCo.",
		".odcCo.", ".odcCo.", ".odcCo.", ".oqBBo.", ".otsSo.",
		".otssSo", "..ottso", "...ooo."
	], p)
	# Small neck, then a single visible eye, projected nose, chin and ear.
	stamp(image, Vector2i(14, 14), [".otto..", ".otsSo.", ".otsSo.", ".olLlo.", "..ooo.."], p)
	stamp(image, Vector2i(12, 5), [
		"...oooooo....", "..ohhHHhho...", ".ojhhHHhhho..", ".ojhhhHHhho..",
		"ojjhhhhhSSo..", "ojjhhhtSSSo..", "ojjhhstSSSo..", ".ojhstSooSo..",
		"..ojstSSSSSoo", "...ottSSSSSSo", "...otttSSSoo.", "....ottsSSSo.",
		".....otttSo..", "......oooo..."
	], p)
	# Each head has its own silhouette, not just a palette swap.
	if gender == 0:
		match look:
			0: # Cropped hair, sideburn and short beard.
				stamp(image, Vector2i(13, 7), [".hhHhHhh..", "jhHhhhhh..", "jhhh......", "jhh.......", ".jh......."], p)
				stamp(image, Vector2i(18, 15), ["j...hh.", "jhhhho.", ".jhhho.", "..ooo.."], p)
			1: # Wavy fair hair, clean-shaven profile.
				stamp(image, Vector2i(12, 5), ["...ooooo...", "..ohHHHho..", ".ohHHhHHho.", ".ojhHHhhho.", "ojjhhhHho..", ".ojhh......", "..ojh......"], p)
			2: # Close-cut head and a long beard.
				stamp(image, Vector2i(13, 6), ["..ohHHhho.", ".ojhhhhhho", ".ojhhhhhho", ".ojh......"], p)
				stamp(image, Vector2i(18, 14), ["j....h.", "jh.hHho", "jhhHHho", ".jhhHho", ".jhhho.", "..jho..", "...o..."], p)
			3: # Tied-back chestnut hair with a cloth headband.
				stamp(image, Vector2i(10, 8), ["..ojhh......", ".ojhHh......", "ojhho.......", "ojho........", ".oo........."], p)
				stamp(image, Vector2i(13, 9), ["ccccCCCCcc", "ddddcccccc"], p)
	else:
		match look:
			0: # Thick braid behind the shoulder.
				stamp(image, Vector2i(10, 11), [".ojh...", "ojhHo..", "ojhho..", ".ohHo..", ".ojhHo.", "..ohho.", "..ojhHo", "...ohho", "...ojho", "...oggo", "....oo."], p)
			1: # Low round bun and loose fringe.
				stamp(image, Vector2i(9, 9), ["..oooo..", ".ohHHho.", "ojhHHHho", "ojhhHhho", ".ojhhho.", "..oooo.."], p)
				stamp(image, Vector2i(19, 8), ["Hhhho", "hho..", "ho..."], p)
			2: # Short, jaw-length dark hair.
				stamp(image, Vector2i(11, 9), ["ojhhHh...", "ojhhHh...", "ojhhh....", "ojhHh....", "ojhh.....", ".ojh.....", ".ojhho...", "..ooo...."], p)
			3: # Long ponytail, bound high with a brass clasp.
				stamp(image, Vector2i(8, 7), ["...oooo...", "..ojHHho..", ".ojhHHhgo.", "ojjhHho...", "ojjhho....", "ojjhho....", ".ojhho....", ".ojhho....", "..ojho....", "..ojho....", "...oho....", "....o....."], p)
	# All assets have the same canvas and baseline and are safe to mirror later.
	return ImageTexture.create_from_image(image)
