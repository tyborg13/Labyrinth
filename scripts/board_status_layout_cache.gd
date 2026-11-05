extends RefCounted

## Owned by the board, shared with its retained layers. Cached entries are private;
## board query APIs copy them, while paint/collision submission only reads them.
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const Plates = preload("res://scripts/board_status_plates.gd")
const Groups = preload("res://scripts/board_hud_group_placement.gd")
const MAX_ACTORS: int = 128
var fixed_order_rects: Array[Rect2]
var group_obstacles: Dictionary = {}
var _actors: Dictionary = {}
var _group_order: Array[String]
var _previous_order_rects: Array[Rect2]
var _intent_obstacles: Dictionary = {}
var board_area := Rect2()
var reserved_ui: Array[Rect2]
var _choice_memos: Dictionary = {}
var _interpolating: bool = false
var _motion_x: float = 0.0
var _motion_context: Dictionary = {}
var last_updated_keys: Dictionary = {}
var motion_cell_hits: int = 0
var plan_count: int = 0
var plan_max_usec: int = 0
var pass_usec: int = 0
var rebuilds: int = 0
var hits: int = 0

func prepare_groups(view: Control, units: Array[Dictionary]) -> void:
	var started: int = Time.get_ticks_usec()
	var next_area: Rect2 = Groups.board_bounds(view, units)
	var next_ui: Array[Rect2] = Groups.screen_reservations(view)
	var keys: Array[String]
	var changed: Dictionary = {}
	for unit: Dictionary in units:
		if not _has_group(unit): continue
		var key: String = str(unit.get("key", ""))
		keys.append(key)
		var old: Dictionary = _actors.get(key, {})
		if old.is_empty():
			changed[key] = true
			continue
		var frame: Rect2 = view._unit_health_bar_rect(unit, view._unit_center(unit))
		if old.get("inputs", []) != _source_inputs(view, unit, frame): changed[key] = true
	for key: String in _group_order:
		if not keys.has(key): changed[key] = true
	if board_area == next_area and reserved_ui == next_ui and changed.size() <= 1 and not _group_order.is_empty():
		_group_order = keys
		if not changed.is_empty() or fixed_order_rects != _previous_order_rects:
			_motion_context.clear()
			refresh_moving(view, units, changed, false)
		pass_usec = Time.get_ticks_usec() - started
		return
	_choice_memos.clear()
	_motion_context.clear()
	_previous_order_rects = TypedArrays.rects(fixed_order_rects.duplicate())
	_intent_obstacles.clear()
	_group_order.clear()
	group_obstacles.clear()
	board_area = next_area
	reserved_ui = next_ui
	var occupied: Array[Rect2]
	for unit: Dictionary in units:
		if not _has_group(unit): continue
		var key: String = str(unit.get("key", ""))
		_group_order.append(key)
		group_obstacles[key] = occupied.duplicate()
		var frame: Rect2 = view._unit_health_bar_rect(unit, view._unit_center(unit))
		var group: Dictionary = resolve(view, unit, frame, true)
		occupied.append_array(group["group_rects"])
	pass_usec = Time.get_ticks_usec() - started

static func _has_group(unit: Dictionary) -> bool:
	return str(unit.get("role", "")) != "npc" and not bool(unit.get("boss_bar", false)) and not bool(unit.get("death_animation", false))

func cached_group(key: String) -> Dictionary:
	return _actors.get(key, {})

# A historical HUD entry owns an isolated copy of the exact group plan that
# produced it. Paint resolves against this same plan, never a newer history.
func snapshot_groups() -> Dictionary:
	return {"actors": _actors, "order": _group_order, "obstacles": group_obstacles,
		"fixed_order_rects": fixed_order_rects, "previous_order_rects": _previous_order_rects,
		"intent_obstacles": _intent_obstacles, "board_area": board_area, "reserved_ui": reserved_ui}.duplicate(true)

func restore_groups(snapshot: Dictionary) -> void:
	# Detach the live mutable cache from the LRU's immutable snapshot. Future
	# status changes and paint queries must not alter any historical plan.
	var restored: Dictionary = snapshot.duplicate(true)
	_actors = restored["actors"]
	_group_order.assign(restored["order"])
	group_obstacles = restored["obstacles"]
	fixed_order_rects.assign(restored["fixed_order_rects"])
	_previous_order_rects.assign(restored["previous_order_rects"])
	_intent_obstacles = restored["intent_obstacles"]
	board_area = restored["board_area"]
	reserved_ui.assign(restored["reserved_ui"])
	# Motion certificates refer to the plan replaced above, not this history.
	_choice_memos.clear()
	_motion_context.clear()
	last_updated_keys.clear()
	_interpolating = false
	_motion_x = 0.0

