extends RefCounted
## Source identity is required: shared terms must never borrow another actor's demo.
const PATH: String = "res://data/tooltip_loops.json"
static var _rows: Array = []

static func entries() -> Array:
	if _rows.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary: _rows = parsed.get("loops", [])
	return _rows

static func find(term: String, source: Dictionary) -> Dictionary:
	for row: Dictionary in entries():
		if term != row["term"] and not (row.get("aliases", []) as Array).has(term): continue
		var match_source: Dictionary = row["source_match"]
		if str(source.get("kind", "")) != str(match_source["kind"]): continue
		if match_source.has("id") and str(source.get("id", "")) != str(match_source["id"]): continue
		return row
	return {}

static func has_source(source: Dictionary) -> bool:
	for row: Dictionary in entries():
		if not find(str(row["term"]), source).is_empty(): return true
	return false
