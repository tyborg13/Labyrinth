extends RefCounted

## Presentation-only values. Committed combat/save/RNG data never contains these.
const Pulse = preload("res://scripts/combat_preview_pulse.gd")
const Retaliate = preload("res://scripts/retaliate_rules.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")
const Maneuver = preload("res://scripts/maneuver_rules.gd")
const Rites = preload("res://scripts/rite_rules.gd")
const KEY: String = "hud_forecast"
const STATUS_FIELDS: Array = ["bleed", "expose", "chilled", "freeze", "petrify", "shock", "immobilize", "frost_armor"]
var _held: Dictionary = {}

func clear() -> void:
	_held = {}

func begin(scene: Node, resolved: Dictionary) -> void:
	_held = changes(scene._combat_state, scene._board_display_state())
	# Hovered ground statuses have their existing arrow/word pill. Retain that
	# exact form, rather than converting it into an ordinary status at commit.
	for actor: String in scene.board_view.presentation.get("surface_status_preview", {}):
		var pending: Dictionary = _held.get(actor, {"values": {}, "badges": {}})
		pending["status_preview"] = scene.board_view.presentation["surface_status_preview"][actor].duplicate(true)
		for field: String in pending["status_preview"]: pending["values"].erase(field)
		_held[actor] = pending
	for actor: String in scene.board_view._damage_preview_map():
		var pending: Dictionary = _held.get(actor, {"values": {}, "badges": {}})
		pending["damage_preview"] = scene.board_view._damage_preview_map()[actor].duplicate(true)
		_held[actor] = pending
	# Delivery snapshots precede card payment. An existing Quicken pool, for
	# example, is spent at finish; its newly gained part still lands at its float.
	var before_units: Dictionary = actors(scene._combat_state)
	var delivered_units: Dictionary = actors(resolved)
	var before_badges: Dictionary = badges_by_icon(keyword_badges(scene._combat_state))
	var delivered_badges: Dictionary = badges_by_icon(keyword_badges(resolved))
	for actor: String in _held:
		var entry: Dictionary = _held[actor]
		entry["delivery_values"] = {}
		for field: String in entry["values"]:
			if delivered_units.get(actor, {}).get(field) != before_units.get(actor, {}).get(field): entry["delivery_values"][field] = delivered_units.get(actor, {}).get(field)
		entry["delivery_badges"] = {}
		for icon: String in entry["badges"]:
			if delivered_badges.get(icon, {}) != before_badges.get(icon, {}): entry["delivery_badges"][icon] = delivered_badges.get(icon, {})
	# Include payment/finish hooks in the same owned query used by selection.
	# This does not mutate the resolver snapshot or its RNG.
	confirm(scene._combat_engine.finish_player_card(resolved, scene._selected_card_index,
		scene._combat_engine.card_plays_spent_for_actions(scene._pending_actions), {"play_mode": "play"}))

func confirm(resolved: Dictionary) -> bool:
	# A speculative result interrupted by a hidden cause is not promised at play.
	var previous: Dictionary = _held
	_held = _held.duplicate(true)
	var final_units: Dictionary = actors(resolved)
	var final_badges: Dictionary = badges_by_icon(keyword_badges(resolved))
	for actor: String in _held.keys():
		var entry: Dictionary = _held[actor]
		var actual: Dictionary = final_units.get(actor, {})
		for collection: String in ["values", "status_preview"]:
			var values: Dictionary = entry.get(collection, {})
			for field: String in values.keys():
				if actual.get(field, false if values[field] is bool else 0) != values[field]: values.erase(field)
		for icon: String in entry["badges"].keys():
			if final_badges.get(icon, {}) != entry["badges"][icon]: entry["badges"].erase(icon)
		var damage: Dictionary = entry.get("damage_preview", {})
		for field: String in ["hp", "block", "stoneskin"]:
			if damage.has(field) and damage[field] != actual.get(field, 0): entry.erase("damage_preview")
		if _empty(entry): _held.erase(actor)
	return previous != _held

func decorate(scene: Node, state: Dictionary, presentation: Dictionary) -> Dictionary:
	var forecast: Dictionary = {}
	if scene._animation_lock:
		var current: Dictionary = actors(state)
		var current_badges: Dictionary = badges_by_icon(keyword_badges(state))
		# Each value becomes real at the existing delivery snapshot, independently
		# of its siblings (e.g. Block first, then Undertaker Stand's Retaliate).
		var remaining: Dictionary = _held.duplicate(true)
		for actor: String in remaining.keys():
			var entry: Dictionary = remaining[actor]
			for collection: String in ["values", "status_preview"]:
				var values: Dictionary = entry.get(collection, {})
				for field: String in values.keys():
					var value: Variant = current.get(actor, {}).get(field, false if values[field] is bool else 0)
					if value == values[field] or (collection == "values" and entry.get("delivery_values", {}).has(field) and value == entry["delivery_values"][field]): values.erase(field)
			for icon: String in entry["badges"].keys():
				if current_badges.get(icon, {}) == entry["badges"][icon] or (entry.get("delivery_badges", {}).has(icon) and current_badges.get(icon, {}) == entry["delivery_badges"][icon]): entry["badges"].erase(icon)
			var damage: Dictionary = entry.get("damage_preview", {})
			var delivered: bool = not damage.is_empty()
			for field: String in ["hp", "block", "stoneskin"]:
				if damage.has(field) and damage[field] != current.get(actor, {}).get(field, 0): delivered = false
			if delivered: entry.erase("damage_preview")
			if _empty(entry): remaining.erase(actor)
		_held = remaining
		forecast = remaining
	else:
		clear()
		if scene._selected_card_index >= 0: forecast = changes(scene._combat_state, state)
	var result: Dictionary = presentation.duplicate(false)
	if forecast.is_empty():
		result.erase(KEY)
	else:
		result[KEY] = forecast
		var statuses: Dictionary = (result.get("surface_status_preview", {}) as Dictionary).duplicate(true)
		var damage: Dictionary = (result.get("damage_preview", {}) as Dictionary).duplicate(true)
		for actor: String in forecast:
			if not (forecast[actor].get("status_preview", {}) as Dictionary).is_empty(): statuses[actor] = forecast[actor]["status_preview"]
			if not (forecast[actor].get("damage_preview", {}) as Dictionary).is_empty(): damage[actor] = forecast[actor]["damage_preview"]
		if not statuses.is_empty(): result["surface_status_preview"] = statuses
		if not damage.is_empty(): result["damage_preview"] = damage
	return result

