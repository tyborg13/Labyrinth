extends RefCounted
## Sentence card faces (playability plan 2026-11-20, owner-approved round 5).
## data/card_faces.json maps a card id to {chip, sentence}:
##   chip: {icon: icon id or null, word, range} or null
##   extra_art_relief: optional additional art height the sentence can borrow at 250x352
##   sentence: ordered segments, each one of
##     {"text": "..."}                          words; a segment carries its own spaces
##     {"term": icon id, "word": "...", "number": n or null}
##     {"damage": "melee" | "ranged", "number": n}
##     {"number": n, "bind": key}              a live number in prose
##     {"pattern": pattern id}
##   bind: optional explicit key in a live row's face_values, also for damage
##   sentence_panels: keep only panels for words and tokens in the sentence
## Cards marked {"simple": true}, or absent from the file, use live icon rows.
##   duration: a Vision turn count in ordinary prose
## Simple faces specify row order. Icons and values come from the live rows.
## Cards absent from the file use their generated icon rows.

const PatternText = preload("res://scripts/pattern_text.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")

const DATA_PATH: String = "res://data/card_faces.json"
const DAMAGE_KINDS: Array = ["melee", "ranged"]
## Face pattern ids (card_faces_v5.json "patterns"): shape, extent, and
## whether the diagram marks the origin tile it is measured from.
const PATTERNS: Dictionary = {
	"neighbors": {"shape": "neighbors", "extent": 0, "origin": true},
	"cross": {"shape": "cross", "extent": 0, "origin": false},
	"diamond3": {"shape": "hollow_diamond", "extent": 3, "origin": true},
	"diamond2": {"shape": "diamond", "extent": 2, "origin": false},
	"diamond2_hollow": {"shape": "hollow_diamond", "extent": 2, "origin": true},
	"line3": {"shape": "line3", "extent": 0, "origin": false},
	"diagonals": {"shape": "diagonals", "extent": 0, "origin": true},
}

static var _faces: Dictionary = {}
static var _loaded: bool = false
static var _icons: Dictionary = {}

static func faces() -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_faces = parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}
	return _faces

static func spec_for(card_id: String) -> Dictionary:
	var spec: Variant = faces().get(card_id, null)
	return spec as Dictionary if typeof(spec) == TYPE_DICTIONARY and not bool(spec.get("simple", false)) else {}

## Tests and tools: replace the loaded table (an empty dictionary reloads the file).
static func override_faces(table: Dictionary) -> void:
	_faces = table.duplicate(true)
	_loaded = not table.is_empty()

static func uses_icon_rows(spec: Dictionary) -> bool:
	return spec.get("icon_rows") is Array

## Arrange the current rules tokens without freezing printed numbers. Added or
## replaced effects fall back to their native rows so they stay visible.
static func display_icon_rows(spec: Dictionary, live_rows: Array) -> Array:
	if not uses_icon_rows(spec):
		return live_rows
	var tokens: Array = []
	for row: Array in live_rows:
		for token: Dictionary in row:
			if str(token.get("icon", "")) == "pierce" and str(token.get("field", "")) == "damage":
				var damage: Dictionary = token.duplicate()
				damage["icon"] = "melee"
				tokens.append(damage)
				tokens.append(ActionIcons.token_for("pierce"))
			else:
				tokens.append(token)
	var result: Array = []
	for names: Array in spec["icon_rows"]:
		var row: Array = []
		for icon: String in names:
			if icon == ":":
				row.append(ActionIcons.text_token(":"))
				continue
			var index: int = _live_token_index(tokens, icon)
			if index < 0:
				return live_rows
			var token: Dictionary = tokens.pop_at(index)
			if token.get("icon") != icon:
				token = token.duplicate()
				token["icon"] = icon
			row.append(token)
		result.append(row)
	return result if tokens.is_empty() else live_rows

static func _live_token_index(tokens: Array, icon: String) -> int:
	for index: int in range(tokens.size()):
		if tokens[index].get("icon") == icon:
			return index
	if icon in DAMAGE_KINDS:
		for index: int in range(tokens.size()):
			if tokens[index].get("field") == "damage":
				return index
	return -1

static func pattern_offsets(pattern_id: String) -> Array:
	var entry: Dictionary = PATTERNS.get(pattern_id, {}) as Dictionary
	if entry.is_empty():
		return []
	var result: Array = []
	if pattern_id == "line3":
		return [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0)]
	if str(entry["shape"]) == "diagonals":
		result.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
		return result
	for offset: Vector2i in PatternText.offsets(str(entry["shape"]), int(entry["extent"])):
		result.append(offset)
	return result

static func pattern_shows_origin(pattern_id: String) -> bool:
	return bool((PATTERNS.get(pattern_id, {}) as Dictionary).get("origin", false))

## The icon's painted area (its alpha bounds) as a mipmapped texture. Inline
## icons are sized by visible height, as the approved mocks were; mipmaps keep
## a 64 px painting clean at the 12-15 px it is drawn at in a hand.
static func icon_entry(icon_key: String) -> Dictionary:
	if _icons.has(icon_key):
		return _icons[icon_key]
	var entry: Dictionary = {"texture": null, "aspect": 1.0}
	var source: Texture2D = ActionIcons.icon_texture(icon_key)
	if source != null:
		entry["texture"] = source
		var image: Image = source.get_image()
		if image != null and not image.is_empty():
			image = image.duplicate() as Image
			if image.is_compressed():
				image.decompress()
			var used: Rect2i = image.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				var cropped: Image = image.get_region(used)
				cropped.fix_alpha_edges()
				cropped.generate_mipmaps()
				entry["texture"] = ImageTexture.create_from_image(cropped)
				entry["aspect"] = float(used.size.x) / float(used.size.y)
		elif source.get_height() > 0:
			entry["aspect"] = float(source.get_width()) / float(source.get_height())
	_icons[icon_key] = entry
	return entry

