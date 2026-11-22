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
		if source.get("kind") == "grimoire":
			if (row.get("grimoire_entries", []) as Array).has(source.get("id", "")): return row
			continue
		var kind: String = str(match_source["kind"])
		if kind == "*": return row
		var source_kind: String = str(source.get("kind", ""))
		if source_kind != kind and not match_source.get("also_kinds", []).has(source_kind): continue
		if match_source.has("id") and str(source.get("id", "")) != str(match_source["id"]): continue
		if match_source.has("ids") and not match_source["ids"].has(source.get("id")): continue
		if match_source.has("variant") and match_source["variant"] != source.get("variant"): continue
		if match_source.has("element") and str(source.get("element", "")) != str(match_source["element"]): continue
		return row
	return {}

static func grimoire_term(entry_id: String) -> String:
	for row: Dictionary in entries():
		if row.has("todo_design") or not row.get("grimoire_entries", []).has(entry_id): continue
		var term: String = entry_id.get_slice(":", 1)
		return term if row.get("aliases", []).has(term) else str(row["term"])
	return ""

static func has_source(source: Dictionary) -> bool:
	for row: Dictionary in entries():
		if row.has("todo_design") or row.get("keyword_only", false): continue
		if row["source_match"].get("kind") == "enemy" and row["source_match"].get("id") == source.get("id") and source.get("kind") == "enemy": return true
	return false