static func _empty(entry: Dictionary) -> bool:
	return (entry.get("values", {}) as Dictionary).is_empty() and (entry.get("badges", {}) as Dictionary).is_empty() and (entry.get("status_preview", {}) as Dictionary).is_empty() and (entry.get("damage_preview", {}) as Dictionary).is_empty()

static func actors(state: Dictionary) -> Dictionary:
	var result: Dictionary = {"player": state.get("player", {})}
	for enemy: Dictionary in state.get("enemies", []): result["enemy_%d" % int(enemy.get("id", -1))] = enemy
	return result

static func keyword_badges(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = Retaliate.player_badges(state, Rites.effects(state))
	result.append_array(Tempo.player_badges(state))
	result.append_array(Maneuver.player_badges(state))
	return result

static func badges_by_icon(badges: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for badge: Dictionary in badges: result[str(badge["icon"])] = badge
	return result

static func changes(before: Dictionary, projected: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var previous: Dictionary = actors(before)
	var projected_units: Dictionary = actors(projected)
	for actor: String in projected_units:
		var unit: Dictionary = projected_units[actor]
		var old: Dictionary = previous.get(actor, {})
		if old.is_empty(): continue
		var values: Dictionary = {}
		var fields: Array = STATUS_FIELDS.duplicate()
		if actor == "player": fields.append_array(["hp", "block", "stoneskin"])
		for field: String in fields:
			var fallback: Variant = false if field in ["chilled", "immobilize"] else 0
			if unit.get(field, fallback) != old.get(field, fallback): values[field] = unit.get(field, fallback)
		if not values.is_empty(): result[actor] = {"values": values, "badges": {}}
	var old_badges: Dictionary = badges_by_icon(keyword_badges(before))
	for badge: Dictionary in keyword_badges(projected):
		var icon: String = str(badge["icon"])
		if old_badges.get(icon, {}) == badge: continue
		if not result.has("player"): result["player"] = {"values": {}, "badges": {}}
		result["player"]["badges"][icon] = badge
	if result.has("player"):
		# Retain the delivered producers' order, not the insertion order of a
		# merge into the pre-delivery badges (which appends newly gained icons).
		result["player"]["badge_order"] = badges_by_icon(keyword_badges(projected)).keys()
	return result

static func unit(source: Dictionary, presentation: Dictionary) -> Dictionary:
	var pending: Dictionary = (presentation.get(KEY, {}) as Dictionary).get(str(source.get("key", "")), {})
	if pending.is_empty(): return source
	var result: Dictionary = source.duplicate(false)
	var fields: Dictionary = pending.get("values", {})
	result.merge(fields, true)
	result["hud_forecast_fields"] = fields
	var icons: Dictionary = fields.duplicate(false)
	var badges: Dictionary = pending.get("badges", {})
	if not badges.is_empty():
		var merged: Dictionary = badges_by_icon(source.get("keyword_badges", []))
		merged.merge(badges, true)
		var entries: Array[Dictionary]
		for icon: String in pending.get("badge_order", []):
			if merged.has(icon):
				entries.append(merged[icon])
				merged.erase(icon)
		for badge: Dictionary in merged.values(): entries.append(badge)
		result["keyword_badges"] = entries
		icons.merge(badges)
	result["hud_forecast_icons"] = icons
	return result

static func field_is_preview(unit: Dictionary, field: String, damage: Dictionary = {}) -> bool:
	return (unit.get("hud_forecast_fields", {}) as Dictionary).has(field) or (damage.has(field) and damage[field] != unit.get(field, 0))

static func needs_pulse(presentation: Dictionary) -> bool:
	return not bool(presentation.get("reduced_motion", false)) and (
		not (presentation.get(KEY, {}) as Dictionary).is_empty()
		or not (presentation.get("surface_status_preview", {}) as Dictionary).is_empty())

func boss(scene: Node, source: Dictionary, presentation: Dictionary) -> Dictionary:
	var key: String = "enemy_%d" % int(source.get("id", -1))
	var pending: Dictionary = (presentation.get(KEY, {}) as Dictionary).get(key, {})
	var values: Dictionary = (pending.get("values", {}) as Dictionary).duplicate(false)
	values.merge(pending.get("status_preview", {}), true)
	values.merge((presentation.get("surface_status_preview", {}) as Dictionary).get(key, {}), true)
	for field: String in scene._boss_status_cells:
		Pulse.bind(scene._boss_status_cells[field]["cell"], presentation, values.has(field))
	var result: Dictionary = source.duplicate(false)
	result.merge(values, true)
	return result
