extends RefCounted

## Canonical copy only. Icon rendering stays in ActionIconLibrary, avoiding a
## preload cycle and preserving contextual token explanations and card layout.
const DATA_PATH: String = "res://data/glossary.json"
const MAX_RELIC_PANELS: int = 6
const TokenSyntax = preload("res://scripts/inline_token_syntax.gd")

static var _entries: Dictionary = {}
static var _aliases: Dictionary = {}
static var _terms: Array[Dictionary]
static var _loaded: bool = false
static var _missing_definitions: Dictionary = {}
static var _amount_placeholder := RegEx.create_from_string("\\bX\\b")
static var _amount_article := RegEx.create_from_string("\\b([Aa])n? X\\b")
static var _following_amount := RegEx.create_from_string("^\\s+[+]?(\\d+)(?![\\w%]|\\.\\d)")
static var _preceding_amount := RegEx.create_from_string("(?<![\\w.-])[+]?(\\d+)\\s+$")

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

# Internal read-only view: hot label/definition reads must not deep-copy entries.
static func _entry(id_or_alias: String) -> Dictionary:
	_ensure_loaded()
	var key: String = id_or_alias.to_lower()
	return _entries.get(key if _entries.has(key) else str(_aliases.get(key, key)), {}) as Dictionary

static func lookup(id_or_alias: String) -> Dictionary:
	return _entry(id_or_alias).duplicate(true)

static func all_entries() -> Array:
	_ensure_loaded()
	return _entries.values().duplicate(true)

static func definition(id: String, fallback_label: String = "", amount: Variant = null) -> String:
	var entry: Dictionary = _entry(id)
	var text: String = str(entry.get("definition", "")).strip_edges()
	if not text.is_empty():
		return fill_amount(text, amount)
	var key: String = str(entry.get("id", id)).to_lower()
	if not _missing_definitions.has(key):
		_missing_definitions[key] = true
		push_warning("Missing glossary definition: " + key)
	return name_for(id, fallback_label)

## Replace the standalone rules placeholder without changing names or markup.
static func fill_amount(text: String, amount: Variant) -> String:
	if not text.contains("X"):
		return text
	var number: String = ""
	match typeof(amount):
		TYPE_INT, TYPE_FLOAT:
			number = str(int(amount)) if float(amount) == floorf(float(amount)) else str(amount)
		TYPE_STRING:
			var numeric: String = str(amount).replace("−", "-")
			if numeric.is_valid_int(): number = str(int(numeric))
	if number.is_empty():
		return text
	if number == "1":
		text = text.replace("your next X turns", "your next turn")
		for unit: String in ["tile", "card", "turn"]:
			text = text.replace("X %ss" % unit, "X %s" % unit)
	var articles: Array[RegExMatch] = _amount_article.search_all(text)
	for index: int in range(articles.size() - 1, -1, -1):
		var found: RegExMatch = articles[index]
		text = text.substr(0, found.get_start()) + with_article(number, found.get_string(1) == "A") + text.substr(found.get_end())
	return _amount_placeholder.sub(text, number, true)

## Dynamic rules terms are English names or displayed numbers.
static func with_article(phrase: String, capitalized: bool = false) -> String:
	var first: String = phrase.to_lower().get_slice(" ", 0)
	var spoken: String = first.trim_prefix("+").trim_prefix("-").trim_prefix("−")
	var vowel: bool = not spoken.is_empty() and spoken[0] in "aeiou"
	if spoken.get_slice(".", 0).is_valid_int():
		vowel = spoken.begins_with("8") or spoken.get_slice(".", 0) in ["11", "18"]
	elif spoken == "x" or spoken.begins_with("hour") or spoken.begins_with("honest"):
		vowel = true
	elif spoken.begins_with("one") or spoken.begins_with("unit") or spoken.begins_with("uniq") or spoken.begins_with("use"):
		vowel = false
	var article: String = "an" if vowel else "a"
	return (article.capitalize() if capitalized else article) + " " + phrase

static func enemy_name_in_prose(enemy_type: String, enemy_name: String, use_short_name: bool = false) -> String:
	if preload("res://scripts/dragon_boss_library.gd").is_dragon_boss_id(enemy_type):
		return enemy_name.get_slice(", the ", 0) if use_short_name else enemy_name
	return with_article(enemy_name)

## Read a term's printed amount in authored relic copy. Competing amounts
## leave the shared definition generic.
static func amount_in_text(id: String, text: String) -> Variant:
	if not str(_entry(id).get("definition", "")).contains("X"):
		return null
	var amounts: Dictionary = {}
	var plain: String = text
	for token: RegExMatch in TokenSyntax.tokens(text):
		if str(_entry(token.get_string(2)).get("id", "")) == id:
			_collect_text_amount(text, token, amounts)
		plain = plain.substr(0, token.get_start()) + " ".repeat(token.get_end() - token.get_start()) + plain.substr(token.get_end())
	for term: Dictionary in _terms:
		if term["id"] != id: continue
		for token: RegExMatch in (term["pattern"] as RegEx).search_all(plain):
			_collect_text_amount(text, token, amounts)
	return amounts.keys()[0] if amounts.size() == 1 else null

static func _collect_text_amount(text: String, token: RegExMatch, amounts: Dictionary) -> void:
	var after: RegExMatch = _following_amount.search(text.substr(token.get_end()))
	var before: RegExMatch = _preceding_amount.search(text.substr(0, token.get_start()))
	var found: RegExMatch = after if after != null else before
	if found != null:
		amounts[int(found.get_string(1))] = true

static func name_for(id: String, fallback_label: String = "") -> String:
	var label: String = str(_entry(id).get("name", "")).strip_edges()
	return label if not label.is_empty() else (fallback_label if not fallback_label.is_empty() else id.capitalize())

## Merge explicit icon tokens and written keywords in first appearance order.
## Longer phrases win at the same position (Health Cost before Health).
static func ids_in_text(text: String, limit: int = 0) -> Array[String]:
	_ensure_loaded()
	var matches: Array[Dictionary]
	var plain: String = text
	for found: RegExMatch in TokenSyntax.tokens(text):
		var entry: Dictionary = _entry(found.get_string(2))
		matches.append({"id": entry.get("id", found.get_string(2)), "start": found.get_start(), "end": found.get_end()})
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