## Reorder the live tokens only while every authored icon is still present.
## Modified values and tooltips travel with their tokens. Extra effects retain
## the ordinary generated layout.
static func ordered_icon_rows(card_id: String, live_rows: Array) -> Array:
	var rows: Array = spec_for(card_id).get("rows", [])
	if rows.is_empty():
		return live_rows
	var available: Array = []
	for live_row: Array in live_rows:
		available.append_array(live_row)
	var result: Array = []
	for row: Array in rows:
		var ordered: Array = []
		for expected: Dictionary in row:
			var found: int = available.find_custom(func(token: Dictionary) -> bool: return token.get("icon") == expected["icon"])
			if found < 0:
				return live_rows
			ordered.append(available.pop_at(found))
		result.append(ordered)
	return result if available.is_empty() else live_rows

## Problems with one face entry, for tests and the data check.
static func validate(card_id: String, spec: Dictionary) -> Array:
	var problems: Array = []
	if bool(spec.get("simple", false)):
		if spec.size() != 1:
			problems.append("%s: simple faces use live icon rows" % card_id)
		return problems
	if uses_icon_rows(spec):
		if spec.has("sentence") or spec.has("chip") or spec["icon_rows"].is_empty():
			problems.append("%s: icon-row faces need rows and cannot include a sentence or chip" % card_id)
		for row: Array in spec["icon_rows"]:
			for icon: String in row:
				if icon not in [":", "aoe_pattern"] and not ActionIcons.KEYWORDS.has(icon):
					problems.append("%s: unknown row icon %s" % [card_id, icon])
		return problems
	if spec.has("rows"):
		for row: Array in spec["rows"]:
			for token: Dictionary in row:
				if not ActionIcons.KEYWORDS.has(str(token.get("icon", ""))):
					problems.append("%s: unknown row icon %s" % [card_id, str(token.get("icon", ""))])
		return problems
	var chip: Variant = spec.get("chip", null)
	if chip != null:
		if typeof(chip) != TYPE_DICTIONARY:
			problems.append("%s: chip must be an object or null" % card_id)
		else:
			var chip_dict: Dictionary = chip
			if chip_dict.get("icon", null) != null and not ActionIcons.KEYWORDS.has(str(chip_dict["icon"])):
				problems.append("%s: unknown chip icon %s" % [card_id, str(chip_dict["icon"])])
			if str(chip_dict.get("word", "")).is_empty():
				problems.append("%s: chip needs a word" % card_id)
			if typeof(chip_dict.get("range", null)) not in [TYPE_INT, TYPE_FLOAT]:
				problems.append("%s: chip needs a numeric range" % card_id)
	var sentence: Variant = spec.get("sentence", null)
	if typeof(sentence) != TYPE_ARRAY or (sentence as Array).is_empty():
		problems.append("%s: sentence must be a non-empty array" % card_id)
		return problems
	var extra_art_relief: Variant = spec.get("extra_art_relief", 0.0)
	if typeof(extra_art_relief) not in [TYPE_INT, TYPE_FLOAT] or float(extra_art_relief) < 0.0:
		problems.append("%s: extra_art_relief must be a non-negative number" % card_id)
	for index: int in range((sentence as Array).size()):
		var segment_var: Variant = (sentence as Array)[index]
		if typeof(segment_var) != TYPE_DICTIONARY:
			problems.append("%s: segment %d is not an object" % [card_id, index])
			continue
		var segment: Dictionary = segment_var
		if segment.has("bind") and (str(segment["bind"]).is_empty() or typeof(segment.get("number")) not in [TYPE_INT, TYPE_FLOAT]):
			problems.append("%s: segment %d binding needs a key and a numeric value" % [card_id, index])
		if segment.has("text"):
			if segment.size() != 1 or str(segment["text"]).is_empty():
				problems.append("%s: segment %d text segment has extra keys or no text" % [card_id, index])
		elif segment.has("term"):
			if not ActionIcons.KEYWORDS.has(str(segment["term"])):
				problems.append("%s: segment %d unknown term icon %s" % [card_id, index, str(segment["term"])])
			if str(segment.get("word", "")).is_empty() or not segment.has("number"):
				problems.append("%s: segment %d term needs word and number (or null)" % [card_id, index])
			elif segment["number"] != null and typeof(segment["number"]) not in [TYPE_INT, TYPE_FLOAT]:
				problems.append("%s: segment %d term number must be numeric or null" % [card_id, index])
		elif segment.has("damage"):
			if not DAMAGE_KINDS.has(str(segment["damage"])):
				problems.append("%s: segment %d damage must be melee or ranged" % [card_id, index])
			if typeof(segment.get("number", null)) not in [TYPE_INT, TYPE_FLOAT]:
				problems.append("%s: segment %d damage needs a number" % [card_id, index])
		elif segment.has("duration"):
			if typeof(segment["duration"]) not in [TYPE_INT, TYPE_FLOAT]:
				problems.append("%s: segment %d duration must be numeric" % [card_id, index])
		elif segment.has("pattern"):
			if pattern_offsets(str(segment["pattern"])).is_empty():
				problems.append("%s: segment %d unknown pattern %s" % [card_id, index, str(segment["pattern"])])
		elif segment.has("number") and segment.has("bind"):
			pass
		else:
			problems.append("%s: segment %d has no known kind" % [card_id, index])
	return problems
