extends RefCounted
class_name MovementUndoRules

## Exact paths only: unknown state (including new nested fields) fails closed.
const IGNORED_FIELDS: Dictionary = {
	"player.pos": "The walked position is restored by the snapshot.",
	"player.facing": "The walked facing is restored by the snapshot.",
	"player_movement_remaining": "The free movement expenditure is restored.",
	"last_player_movement.resolved": "Request resolution bookkeeping.",
	"last_player_movement.action_type": "Request kind bookkeeping.",
	"last_player_movement.origin": "Request path bookkeeping.",
	"last_player_movement.target": "Request path bookkeeping.",
	"last_player_movement.destination": "Request path bookkeeping.",
	"last_player_movement.spent": "Request pool bookkeeping.",
	"last_player_movement.light_refunds": "Request summary; actual refund flags/events are not ignored.",
	"last_player_movement.remaining_before": "Request pool bookkeeping.",
	"last_player_movement.remaining_after": "Request pool bookkeeping.",
	"last_player_movement.capacity": "Request pool bookkeeping; actual capacity is not ignored.",
	"last_player_movement.undo_report": "Pure derived reversibility report.",
	"last_action_target": "The resolver's target cursor is restored with the walk.",
	"last_action_target_actor": "The resolver's target cursor is restored with the walk.",
	"log": "The bounded presentation log includes the ordinary moved-to line.",
	"damage_context.actor_kind": "Resolver provenance for the current request.",
	"damage_context.actor_id": "Resolver provenance for the current request.",
	"damage_context.card_id": "Resolver provenance for the current request.",
	"damage_context.action_type": "Resolver provenance for the current request.",
	"damage_context.player_card": "Resolver provenance for the current request.",
	"damage_context.source_kind": "Resolver provenance for the current request.",
	"turn_flags.first_move_bonus_used": "Movement counter; restoring it also restores first-move eligibility.",
	"turn_flags.tiles_moved": "Movement counter; restoring it restores distance-based card previews.",
}

var _history: Array[Dictionary]
var _expected_state: Dictionary = {}
var last_walk_committed: bool = false

static func changed_fields(before: Variant, after: Variant, path: String = "") -> Array[String]:
	var changes: Array[String]
	if IGNORED_FIELDS.has(path):
		return changes
	if typeof(before) == TYPE_DICTIONARY and typeof(after) == TYPE_DICTIONARY:
		var keys: Array = (before as Dictionary).keys()
		for key: Variant in (after as Dictionary).keys():
			if not keys.has(key): keys.append(key)
		for key: Variant in keys:
			var next_path: String = str(key) if path.is_empty() else "%s.%s" % [path, key]
			if not (before as Dictionary).has(key) or not (after as Dictionary).has(key):
				if IGNORED_FIELDS.has(next_path): continue
				var value: Variant = (after as Dictionary).get(key) if (after as Dictionary).has(key) else (before as Dictionary).get(key)
				# Added/removed provenance dictionaries still compare every leaf.
				if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
					changes.append_array(changed_fields({}, value, next_path))
				else:
					changes.append(next_path)
			else:
				changes.append_array(changed_fields(before[key], after[key], next_path))
	elif typeof(before) == TYPE_ARRAY and typeof(after) == TYPE_ARRAY:
		if (before as Array).size() != (after as Array).size():
			changes.append(path)
		else:
			for index: int in range((before as Array).size()):
				changes.append_array(changed_fields(before[index], after[index], "%s[%d]" % [path, index]))
	elif typeof(before) != typeof(after) or before != after:
		changes.append(path)
	return changes

## Pure report. Visibility is derived, so include it in the comparison at every
## traversed tile, even when the endpoint has the same visibility as the origin.
static func walk_report(engine: RefCounted, before: Dictionary, after: Dictionary, path: Array[Vector2i]) -> Dictionary:
	var changes: Array[String] = changed_fields(before, after)
	var visible_before: Array = engine.umbra_visible_tiles(before)
	var enemies_before: Array = engine.visible_enemy_ids(before)
	if visible_before != engine.umbra_visible_tiles(after):
		changes.append("derived.umbra_visible_tiles")
	if enemies_before != engine.visible_enemy_ids(after):
		changes.append("derived.visible_enemy_ids")
	var visibility_state: Dictionary = before.duplicate(true)
	var destination: Vector2i = (after.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))
	var tiles: int = 0
	for index: int in range(path.size()):
		var tile: Vector2i = path[index]
		visibility_state["player"]["pos"] = tile
		if visible_before != engine.umbra_visible_tiles(visibility_state) and not changes.has("derived.umbra_visible_tiles"):
			changes.append("derived.umbra_visible_tiles")
		if enemies_before != engine.visible_enemy_ids(visibility_state) and not changes.has("derived.visible_enemy_ids"):
			changes.append("derived.visible_enemy_ids")
		tiles = index
		if index > 0 and tile == destination: break
	var movement: Dictionary = after.get("last_player_movement", {}) as Dictionary
	var walked: bool = bool(movement.get("resolved", false)) and str(movement.get("action_type", "")) == "move" and destination != (before.get("player", {}) as Dictionary).get("pos")
	return {"reversible": walked and changes.is_empty(), "changed_fields": changes, "tiles": tiles}

func record_walk(before: Dictionary, after: Dictionary) -> void:
	observe(before)
	var report: Dictionary = (after.get("last_player_movement", {}) as Dictionary).get("undo_report", {}) as Dictionary
	if not bool(report.get("reversible", false)):
		clear()
		last_walk_committed = true
	else:
		_history.append({"state": before.duplicate(true), "tiles": int(report.get("tiles", 0))})
		last_walk_committed = false
	_expected_state = after.duplicate(true)

func observe(state: Dictionary) -> void:
	# Also catches loads, activation changes, enemy actions and future un-wired
	# state mutations. No history ever enters the save/combat dictionary.
	if not _expected_state.is_empty() and state != _expected_state:
		clear()

func available(state: Dictionary, tutorial_hard_gate: bool = false) -> bool:
	observe(state)
	return not tutorial_hard_gate and not _history.is_empty() and str((state.get("current_actor", {}) as Dictionary).get("kind", "")) == "player" and not bool(state.get("player_turn_ending", false))

func undo(state: Dictionary, tutorial_hard_gate: bool = false) -> Dictionary:
	if not available(state, tutorial_hard_gate): return {}
	var entry: Dictionary = _history.pop_back()
	_expected_state = (entry["state"] as Dictionary).duplicate(true)
	last_walk_committed = false
	return {"state": _expected_state.duplicate(true), "tiles": int(entry["tiles"]), "activation_seq": int(state.get("activation_seq", 0))}

func clear() -> void:
	_history.clear()
	_expected_state.clear()
	last_walk_committed = false
