extends RefCounted

const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Flying = preload("res://scripts/enemy_mechanics/flying.gd")
const Maneuvers = preload("res://scripts/maneuver_rules.gd")
const Relics = preload("res://scripts/surface_relic_rules.gd")
const CARD_EXPOSE_KEY := "_card_ice_expose"
const LEGACY_STAGGER_RIDERS: Dictionary = {
	"hoarfrost_seer/rime_bolt": "ranged",
	"glacial_mirror/refraction": "aoe",
}

static func ignores_ice(state: Dictionary, kind: String, unit: Dictionary) -> bool:
	return Flying.flying(unit) or (kind == "player" and (Maneuvers.player_skating(state) or Relics.has_effect(state, "ice_expose_immunity")))

static func apply_expose(engine: RefCounted, state: Dictionary, kind: String, id: int, unit: Dictionary, start: bool) -> void:
	if int(unit.get("hp", 0)) <= 0:
		return
	if kind == "enemy" and engine._enemy_is_immune_to_status(unit, "expose"):
		return
	var before: int = int(unit.get("expose", 0))
	if before >= Surfaces.ICE_EXPOSE:
		return
	unit["expose"] = Surfaces.ICE_EXPOSE
	var actor_key: String = engine._surface_actor_key(kind, id)
	if not start and kind != "illusion" and bool(state.get("run_stats", {}).get("card_resolution_active", false)):
		var card_expose: Dictionary = state.get(CARD_EXPOSE_KEY, {})
		var earned: Dictionary = card_expose.get(actor_key, {"applied": 0, "unspent": 0})
		var increase: int = Surfaces.ICE_EXPOSE - before
		earned["applied"] += increase
		earned["unspent"] += increase
		card_expose[actor_key] = earned
		state[CARD_EXPOSE_KEY] = card_expose
	Surfaces.record_event(state, {
		"kind": "status_applied", "surface": "ice", "status": "expose",
		"amount": Surfaces.ICE_EXPOSE, "expose_before": before, "trigger": "start" if start else "entry",
		"actor_kind": kind, "id": id, "actor_key": actor_key, "tile": unit["pos"],
	})

static func mark_card_expose_spent(state: Dictionary, actor_key: String) -> void:
	if not bool(state.get("run_stats", {}).get("card_resolution_active", false)):
		return
	var earned: Dictionary = state.get(CARD_EXPOSE_KEY, {}).get(actor_key, {})
	if not earned.is_empty():
		earned["unspent"] = 0

static func contact_on_placement(engine: RefCounted, state: Dictionary, kind: String, unit: Dictionary, start: bool = false) -> void:
	if Surfaces.unit_on(state, unit, "ice") and not ignores_ice(state, kind, unit):
		apply_expose(engine, state, kind, int(unit.get("id", -1)), unit, start)

static func migrate_retired_statuses(state: Dictionary) -> void:
	_clear_retired_statuses(state.get("player", {}) as Dictionary)
	var restrictions: Dictionary = state.get("player_turn_restrictions", {}) as Dictionary
	if bool(restrictions.get("frozen", false)):
		var forfeited: int = maxi(0, int(state.get("plays_forfeited_this_turn", 0)))
		state["cards_played_this_turn"] = maxi(0, int(state.get("cards_played_this_turn", 0)) - forfeited)
		state["plays_forfeited_this_turn"] = 0
	restrictions.erase("frozen")
	for group: String in ["enemies", "illusions"]:
		for unit: Dictionary in state.get(group, []):
			_clear_retired_statuses(unit)
			if group == "enemies":
				_migrate_intent(unit)
				if str(unit.get("type", "")) != "iskaldra":
					unit.erase("frost_armor")

static func _migrate_intent(unit: Dictionary) -> void:
	var intent: Dictionary = unit.get("intent", {}) as Dictionary
	var type: String = str(unit.get("type", ""))
	var id: String = str(intent.get("id", ""))
	var attack_type: String = str(LEGACY_STAGGER_RIDERS.get(type + "/" + id, ""))
	var rider: Dictionary = {}
	if not attack_type.is_empty():
		for current: Dictionary in Data.enemy_property(type, "intents", []):
			if str(current.get("id", "")) != id:
				continue
			for action: Dictionary in current.get("actions", []):
				if str(action.get("type", "")) == attack_type:
					rider = action.get("surface_bonus", {}) as Dictionary
					break
			break
	_migrate_chilled_rider(intent, attack_type, rider)

static func _migrate_chilled_rider(value: Variant, attack_type: String, rider: Dictionary, inherited: bool = false) -> void:
	if value is Array:
		for child: Variant in value:
			_migrate_chilled_rider(child, attack_type, rider, inherited)
	elif value is Dictionary:
		var chilled: bool = bool(value.get("chilled", false))
		value.erase("chilled")
		var type: String = str(value.get("type", ""))
		if type == attack_type and not rider.is_empty() and (chilled or inherited):
			value["surface_bonus"] = rider.duplicate(true)
		for child: Variant in value.values():
			_migrate_chilled_rider(child, attack_type, rider, inherited or (type.is_empty() and chilled))

static func _clear_retired_statuses(unit: Dictionary) -> void:
	for status: String in ["chilled", "relic_chilled", "freeze", "petrify"]:
		unit.erase(status)
