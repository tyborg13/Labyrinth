extends RefCounted

## pla-02: a hand card's Draw chip shows how many cards it will really draw.
## The played card stays in hand while its draw resolves, so the 7-card hand
## leaves room for 7 minus the hand size; the draw and discard piles together
## bound the rest (a reshuffle refills the draw pile). The rule itself lives in
## CombatEngine._draw_cards_in_place; this only reads the same inputs.
## Presentation only: the card definition and combat state are unchanged.
const Combat = preload("res://scripts/combat_engine.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")

static func apply(display: Dictionary, card_id: String, state: Dictionary) -> Dictionary:
	var deck: Dictionary = state.get("deck", {}) as Dictionary
	var hand: Array = deck.get("hand", []) as Array
	if not hand.has(card_id): return display
	var room: int = maxi(0, Combat.MAX_HAND_SIZE - hand.size())
	var left: int = (deck.get("draw", []) as Array).size() + (deck.get("discard", []) as Array).size()
	var rows: Array = display.get("summary_rows", []) as Array
	var changed: bool = false
	var result_rows: Array = []
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			result_rows.append(row_var)
			continue
		var result_row: Array = []
		for token_var: Variant in row_var:
			if not _is_draw_amount(token_var):
				result_row.append(token_var)
				continue
			var token: Dictionary = token_var
			var printed: int = int(token["value"])
			var actual: int = clampi(mini(room, left), 0, printed)
			if actual < printed:
				token = _capped(token, printed, actual, room <= left, left)
				changed = true
			room -= actual
			left -= actual
			result_row.append(token)
		result_rows.append(result_row)
	if not changed: return display
	var result: Dictionary = display.duplicate(false)
	result["summary_rows"] = result_rows
	result["summary_bbcode"] = ActionIcons.plain_text_for_rows(result_rows)
	return result

static func _is_draw_amount(token: Variant) -> bool:
	if typeof(token) != TYPE_DICTIONARY: return false
	var entry: Dictionary = token
	return str(entry.get("icon", "")) == "draw" and str(entry.get("field", "")) == "amount" and typeof(entry.get("value")) in [TYPE_INT, TYPE_FLOAT] and int(entry["value"]) > 0

static func _capped(token: Dictionary, printed: int, actual: int, hand_full: bool, left: int) -> Dictionary:
	var capped: Dictionary = token.duplicate(true)
	capped["value"] = actual
	capped["tone"] = "penalty"
	capped["modified"] = true
	if not capped.has("base_value"): capped["base_value"] = printed
	var modifiers: Array = (capped.get("modifiers", []) as Array).duplicate(true)
	if hand_full:
		modifiers.append({"source": "Hand limit", "kind": "rule", "amount": actual - printed, "detail": "Your hand holds at most %d" % Combat.MAX_HAND_SIZE})
	else:
		modifiers.append({"source": "Cards left", "kind": "rule", "amount": actual - printed, "detail": "%d in your draw and discard piles" % maxi(0, left)})
	capped["modifiers"] = modifiers
	return capped
