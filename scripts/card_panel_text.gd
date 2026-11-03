extends RefCounted
## Card copy is data-owned. The legacy tooltip remains on shared action tokens
## for enemy intent; only card focus assembly reads card_tooltip/card_title.
const Glossary = preload("res://scripts/glossary.gd")
const DATA_PATH: String = "res://data/card_panel_text.json"
static var _templates: Dictionary = {}
static var _loaded: bool = false
static var _counted_tiles: RegEx

static func copy(id: String, values: Dictionary = {}, glossary_override: String = "") -> Dictionary:
	if not _loaded:
		_loaded = true
		_templates = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) as Dictionary
		_counted_tiles = RegEx.new()
		_counted_tiles.compile("\\{(\\w+)\\} tiles\\b")
	assert(_templates.has(id), "Missing card panel template: " + id)
	var template: Dictionary = _templates.get(id, {})
	var term: String = glossary_override if not glossary_override.is_empty() else str(template.get("term", ""))
	var title: String = Glossary.name_for(term) if not glossary_override.is_empty() else str(template.get("title", ""))
	var text: String = Glossary.definition(term) if template.get("text") == null or not glossary_override.is_empty() else _format_card_text(str(template["text"]), values)
	return {
		"tooltip": str(template.get("legacy", template.get("text", ""))).format(values),
		"card_tooltip": (title + "\n" if not title.is_empty() else "") + text,
		"card_title": title,
		"card_term": term,
		"panel_id": id,
	}

static func _format_card_text(template: String, values: Dictionary) -> String:
	var text: String = template
	for counted: RegExMatch in _counted_tiles.search_all(template):
		var key: String = counted.get_string(1)
		if values.get(key, 0) == 1:
			text = text.replace(counted.get_string(), "{%s} tile" % key)
	return text.format(values)

static func join_names(names: PackedStringArray) -> String:
	if names.size() < 2:
		return ", ".join(names)
	var leading: PackedStringArray = names.slice(0, names.size() - 1)
	return "%s and %s" % [", ".join(leading), names[names.size() - 1]]