func refresh_moving(view: Control, units: Array[Dictionary], moving: Dictionary, interpolation: bool = true) -> Dictionary:
	# One bounded neighborhood pass, no propagation from displaced neighbors.
	# Reuse every other dictionary and its geometry by identity.
	var contextual_intents: bool = view._all_enemy_intents_expanded() or not view._hud_hover_actor_key(units).is_empty() or not (view.presentation.get("expanded_enemy_actor_keys", []) as Array).is_empty()
	if interpolation and moving.size() == 1 and fixed_order_rects.is_empty() and not contextual_intents:
		var moving_key: String = str(moving.keys()[0])
		for unit: Dictionary in units:
			if str(unit.get("key", "")) != moving_key: continue
			var center: Vector2 = view._unit_center(unit)
			_motion_x = center.x
			if _reuse_motion_cell(view, units, moving_key, center): return last_updated_keys
	else: _motion_context.clear()
	_interpolating = interpolation
	last_updated_keys = moving.duplicate()
	var touched: Array[Rect2]
	for rect: Rect2 in _previous_order_rects:
		if not fixed_order_rects.has(rect): touched.append(rect)
	for rect: Rect2 in fixed_order_rects:
		if not _previous_order_rects.has(rect): touched.append(rect)
	_previous_order_rects = TypedArrays.rects(fixed_order_rects.duplicate())
	_intent_obstacles.clear()
	if contextual_intents:
		var by_actor: Dictionary = view._units_by_key(units)
		for entry: Dictionary in view._hud_layout_entries_cache:
			var key: String = str(entry.get("actor_key", ""))
			var layout: Dictionary = entry.get("layout", {})
			var rects: Array[Rect2]
			rects.assign(layout.get("line_rects", []))
			if by_actor.has(key):
				var crest: Rect2 = view._leader_marker_rect(by_actor[key], entry.get("health_rect", Rect2()), layout.get("intent_rect", Rect2()))
				if crest.has_area(): rects.append(crest)
			_intent_obstacles[key] = rects
	for key: String in moving:
		var old: Dictionary = _actors.get(key, {})
		touched.append_array(old.get("group_rects", []))
	var by_key: Dictionary = view._units_by_key(units)
	for key: String in moving:
		if not by_key.has(key) or not _has_group(by_key[key]):
			_actors.erase(key)
			group_obstacles.erase(key)
			continue
		var unit: Dictionary = by_key[key]
		var frame: Rect2 = view._unit_health_bar_rect(unit, view._unit_center(unit))
		var obstacles: Array[Rect2] = _other_groups(key, frame, true)
		group_obstacles[key] = obstacles
		var group: Dictionary = resolve(view, unit, frame, true)
		touched.append_array(group["group_rects"])
	var touched_bounds: Rect2 = view._rects_bounds(touched)
	for unit: Dictionary in units:
		var key: String = str(unit.get("key", ""))
		if moving.has(key) or not _has_group(unit): continue
		var old: Dictionary = _actors.get(key, {})
		if not (old.get("group_bounds", Rect2()) as Rect2).intersects(touched_bounds, true): continue
		var intersects: bool = false
		for piece: Rect2 in old.get("group_rects", []):
			for rect: Rect2 in touched:
				if piece.intersects(rect, true): intersects = true
		if not intersects: continue
		last_updated_keys[key] = true
		group_obstacles[key] = _other_groups(key)
		resolve(view, unit, view._unit_health_bar_rect(unit, view._unit_center(unit)), true)
	# Changed discs were included in the touched set above. Unaffected groups
	# retain their actual geometry and identity; acknowledge the new fixed input
	# so a later paint query cannot accidentally rebuild every actor again.
	if not fixed_order_rects.is_empty():
		for unit: Dictionary in units:
			var key: String = str(unit.get("key", ""))
			if last_updated_keys.has(key) or not _actors.has(key): continue
			var signature: Array = _actors[key]["signature"]
			signature[signature.size() - 5] = fixed_order_rects.duplicate()

	_interpolating = false
	_motion_context.clear()
	if interpolation and moving.size() == 1 and fixed_order_rects.is_empty() and not contextual_intents and _actors.has(str(moving.keys()[0])):
		var lower: float = -INF
		var upper: float = INF
		for key: String in last_updated_keys:
			for suffix: String in ([":normal", ":compact"] if _actors.get(key, {}).get("compacted", false) else [":normal"]):
				var memo: Dictionary = _choice_memos.get(key + suffix, {})
				if not memo.has("winner") or not memo.has("world_x"):
					lower = INF
					break
				lower = maxf(lower, float(memo["world_x"]) + float(memo["lower"]))
				upper = minf(upper, float(memo["world_x"]) + float(memo["upper"]))
		if lower < upper and _motion_x >= lower and _motion_x <= upper:
			var key: String = str(moving.keys()[0])
			_motion_context = {"key": key, "y": view._unit_center(by_key[key]).y, "lower": lower, "upper": upper}
	return last_updated_keys

