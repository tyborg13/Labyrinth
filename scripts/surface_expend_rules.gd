extends RefCounted

## Shared source identity, independent of GameData to avoid its rules preload cycle.
const Icons = preload("res://scripts/action_icon_library.gd")
const Tokens = preload("res://scripts/inline_token_syntax.gd")
const KEYWORD: String = "surface_consume"
const CARD_TAG: String = "_card_surface_consume"
static var _expend_word: RegEx

static func is_trap_source(source: Dictionary) -> bool:
	return str(source.get("source_kind", "")) == "trap" or str(source.get("causal_source_kind", "")) == "trap"

static func definition_uses_expend(definition: Dictionary) -> bool:
	if definition.is_empty(): return false
	var text: String = str(definition.get("description", ""))
	for token: RegExMatch in Tokens.tokens(text):
		if token.get_string(2) == KEYWORD: return true
	# Some authored cards (including Magma Vent) still use plain-word copy.
	if _expend_word == null:
		_expend_word = RegEx.new()
		_expend_word.compile("(?i)\\bexpend(?:s|ed|ing)?\\b")
	if _expend_word.search(text) != null: return true
	for row: Array in Icons.rows_for_card(definition):
		for token: Dictionary in row:
			if str(token.get("icon", "")) == KEYWORD: return true
	return false

static func card_source(source: Dictionary, definition: Dictionary, action: Dictionary) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	var shown: Dictionary = definition if not definition.is_empty() else {"actions": [action]}
	var tagged: bool = bool(action[CARD_TAG]) if action.has(CARD_TAG) else definition_uses_expend(shown)
	if tagged: result[KEYWORD] = true
	return result

static func relic_source(source: Dictionary, effect: Dictionary, definition: Dictionary) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	# Preserve the triggering card/source fields; identify the actual remover
	# additively, and override its tag even when the triggering card uses Expend.
	result["removal_relic_id"] = str(effect.get("relic_id", ""))
	result[KEYWORD] = definition_uses_expend(definition)
	return result
