extends RefCounted
class_name GrimoireSearch

const _TITLE_EXACT_BOOST: int = 1200
const _TITLE_PREFIX_BOOST: int = 760
const _TITLE_PHRASE_BOOST: int = 760
const _ALIAS_EXACT_BOOST: int = 700
const _ALIAS_PHRASE_BOOST: int = 430
const _TOPIC_PHRASE_BOOST: int = 260
const _RULES_PHRASE_BOOST: int = 180

static func search(entries: Array, sections: Array, query: String) -> Array[Dictionary]:
	var normalized_query: String = normalize(query)
	if normalized_query.is_empty():
		return []
	var query_tokens: PackedStringArray = normalized_query.split(" ", false)
	var section_titles: Dictionary = _section_title_lookup(sections)
	var results: Array[Dictionary] = []
	for entry_var: Variant in entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var scored: Dictionary = _score_entry(entry_var as Dictionary, normalized_query, query_tokens, section_titles)
		if not scored.is_empty():
			results.append(scored)
	results.sort_custom(_result_before)
	return results

static func normalize(value: String) -> String:
	var lowered: String = value.to_lower()
	var normalized: String = ""
	for index: int in range(lowered.length()):
		var codepoint: int = lowered.unicode_at(index)
		var is_ascii_letter: bool = codepoint >= 97 and codepoint <= 122
		var is_digit: bool = codepoint >= 48 and codepoint <= 57
		var is_unicode_separator: bool = codepoint == 160 \
				or (codepoint >= 0x2000 and codepoint <= 0x206F)
		if is_ascii_letter or is_digit or (codepoint >= 128 and not is_unicode_separator):
			normalized += String.chr(codepoint)
		else:
			normalized += " "
	return " ".join(normalized.split(" ", false))

static func _score_entry(entry: Dictionary, query: String, query_tokens: PackedStringArray, section_titles: Dictionary) -> Dictionary:
	var title: String = str(entry.get("title", entry.get("id", "")))
	var title_text: String = normalize(title)
	var aliases_text: String = normalize(" ".join(_string_values(entry.get("aliases", []))))
	var section_id: String = str(entry.get("section", ""))
	var topic_text: String = normalize(" ".join([
		str(section_titles.get(section_id, section_id)),
		str(entry.get("group_title", entry.get("group", ""))),
		str(entry.get("id", "")),
		str(entry.get("card_id", "")),
		str(entry.get("equipment_id", "")),
		str(entry.get("npc_id", "")),
		str(entry.get("enemy_id", ""))
	]))
	var rules_text: String = normalize(" ".join(_string_values(entry.get("body", []))))
	var title_words: PackedStringArray = title_text.split(" ", false)
	var alias_words: PackedStringArray = aliases_text.split(" ", false)
	var topic_words: PackedStringArray = topic_text.split(" ", false)
	var rules_words: PackedStringArray = rules_text.split(" ", false)
	var score: int = 0
	var matched_kinds: Array[String] = []
	var relied_on_fuzzy: bool = false
	for query_token: String in query_tokens:
		var token_match: Dictionary = _best_token_match(query_token, title_words, alias_words, topic_words, rules_words)
		if token_match.is_empty():
			return {}
		score += int(token_match.get("score", 0))
		var kind: String = str(token_match.get("kind", "rules"))
		if not matched_kinds.has(kind):
			matched_kinds.append(kind)
		relied_on_fuzzy = relied_on_fuzzy or bool(token_match.get("fuzzy", false))
	if title_text == query:
		score += _TITLE_EXACT_BOOST
	elif title_text.begins_with(query):
		score += _TITLE_PREFIX_BOOST
	elif title_text.contains(query):
		score += _TITLE_PHRASE_BOOST
	if not aliases_text.is_empty():
		if _phrase_list_contains(aliases_text, query):
			score += _ALIAS_EXACT_BOOST
		elif aliases_text.contains(query):
			score += _ALIAS_PHRASE_BOOST
	if not topic_text.is_empty() and topic_text.contains(query):
		score += _TOPIC_PHRASE_BOOST
	if not rules_text.is_empty() and rules_text.contains(query):
		score += _RULES_PHRASE_BOOST
	var match_kind: String = _match_kind(matched_kinds, relied_on_fuzzy)
	return {
		"entry": entry,
		"score": score,
		"match_kind": match_kind,
		"breadcrumb": _breadcrumb(entry, section_titles)
	}

