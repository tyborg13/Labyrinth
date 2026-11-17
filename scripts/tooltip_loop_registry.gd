extends RefCounted
## Source identity is required: shared terms must never borrow another actor's demo.
const PATH: String = "res://data/tooltip_loops.json"
static var _rows: Array = []
# Counterfactual capture only: preserve term routing, text and icons.
static var proof_media_disabled: bool = false

static func media_available(row: Dictionary) -> bool:
	return not proof_media_disabled and not row.is_empty() and FileAccess.file_exists(str(row["asset_path"]))

static func entries() -> Array:
	if _rows.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary: _rows = parsed.get("loops", [])
	return _rows

static func find(term: String, source: Dictionary) -> Dictionary:
	for row: Dictionary in entries():
		if row.has("todo_design"): continue
		if term != row["term"] and not (row.get("aliases", []) as Array).has(term): continue
		var match_source: Dictionary = row["source_match"]
		if (row.get("global_terms", []) as Array).has(term): return row
		if str(match_source["kind"]) == "*": return row
		if str(source.get("kind", "")) != str(match_source["kind"]): continue
		if match_source.has("id") and str(source.get("id", "")) != str(match_source["id"]): continue
		if match_source.has("element") and str(source.get("element", "")) != str(match_source["element"]): continue
		return row
	return {}

static func has_source(source: Dictionary) -> bool:
	for row: Dictionary in entries():
		if row.has("todo_design"): continue
		if row["source_match"].get("kind") == "enemy" and row["source_match"].get("id") == source.get("id") and source.get("kind") == "enemy": return true
	return false