func _other_groups(key: String, frame: Rect2 = Rect2(), all_previous: bool = false) -> Array[Rect2]:
	var result: Array[Rect2]
	var owner: Dictionary = _actors.get(key, {})
	var reach := Rect2()
	if not owner.is_empty() and not all_previous:
		if not frame.has_area(): frame = owner["anchor_frame"]
		var raw: Dictionary = owner["raw"]
		var raw_bounds: Rect2 = raw["bounds"]
		raw_bounds.position += frame.position - (raw["anchor"] as Rect2).position
		reach = raw_bounds.grow_individual(Groups.MAX_HORIZONTAL, frame.size.y + Groups.ROW_GAP, Groups.MAX_HORIZONTAL, frame.size.y + Groups.ROW_GAP)
	for other: String in _group_order:
		if other == key: break
		if _actors.has(other) and (not reach.has_area() or reach.intersects(_actors[other]["group_bounds"], false)): result.append_array(_actors[other]["group_rects"])
	for other: String in _intent_obstacles:
		if other != key: result.append_array(_intent_obstacles[other])
	return result

static func _compact_badges(badges: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for badge: Dictionary in badges:
		var entry: Dictionary = badge.duplicate()
		if not str(entry.get("status_word", "")).is_empty():
			var label: String = str(entry.get("count_text", ""))
			if label.is_empty() and (int(entry.get("count", 0)) > 0 or bool(entry.get("show_count", false))): label = str(int(entry.get("count", 0)))
			if bool(entry.get("predicted", false)) and not label.begins_with("→"): label = "→" + (" " + label if not label.is_empty() else "")
			entry["label"] = label
			entry["label_font_size"] = 15
		result.append(entry)
	return result

func _source_inputs(view: Control, unit: Dictionary, frame: Rect2) -> Array:
	var key: String = str(unit.get("key", ""))
	var preview: Dictionary = view._unit_damage_preview(unit)
	var presentation: Dictionary = view.presentation
	return [frame, unit.get("role"), unit.get("type"), unit.get("hp"), unit.get("death_animation", false),
		unit.get("block", 0), unit.get("stoneskin", 0), unit.get("bleed", 0), unit.get("expose", 0), unit.get("chilled", false),
		unit.get("freeze", 0), unit.get("petrify", 0), unit.get("shock", 0), unit.get("immobilize", false), unit.get("frost_armor", 0),
		unit.get("charge", 0), unit.get("burrowed", false), unit.get("kindled_bonus", 0), unit.get("keyword_badges", []), unit.get("hud_forecast_fields", {}), unit.get("hud_forecast_icons", {}),
		preview.get("block", unit.get("block", 0)), preview.get("stoneskin", unit.get("stoneskin", 0)), preview.get("block_loss", 0), preview.get("stoneskin_loss", 0),
		presentation.get("umbra_truesight_activations", 0), presentation.get("umbra_truesight_conditional", false),
		(presentation.get("surface_status_preview", {}) as Dictionary).get(key, {}), unit.get("is_leader", false)]

func resolve(view: Control, unit: Dictionary, frame: Rect2, anchor_input: bool = false) -> Dictionary:
	var key: String = str(unit.get("key", ""))
	var cached: Dictionary = _actors.get(key, {})
	# Render/collision consumers may pass the placed frame. Normalize it to the
	# original anchor; the joint pass explicitly supplies new anchors on motion.
	if not anchor_input and not cached.is_empty() and frame == cached["frame"]: frame = cached["anchor_frame"]
	var preview: Dictionary = view._unit_damage_preview(unit)
	var presentation: Dictionary = view.presentation
	# Compare full owned signatures; a hash alone cannot establish equivalence.
	var inputs: Array = _source_inputs(view, unit, frame)
	var signature: Array = inputs.duplicate(false)
	signature.append_array([fixed_order_rects, group_obstacles.get(key, []), unit.get("is_leader", false), board_area, reserved_ui])
	if not cached.is_empty() and cached["signature"] == signature:
		hits += 1
		return cached
	var content_signature: Array = inputs.slice(1)
	content_signature.append(unit.get("is_leader", false))
	content_signature.append(frame.size)
	var raw: Dictionary
	if not cached.is_empty() and cached.get("content_signature", []) == content_signature:
		raw = cached["raw"]
	else:
		var defenses: Array[Dictionary] = Plates.defense_entries(unit, frame, preview)
		var statuses: Array[Dictionary]
		var compact: Array[Dictionary]
		if not bool(unit.get("death_animation", false)):
			var fill: Rect2 = view._health_bar_content_rect(unit, frame).grow(-Plates.HEALTH_BAR_BORDER_WIDTH)
			var badges: Array[Dictionary] = view._unit_status_presentation_badges(unit)
			statuses = Plates.status_entries(badges, fill, str(unit.get("role", "")) in ["player", "illusion"])
			compact = Plates.status_entries(_compact_badges(badges), fill, str(unit.get("role", "")) in ["player", "illusion"])
		var pips: Array[Rect2] = view._unit_hud_pip_rects(unit, frame)
		var crest: Rect2 = view._leader_marker_rect(unit, frame)
		var pieces: Array[Rect2]
		pieces.append(frame)
		pieces.append_array(Plates.rects(defenses))
		pieces.append_array(pips)
		if crest.has_area(): pieces.append(crest)
		var compact_pieces: Array[Rect2] = TypedArrays.rects(pieces.duplicate())
		pieces.append_array(Plates.rects(statuses))
		compact_pieces.append_array(Plates.rects(compact))
		raw = {"anchor": frame, "defenses": defenses, "statuses": statuses, "compact": compact, "pips": pips, "pieces": pieces, "compact_pieces": compact_pieces, "bounds": Groups.pieces_bounds(pieces).merge(Groups.pieces_bounds(compact_pieces))}
	var movement: Vector2 = frame.position - (raw["anchor"] as Rect2).position
	var pieces: Array[Rect2] = Groups.translate_rects(raw["pieces"], movement)
	var obstacles: Array[Rect2] = TypedArrays.rects(fixed_order_rects.duplicate())
	obstacles.append_array(group_obstacles.get(key, []))
	var started: int = Time.get_ticks_usec()
	# Compact pills can pack into a wider row than the normal word pills.
	# Prefilter once against both variants, including the incremental neighbors.
	var envelope: Array[Rect2]
	var raw_bounds: Rect2 = raw["bounds"]
	envelope.append(Rect2(raw_bounds.position + movement, raw_bounds.size))
	var near: Array[Rect2] = Groups.near_obstacles(envelope, obstacles, frame.size.y)
	var placement: Dictionary = _choose(key + ":normal", pieces, near, frame.size.y)
	var compacted: bool = not bool(placement["legal"]) or float(placement["overlap_area"]) > 0.0
	if compacted:
		pieces = Groups.translate_rects(raw["compact_pieces"], movement)
		placement = _choose(key + ":compact", pieces, near, frame.size.y)
	plan_count += 1
	plan_max_usec = maxi(plan_max_usec, Time.get_ticks_usec() - started)
	var offset: Vector2 = placement["offset"]
	if not cached.is_empty() and is_same(raw, cached.get("raw")) and frame == cached["anchor_frame"] and compacted == cached["compacted"] and offset == cached["offset"]:
		cached["signature"] = signature.duplicate(true)
		cached["inputs"] = inputs.duplicate(true)
		cached["placement"] = placement
		hits += 1
		return cached
	var defenses: Array[Dictionary]
	defenses.assign(raw["defenses"].duplicate(true))
	var statuses: Array[Dictionary]
	statuses.assign(raw["compact" if compacted else "statuses"].duplicate(true))
	Groups.translate_entries(defenses, movement + offset)
	Groups.translate_entries(statuses, movement + offset)
	var placed: Array[Rect2] = Groups.translate_rects(pieces, offset)
	cached = {"inputs": inputs.duplicate(true), "raw": raw, "content_signature": content_signature.duplicate(true), "compacted": compacted, "placement": placement, "signature": signature.duplicate(true), "anchor_frame": frame, "frame": Rect2(frame.position + offset, frame.size), "offset": offset,
		"group_bounds": view._rects_bounds(placed), "group_rects": placed, "pip_rects": Groups.translate_rects(raw["pips"], movement + offset), "defenses": defenses, "statuses": statuses,
		"defense_rects": Plates.rects(defenses), "status_rects": Plates.rects(statuses)}
	if not _actors.has(key) and _actors.size() >= MAX_ACTORS: _actors.clear()
	_actors[key] = cached
	rebuilds += 1
	return cached


func _choose(key: String, pieces: Array[Rect2], obstacles: Array[Rect2], height: float) -> Dictionary:
	if not _interpolating: return Groups.choose(pieces, obstacles, board_area, reserved_ui, height, true, key.ends_with(":normal"))
	if not _choice_memos.has(key): _choice_memos[key] = {}
	var memo: Dictionary = _choice_memos[key]
	var previous: Array = memo.get("source", [])
	var choice: Dictionary = Groups.choose_incremental(pieces, obstacles, board_area, reserved_ui, height, memo, key.ends_with(":normal"))
	if not is_same(previous, memo.get("source", [])): memo["world_x"] = _motion_x
	return choice

func _reuse_motion_cell(view: Control, units: Array[Dictionary], key: String, center: Vector2) -> bool:
	if _motion_context.is_empty() or _motion_context["key"] != key or center.y != float(_motion_context["y"]):
		return false
	if center.x <= float(_motion_context["lower"]) or center.x >= float(_motion_context["upper"]):
		return false
	var old: Dictionary = _actors.get(key, {})
	if old.is_empty(): return false
	var unit: Dictionary
	for candidate: Dictionary in units:
		if str(candidate.get("key", "")) == key: unit = candidate
	if unit.is_empty(): return false
	var anchor: Rect2 = view._unit_health_bar_rect(unit, center)
	var delta: Vector2 = anchor.position - (old["anchor_frame"] as Rect2).position
	var next_bounds := Rect2((old["group_bounds"] as Rect2).position + delta, (old["group_bounds"] as Rect2).size)
	# A newly touched actor changes the neighborhood and needs a fresh solve.
	# Actors that have stopped touching keep their dictionaries by identity.
	var affected: Dictionary = {key: true}
	var touched_bounds: Rect2 = next_bounds.merge(old["group_bounds"])
	for other: Dictionary in units:
		var other_key: String = str(other.get("key", ""))
		if other_key == key: continue
		var group: Dictionary = _actors.get(other_key, {})
		if group.is_empty() or not touched_bounds.intersects(group["group_bounds"], true): continue
		var touches: bool = false
		for piece: Rect2 in old["group_rects"]:
			var next_piece := Rect2(piece.position + delta, piece.size)
			for other_piece: Rect2 in group["group_rects"]:
				if next_piece.intersects(other_piece, true) or piece.intersects(other_piece, true): touches = true
		if not touches: continue
		if not last_updated_keys.has(other_key): return false
		affected[other_key] = true
	var moved: Dictionary = old.duplicate(false)
	moved["anchor_frame"] = anchor
	moved["frame"] = Rect2((old["frame"] as Rect2).position + delta, (old["frame"] as Rect2).size)
	moved["group_bounds"] = next_bounds
	for field: String in ["group_rects", "pip_rects", "defense_rects", "status_rects"]: moved[field] = Groups.translate_rects(old[field], delta)
	for field: String in ["defenses", "statuses"]:
		var entries: Array[Dictionary]
		entries.assign(old[field].duplicate(true))
		Groups.translate_entries(entries, delta)
		moved[field] = entries
	_actors[key] = moved
	last_updated_keys = affected
	for actor: String in last_updated_keys:
		var group: Dictionary = _actors[actor].duplicate(false)
		group_obstacles[actor] = _other_groups(actor)
		var signature: Array = group["signature"].duplicate(false)
		signature[0] = group["anchor_frame"]
		var inputs: Array = group["inputs"].duplicate(false)
		inputs[0] = group["anchor_frame"]
		group["inputs"] = inputs
		signature[signature.size() - 4] = group_obstacles[actor].duplicate()
		group["signature"] = signature
		var memo: Dictionary = _choice_memos.get(actor + (":compact" if group["compacted"] else ":normal"), {})
		var score: Dictionary = memo.get("winner", {})
		if not score.is_empty():
			group["placement"] = {"offset": score["offset"], "legal": true, "overlap_area": Groups.motion_score(memo, center.x - float(memo["world_x"]))}
		_actors[actor] = group
	motion_cell_hits += 1
	return true
