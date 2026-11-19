extends RefCounted
## Appearance-only presets, independent of the character's personal details.
const Art = preload("res://scripts/character_art.gd")
const SLOT_COUNT := 3
var path: String
var slots: Array[Dictionary] = [{}, {}, {}]

func _init(storage_path := "user://appearance_presets.cfg") -> void:
	path = storage_path
	var data := ConfigFile.new()
	if data.load(path) != OK: return
	if data.get_value("presets", "version", 0) != 1: return
	for i in range(SLOT_COUNT):
		var saved: Variant = data.get_value("presets", str(i), {})
		slots[i] = clean_appearance(saved)
		if slots[i].is_empty(): continue
		var family: String = Art.data().primary_types[slots[i].weapon]
		if family == "two_axe":
			# Before sparse numbering, the old zero-based index was the file number minus one.
			var id: String = saved.get("two_axe_id", "two_axe/%d" % (int(saved.weapon_item) + 1))
			slots[i].weapon_item = maxi(0, Art.data().melee_groups.two_axe.find(id))

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
		data.set_value("presets", str(i), record)
	# Replace only after a complete write, preserving existing slots on failure.
	var error := data.save(path + ".tmp")
	if error != OK: return error
	error = DirAccess.rename_absolute(path + ".tmp", path)
	if error == OK: slots[slot] = snapshot
	return error
