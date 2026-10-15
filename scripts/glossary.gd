extends RefCounted

## Canonical copy only. Icon rendering stays in ActionIconLibrary, avoiding a
## preload cycle and preserving contextual token explanations and card layout.
const DATA_PATH: String = "res://data/glossary.json"
const MAX_RELIC_PANELS: int = 6
# The unmarked sentence "Consume [Rubble] ..." is surface removal, while the
# named Consume keyword means using an item. Await an explicit design token;
# never attach the item definition to an ambiguous prose verb.
const TODO_DESIGN_GLOSSARY_CONSUME_PROSE: String = "Consume"

static var _entries: Dictionary = {}
static var _aliases: Dictionary = {}
static var _terms: Array[Dictionary]
static var _loaded: bool = false
static var _missing_definitions: Dictionary = {}

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Glossary must contain an array of entries")
		return
	var candidates: Dictionary = {}
	for value: Variant in parsed:
		var entry: Dictionary = value as Dictionary
		var id: String = str(entry.get("id", ""))
		_entries[id] = entry
		var terms: Array = [str(entry.get("name", ""))]
		terms.append_array(entry.get("aliases", []) as Array)
		for term_var: Variant in terms:
			var term: String = str(term_var)
			# Ambiguous names (Fire/Ice element versus ground) require an icon
			# token. Never silently assign one concept's definition to another.
			candidates[term] = id if not candidates.has(term) or candidates[term] == id else ""
		for alias: String in entry.get("aliases", []):
			_aliases[alias.to_lower()] = id
	for term: String in candidates:
		if term.is_empty() or str(candidates[term]).is_empty():
			continue
		_aliases[term.to_lower()] = candidates[term]
		if term == TODO_DESIGN_GLOSSARY_CONSUME_PROSE:
			continue
		var pattern := RegEx.new()
		# Match authored keyword spelling. Ordinary "time", "swap", "consume"
		# and "next attack" prose must not acquire unrelated mechanic panels.
		pattern.compile("(?<![\\w])" + _escape_regex(term) + "(?![\\w])")
		_terms.append({"id": candidates[term], "pattern": pattern})

static func _escape_regex(text: String) -> String:
	var escaped: String = ""
	for character: String in text:
		if character in "\\.^$|?*+()[]{}":
			escaped += "\\"
		escaped += character
	return escaped

static func lookup(id_or_alias: String) -> Dictionary:
	_ensure_loaded()
	var key: String = id_or_alias.to_lower()
	return (_entries.get(key if _entries.has(key) else str(_aliases.get(key, key)), {}) as Dictionary).duplicate(true)

static func all_entries() -> Array:
	_ensure_loaded()
	return _entries.values().duplicate(true)

static func definition(id: String, fallback_label: String = "") -> String:
	var entry: Dictionary = lookup(id)
	var text: String = str(entry.get("definition", "")).strip_edges()
	if not text.is_empty():
		return text
	var key: String = str(entry.get("id", id)).to_lower()
	if not _missing_definitions.has(key):
		_missing_definitions[key] = true
		push_warning("Missing glossary definition: " + key)
	return name_for(id, fallback_label)

static func name_for(id: String, fallback_label: String = "") -> String:
	var label: String = str(lookup(id).get("name", "")).strip_edges()
	return label if not label.is_empty() else (fallback_label if not fallback_label.is_empty() else id.capitalize())

## Merge explicit icon tokens and written keywords in first appearance order.
## Longer phrases win at the same position (Health Cost before Health).
static func ids_in_text(text: String, limit: int = 0) -> Array[String]:
	_ensure_loaded()
	var matches: Array[Dictionary]
	var tokens := RegEx.new()
	tokens.compile("@icon\\(([^)]+)\\)")
	var plain: String = text
	for found: RegExMatch in tokens.search_all(text):
		var entry: Dictionary = lookup(found.get_string(1))
		matches.append({"id": entry.get("id", found.get_string(1)), "start": found.get_start(), "end": found.get_end()})
		plain = plain.substr(0, found.get_start()) + " ".repeat(found.get_end() - found.get_start()) + plain.substr(found.get_end())
	# BBCode metadata is not player-visible prose.
	var tags := RegEx.new()
	tags.compile("\\[[^\\]]*\\]")
	for found: RegExMatch in tags.search_all(plain):
		plain = plain.substr(0, found.get_start()) + " ".repeat(found.get_end() - found.get_start()) + plain.substr(found.get_end())
	for term: Dictionary in _terms:
		for found: RegExMatch in (term["pattern"] as RegEx).search_all(plain):
			matches.append({"id": term["id"], "start": found.get_start(), "end": found.get_end()})
	matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["start"]) < int(b["start"]) if a["start"] != b["start"] else int(a["end"]) > int(b["end"]))
	var result: Array[String]
	var consumed_end: int = -1
	for found: Dictionary in matches:
		if int(found["start"]) < consumed_end:
			continue
		consumed_end = int(found["end"])
		var id: String = str(found["id"])
		if not result.has(id):
			result.append(id)
		if limit > 0 and result.size() >= limit:
			break
	return result
