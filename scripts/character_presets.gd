extends RefCounted
## Appearance-only presets, independent of the character's personal details.
const Art = preload("res://scripts/character_art.gd")
const SLOT_COUNT := 3
# Body indices saved through 0.0.76. Empty entries use the current default outfit.
const LEGACY_OUTFITS := [
	"tunic_black", "tunic_blue", "leather vest_brown", "", "tunic_green", "", "", "",
	"", "tunic_red", "", "", "tunic_green", "tunic_white", "leather vest_black", "gambeson_white",
]
# Closest eye and mouth to each former face, comparing the original feature pixels.
const LEGACY_EYES := [9,7,9,7,7,11,7,10,7,7,7,7,5,9,10,9,7,7,7,7,7,10,10,10,10,9,9,10,9,7,9,9,7,10,7,7,10,7,7,10]
const LEGACY_MOUTHS := [0,0,0,0,1,0,0,0,0,3,3,1,1,0,0,0,0,0,1,0,1,0,1,1,0,0,0,0,0,3,0,0,1,0,0,1,0,0,1,0]
var path: String
var slots: Array[Dictionary] = [{}, {}, {}]

func _init(storage_path := "user://appearance_presets.cfg") -> void:
	path = storage_path
	var data := ConfigFile.new()
	if data.load(path) != OK: return
	if data.get_value("presets", "version", 0) != 1: return
	for i in range(SLOT_COUNT):
		var saved: Variant = data.get_value("presets", str(i), {})
		if saved is Dictionary and saved.get("face") is int and not saved.has("eye"):
			var old_face := clampi(int(saved.face), 0, LEGACY_EYES.size() - 1)
			saved.eye = LEGACY_EYES[old_face]
			saved.mouth = LEGACY_MOUTHS[old_face]
			saved.gender = 0
		slots[i] = clean_appearance(saved)
		if slots[i].is_empty(): continue
		var outfit_id: String = saved.get("body_id", "")
		if not saved.has("body_id") and saved.body >= 0 and saved.body < LEGACY_OUTFITS.size():
			outfit_id = LEGACY_OUTFITS[saved.body]
		var body_index: int = Art.data().body_ids.find(outfit_id)
		slots[i].body = body_index if body_index >= 0 else Art.data().body_ids.find(Art.DEFAULT_OUTFIT)
		var family: String = Art.data().primary_types[slots[i].weapon]
		if family == "two_axe":
			# Before sparse numbering, the old zero-based index was the file number minus one.
			var id: String = saved.get("two_axe_id", "two_axe/%d" % (int(saved.weapon_item) + 1))
			slots[i].weapon_item = maxi(0, Art.data().melee_groups.two_axe.find(id))

		# Numeric sheet IDs take precedence over the older selector positions.
		restore_weapon(slots[i], saved.get("primary_item_id"), true)
		restore_weapon(slots[i], saved.get("secondary_item_id"), false)
		Art.normalize(slots[i])

func restore_weapon(appearance: Dictionary, id: Variant, primary: bool) -> void:
	if not id is int: return
	var item := Art.weapon_by_item_id(id)
	if item.is_empty(): return
	var types: Array = Art.data().primary_types if primary else Art.data().secondary_types
	var family := types.find(item.family)
	if family < 0: return
	var items: Array = Art.primary_items(item.family) if primary else Art.data().melee_groups[item.family]
	appearance["weapon" if primary else "offhand"] = family
	appearance["weapon_item" if primary else "offhand_item"] = items.find(item.id)

func clean_appearance(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var result := Art.defaults()
	for key in result:
		if not value.has(key) or not value[key] is int: return {}
		result[key] = value[key]
	Art.normalize(result)
	return result

func get_appearance(slot: int) -> Dictionary:
	return slots[slot].duplicate(true) if slot >= 0 and slot < SLOT_COUNT else {}

func save_appearance(slot: int, appearance: Dictionary) -> Error:
	if slot < 0 or slot >= SLOT_COUNT: return ERR_INVALID_PARAMETER
	var snapshot := clean_appearance(appearance)
	if snapshot.is_empty(): return ERR_INVALID_DATA
	var data := ConfigFile.new()
	data.set_value("presets", "version", 1)
	for i in range(SLOT_COUNT):
		var record: Dictionary = (snapshot if i == slot else slots[i]).duplicate()
		if not record.is_empty() and Art.data().primary_types[record.weapon] == "two_axe":
			record.two_axe_id = Art.equipped_weapon(record).id
		if not record.is_empty():
			record.body_id = Art.data().body_ids[record.body]
			var primary := Art.equipped_weapon(record)
			var secondary := Art.equipped_offhand(record)
			if primary.has("item_id"): record.primary_item_id = primary.item_id
			if secondary.has("item_id"): record.secondary_item_id = secondary.item_id
		data.set_value("presets", str(i), record)
	# Replace only after a complete write, preserving existing slots on failure.
	var error := data.save(path + ".tmp")
	if error != OK: return error
	error = DirAccess.rename_absolute(path + ".tmp", path)
	if error == OK: slots[slot] = snapshot
	return error
