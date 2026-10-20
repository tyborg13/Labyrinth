extends RefCounted

# Presentation-only state. Explicit removals distinguish identical hand copies;
# observation retains surviving slots and never charges newly drawn cards.
var cards: Array = []
var charged: Array[bool]
var turn: int = -1
var staged_hand: Array = []
var staged_state: Dictionary = {}
var staged_previous_charged: Array[bool]

func observe(state: Dictionary) -> void:
	if not staged_state.is_empty():
		if state == staged_state: return
		cards = staged_hand
		staged_state = {}
		staged_previous_charged.clear()
	var hand: Array = (state.get("deck", {}) as Dictionary).get("hand", [])
	var next_turn: int = int(state.get("turn", -1))
	if state.is_empty() or next_turn != turn or bool(state.get("player_turn_ending", false)):
		cards = hand.duplicate()
		charged.clear()
		charged.resize(cards.size())
		charged.fill(false)
		turn = next_turn
		return
	if cards == hand:
		return
	var next_charged: Array[bool]
	var cursor: int = 0
	for id: Variant in hand:
		var found: int = cards.find(id, cursor)
		next_charged.append(charged[found] if found >= 0 else false)
		if found >= 0:
			cursor = found + 1
	cards = hand.duplicate()
	charged = next_charged

func is_charged(index: int) -> bool:
	var flags: Array[bool] = staged_previous_charged if not staged_state.is_empty() else charged
	return index >= 0 and index < flags.size() and flags[index]

func toggle(index: int) -> void:
	if index >= 0 and index < charged.size():
		charged[index] = not charged[index]

func remove(index: int, before_state: Dictionary) -> void:
	staged_state = before_state
	staged_previous_charged = charged.duplicate()
	if index >= 0 and index < staged_previous_charged.size(): staged_previous_charged[index] = false
	if index >= 0 and index < cards.size():
		cards.remove_at(index)
		charged.remove_at(index)
		staged_hand = cards.duplicate()
