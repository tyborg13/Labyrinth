extends RefCounted

# Raw resolver chronology, independent of presentation traces and step arrays.
# A child seals its parent's realized work; no-op children allow the same owner
# to finish in one entry. Only the existing deferred-field encoder is shared.
var encode: Callable
var raw_events: Array[Dictionary]
var events: Array[Dictionary]
var stack: Array[Dictionary]
var next_token: int = 0
var action_count: int = 0
var bleed_paid: bool = false

func observe(event: String, state: Dictionary, owner: Dictionary) -> void:
	match event:
		"begin":
			seal(state)
			next_token += 1
			stack.append({"token": next_token, "owner": owner.duplicate(true), "cursor": encode.call(state)})
			if owner["kind"] == "action": action_count += 1
			if owner["kind"] in ["bleed_move", "bleed_attack"]: bleed_paid = true
		"checkpoint": seal(state)
		"end":
			seal(state, not stack.is_empty() and stack.back()["owner"]["kind"] == "action")
			assert(not stack.is_empty(), "Independent resolver journal scope is balanced")
			stack.pop_back()
			if not stack.is_empty(): stack.back()["cursor"] = encode.call(state)
		"instant": instant(state, owner)

func seal(state: Dictionary, force: bool = false) -> void:
	if stack.is_empty(): return
	var scope: Dictionary = stack.back()
	var value: String = encode.call(state)
	if not force and scope["cursor"] == value: return
	var entry: Dictionary = {"sequence": raw_events.size() + 1, "token": scope["token"], "owner": scope["owner"], "state": state.duplicate(true), "serialized": value, "complete": false}
	raw_events.append(entry)
	if not events.is_empty() and events.back()["token"] == scope["token"]: events[-1] = entry
	else: events.append(entry)
	scope["cursor"] = value

func instant(state: Dictionary, owner: Dictionary, complete: bool = false) -> void:
	next_token += 1
	var entry: Dictionary = {"sequence": raw_events.size() + 1, "token": next_token, "owner": owner.duplicate(true), "state": state.duplicate(true), "serialized": encode.call(state, complete), "complete": complete}
	raw_events.append(entry)
	events.append(entry)

func finish_movement(first: int, paid: bool) -> void:
	# An uninterrupted unpaid walk has one embedded move. Paid or interrupted
	# walks retain each arrival interval, including resumed movement after deaths.
	var span: Array = events.slice(first)
	if paid or span.is_empty() or span.any(func(entry: Dictionary) -> bool: return entry["owner"]["kind"] != "move"): return
	var final: Dictionary = events.back()
	events.resize(first)
	events.append(final)