static func _best_token_match(query_token: String, title_words: PackedStringArray, alias_words: PackedStringArray, topic_words: PackedStringArray, rules_words: PackedStringArray) -> Dictionary:
	var candidates: Array[Dictionary] = []
	_append_field_match(candidates, query_token, title_words, "title", 180, 150, 118)
	_append_field_match(candidates, query_token, alias_words, "alias", 145, 122, 96)
	_append_field_match(candidates, query_token, topic_words, "topic", 112, 94, 76)
	_append_field_match(candidates, query_token, rules_words, "rules", 82, 68, 54)
	if candidates.is_empty() and query_token.length() >= 4:
		_append_fuzzy_match(candidates, query_token, title_words, "title", 92)
		_append_fuzzy_match(candidates, query_token, alias_words, "alias", 76)
		_append_fuzzy_match(candidates, query_token, topic_words, "topic", 58)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("score", 0)) > int(b.get("score", 0)))
	return candidates[0]

static func _append_field_match(candidates: Array[Dictionary], query_token: String, words: PackedStringArray, kind: String, exact_score: int, prefix_score: int, contains_score: int) -> void:
	var best: int = 0
	for word: String in words:
		if word == query_token:
			best = maxi(best, exact_score)
		elif query_token.length() >= 2 and word.begins_with(query_token):
			best = maxi(best, prefix_score)
		elif query_token.length() >= 3 and word.contains(query_token):
			best = maxi(best, contains_score)
	if best > 0:
		candidates.append({"score": best, "kind": kind, "fuzzy": false})

static func _append_fuzzy_match(candidates: Array[Dictionary], query_token: String, words: PackedStringArray, kind: String, base_score: int) -> void:
	var allowed_distance: int = 2 if query_token.length() >= 8 else 1
	var best_distance: int = allowed_distance + 1
	for word: String in words:
		if absi(word.length() - query_token.length()) > allowed_distance:
			continue
		var distance: int = _damerau_levenshtein(query_token, word, allowed_distance)
		best_distance = mini(best_distance, distance)
	if best_distance <= allowed_distance:
		candidates.append({
			"score": base_score - best_distance * 18,
			"kind": kind,
			"fuzzy": true
		})

static func _damerau_levenshtein(left: String, right: String, limit: int) -> int:
	if left == right:
		return 0
	if absi(left.length() - right.length()) > limit:
		return limit + 1
	var previous_previous: Array[int] = []
	var previous: Array[int] = []
	for column: int in range(right.length() + 1):
		previous.append(column)
	for row: int in range(1, left.length() + 1):
		var current: Array[int] = [row]
		var row_minimum: int = row
		for column: int in range(1, right.length() + 1):
			var substitution_cost: int = 0 if left.unicode_at(row - 1) == right.unicode_at(column - 1) else 1
			var value: int = mini(
				mini(current[column - 1] + 1, previous[column] + 1),
				previous[column - 1] + substitution_cost
			)
			if row > 1 and column > 1 \
					and left.unicode_at(row - 1) == right.unicode_at(column - 2) \
					and left.unicode_at(row - 2) == right.unicode_at(column - 1):
				value = mini(value, previous_previous[column - 2] + 1)
			current.append(value)
			row_minimum = mini(row_minimum, value)
		if row_minimum > limit:
			return limit + 1
		previous_previous = previous
		previous = current
	return previous[right.length()]

static func _section_title_lookup(sections: Array) -> Dictionary:
	var result: Dictionary = {}
	for section_var: Variant in sections:
		if typeof(section_var) != TYPE_DICTIONARY:
			continue
		var section: Dictionary = section_var as Dictionary
		result[str(section.get("id", ""))] = str(section.get("title", section.get("id", "")))
	return result

static func _breadcrumb(entry: Dictionary, section_titles: Dictionary) -> String:
	var parts: Array[String] = []
	var section_id: String = str(entry.get("section", ""))
	var section_title: String = str(section_titles.get(section_id, section_id.capitalize()))
	if not section_title.is_empty():
		parts.append(section_title)
	var group_title: String = str(entry.get("group_title", ""))
	if not group_title.is_empty() and group_title != section_title:
		parts.append(group_title)
	return " · ".join(parts)

static func _match_kind(kinds: Array[String], relied_on_fuzzy: bool) -> String:
	if relied_on_fuzzy:
		return "close"
	if kinds.has("title"):
		return "title"
	if kinds.has("alias"):
		return "alias"
	if kinds.has("topic"):
		return "topic"
	return "rules"

static func _phrase_list_contains(normalized_values: String, query: String) -> bool:
	if normalized_values == query:
		return true
	return (" %s " % normalized_values).contains(" %s " % query)

static func _string_values(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			var text: String = str(item).strip_edges()
			if not text.is_empty():
				result.append(text)
	else:
		var text: String = str(value).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result

static func _result_before(left: Dictionary, right: Dictionary) -> bool:
	var left_score: int = int(left.get("score", 0))
	var right_score: int = int(right.get("score", 0))
	if left_score != right_score:
		return left_score > right_score
	var left_entry: Dictionary = left.get("entry", {}) as Dictionary
	var right_entry: Dictionary = right.get("entry", {}) as Dictionary
	return str(left_entry.get("title", "")).naturalnocasecmp_to(str(right_entry.get("title", ""))) < 0
