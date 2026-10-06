extends RefCounted

## Presentation-only registry. Validate once; a bad item never enters the cache.
const AssetLoader = preload("res://scripts/asset_loader.gd")
const BASE: String = "res://assets/units/protagonist_cutout"
const PATH: String = BASE + "/gear_visuals.json"
const SLOTS: PackedStringArray = ["weapon", "offhand", "armor", "boots", "trinket"]
const DEFAULTS: Dictionary = {"weapon": "training_sword", "offhand": "splintered_shield", "armor": "patched_cloak", "boots": "skirmisher_boots", "trinket": "cracked_lantern"}
const REPLACE_PARTS: Dictionary = {"weapon": ["weapon_r"], "armor": ["torso", "arm_r", "arm_l", "hips"], "boots": ["foot_r", "foot_l"], "offhand": [], "trinket": []}

static var _loaded: bool = false
static var _defaults: Dictionary = DEFAULTS.duplicate()
static var _items: Dictionary = {}

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	if not data is Dictionary or data.get("schema_version") != 1 or not data.get("items") is Dictionary or not data.get("slot_defaults") is Dictionary:
		push_error("Invalid protagonist gear registry: " + PATH)
		return
	var layouts: Dictionary = {}
	for facing: String in ["front", "rear"]:
		layouts[facing] = JSON.parse_string(FileAccess.get_file_as_string(BASE.path_join(facing + ".json")))
	for slot: String in SLOTS:
		var default_id: Variant = data["slot_defaults"].get(slot)
		if default_id is String and not default_id.is_empty():
			_defaults[slot] = default_id
		else:
			push_error("Invalid protagonist gear default: " + slot)
	for item_id: String in data["items"]:
		var entry: Variant = data["items"][item_id]
		if _valid_entry(entry, layouts):
			_items[item_id] = entry
		else:
			push_error("Invalid protagonist gear entry; using slot default: " + item_id)
	for slot: String in SLOTS:
		var id: String = str(_defaults[slot])
		if not _items.has(id) or str(_items[id].get("slot", "")) != slot:
			push_error("Invalid protagonist gear default entry: " + id)
			_defaults[slot] = DEFAULTS[slot]

static func _valid_point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int)

static func _valid_hide(value: Variant) -> bool:
	if not value is Array:
		return false
	for clip: Variant in value:
		if not clip is String:
			return false
	return true

static func _valid_entry(entry: Variant, layouts: Dictionary) -> bool:
	if not entry is Dictionary or not SLOTS.has(str(entry.get("slot", ""))) or not entry.get("facings") is Dictionary:
		return false
	var slot: String = entry["slot"]
	if slot == "weapon" and (not (entry.get("hands") is float or entry.get("hands") is int) or int(entry["hands"]) not in [1, 2] or entry.get("motion") not in ["sword", "heavy", "stab"]):
		return false
	if slot == "weapon" and float(entry["hands"]) != float(int(entry["hands"])):
		return false
	if slot == "offhand" and entry.get("held") not in ["shield", "hand"]:
		return false
	if not _valid_hide(entry.get("hide_in_clips", [])):
		return false
	var facings: Dictionary = entry["facings"]
	if not facings.is_empty() and (not facings.has("front") or not facings.has("rear")):
		return false
	for facing: String in facings:
		if not layouts.has(facing) or not layouts[facing] is Dictionary or not facings[facing] is Dictionary:
			return false
		var ops: Dictionary = facings[facing]
		if not ops.get("replace", []) is Array or not ops.get("attach", []) is Array or not ops.get("weapon_grip", {}) is Dictionary:
			return false
		for kind: String in ["replace", "attach"]:
			for op: Variant in ops.get(kind, []):
				if not op is Dictionary or not op.get("file") is String:
					return false
				var texture: Texture2D = AssetLoader.load_texture_source_first(BASE.path_join(op["file"]))
				if texture == null or (op.has("offset") and not _valid_point(op["offset"])):
					return false
				if kind == "replace":
					if not REPLACE_PARTS[slot].has(op.get("part", "")):
						return false
					var found: bool = false
					for part: Dictionary in layouts[facing].get("parts", []):
						found = found or part.get("name") == op["part"]
					for mesh: Dictionary in layouts[facing].get("joint_meshes", []):
						if mesh.get("replaces_part") == op["part"]:
							var base: Texture2D = AssetLoader.load_texture_source_first(mesh["file"])
							if base == null or base.get_size() != texture.get_size():
								return false
					if not found:
						return false
				else:
					if slot not in ["offhand", "trinket"] or not op.get("name") is String or not _valid_point(op.get("offset")):
						return false
					if not layouts[facing].get("joints", {}).has(op.get("bone", "")) or not (op.get("z_index") is float or op.get("z_index") is int):
						return false
					if float(op["z_index"]) != float(int(op["z_index"])) or int(op["z_index"]) < RenderingServer.CANVAS_ITEM_Z_MIN or int(op["z_index"]) > RenderingServer.CANVAS_ITEM_Z_MAX:
						return false
					if not _valid_hide(op.get("hide_in_clips", [])):
						return false
	return true

static func resolve(equipped: Dictionary) -> Dictionary:
	_load()
	var resolved: Dictionary = {}
	for slot: String in SLOTS:
		var id: String = str(equipped.get(slot, ""))
		if id.is_empty():
			resolved[slot] = "" if slot in ["offhand", "trinket"] else _defaults[slot]
		else:
			resolved[slot] = id if _items.has(id) and _items[id]["slot"] == slot else _defaults[slot]
	return resolved

static func signature(equipped: Dictionary) -> String:
	var resolved: Dictionary = resolve(equipped)
	var values: PackedStringArray = []
	for slot: String in SLOTS:
		values.append(slot + "=" + str(resolved[slot]))
	return "|".join(values)

static func weapon_motion(equipped: Dictionary) -> String:
	return str(_items.get(resolve(equipped)["weapon"], {}).get("motion", "sword"))

static func is_two_handed(equipped: Dictionary) -> bool:
	return int(_items.get(resolve(equipped)["weapon"], {}).get("hands", 1)) == 2

static func offhand_kind(equipped: Dictionary) -> String:
	if is_two_handed(equipped):
		return ""
	return str(_items.get(resolve(equipped)["offhand"], {}).get("held", ""))

static func ops_for_facing(equipped: Dictionary, facing: String) -> Dictionary:
	var resolved: Dictionary = resolve(equipped)
	var replacements: Array = []
	var attachments: Array = []
	var grip: Dictionary = {}
	for slot: String in SLOTS:
		if slot == "offhand" and is_two_handed(resolved):
			continue
		var id: String = resolved[slot]
		var entry: Dictionary = _items.get(id, {})
		var ops: Dictionary = entry.get("facings", {}).get(facing, {})
		for kind: String in ["replace", "attach"]:
			for op: Dictionary in ops.get(kind, []):
				var prepared: Dictionary = op.duplicate(true)
				prepared["item_id"] = id
				if kind == "attach":
					prepared["hide_in_clips"] = op.get("hide_in_clips", entry.get("hide_in_clips", [])).duplicate()
					attachments.append(prepared)
				else:
					replacements.append(prepared)
		if slot == "weapon":
			grip = ops.get("weapon_grip", {}).duplicate(true)
	return {"replace": replacements, "attach": attachments, "weapon_grip": grip}
