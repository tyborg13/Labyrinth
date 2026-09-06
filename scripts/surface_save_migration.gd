extends RefCounted
class_name SurfaceSaveMigration

const Surface = preload("res://scripts/board_surface_rules.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const GuidedCombatScenario = preload("res://scripts/guided_combat_scenario.gd")
const VERSION_KEY: String = "surface_rules_version"
const RETIRED_FIELDS: Array = [
	"elemental_intensity", "intensity", "intensity_cost", "intensity_bonus",
	"requires_intensity", "intensity_spent", "intensity_gained", "intensity_events",
	"poison", "poison_immune", "burn_immune", "thawing", "card_upgrades", "card_mods",
]
const HISTORY_FIELDS: Array = ["analytics", "analytics_context", "analytics_events", "progression_analytics_outbox", "completed_run_results", "last_run_result", "log"]

# Migration keeps the saved action boundary. It never replays a paid card,
# fabricates a pre-encounter snapshot, or changes HP, piles, clocks or ownership.
static func migrate_run(run_state: Dictionary, engine: RefCounted = null) -> Dictionary:
	if run_state.is_empty() or int(run_state.get(VERSION_KEY, 0)) >= Surface.RULES_VERSION:
		return run_state.duplicate(true)
	var result: Dictionary = _migrate_tree(run_state, engine) as Dictionary
	result[VERSION_KEY] = Surface.RULES_VERSION
	result["surface_migration"] = {"from_version": int(run_state.get(VERSION_KEY, 0)), "to_version": Surface.RULES_VERSION, "preserved_action_boundary": true}
	return result

static func _migrate_tree(value: Variant, engine: RefCounted) -> Variant:
	if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]:
		return "pale_spark" if str(value) == "bone_dart" else value
	if typeof(value) == TYPE_ARRAY:
		var entries: Array = []
		for entry: Variant in value:
			if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("type", "")) in ["intensity", "poison", "burn"]:
				continue
			entries.append(_migrate_tree(entry, engine))
		return entries
	if typeof(value) != TYPE_DICTIONARY:
		return value
	var source: Dictionary = value as Dictionary
	var result: Dictionary = {}
	for key: Variant in source:
		if str(key) == "progression" and typeof(source[key]) == TYPE_DICTIONARY:
			# Refund legacy permanent card growth before removing its old fields.
			result[key] = ProgressionStore.normalized_data(source[key] as Dictionary)
			continue
		if RETIRED_FIELDS.has(str(key)) or str(key).begins_with("intensity_"):
			continue
		# `burn: true` on a card is the retained Exhaust cost. Numeric Burn was
		# the retired damage-over-time status, including old trap/action riders.
		if str(key) == "burn" and typeof(source[key]) != TYPE_BOOL:
			continue
		if HISTORY_FIELDS.has(str(key)):
			result[key] = source[key].duplicate(true) if typeof(source[key]) in [TYPE_ARRAY, TYPE_DICTIONARY] else source[key]
		else:
			var migrated_key: Variant = "pale_spark" if str(key) == "bone_dart" else key
			result[migrated_key] = _migrate_tree(source[key], engine)
	if source.has("grid") and (source.has("player") or source.has("enemies")):
		result = _migrate_board(result, engine)
	return result

static func _migrate_board(state: Dictionary, engine: RefCounted) -> Dictionary:
	_migrate_guided_opening(state)
	state["rules_version"] = Surface.RULES_VERSION
	state["surfaces"] = _normalized_surfaces(state)
	state["surface_revision"] = int(state.get("surface_revision", 0))
	state["surface_event_sequence"] = int(state.get("surface_event_sequence", 0))
	state["surface_events"] = []
	# Old Chill was a transient hit counter. It cannot become contact-based
	# Chill merely because a save was opened. A future entry/start can apply it.
	var player: Dictionary = state.get("player", {}) as Dictionary
	player.erase("chilled")
	if state.has("player"):
		state["player"] = player
	for collection: String in ["enemies", "illusions"]:
		for actor: Dictionary in state.get(collection, []):
			actor.erase("chilled")
	if engine != null and engine.has_method("refresh_surface_enemy_definitions"):
		state = engine.call("refresh_surface_enemy_definitions", state) as Dictionary
	return state

static func _normalized_surfaces(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var old: Dictionary = state.get("surfaces", {}) as Dictionary
	for key: Variant in old:
		var tile: Vector2i = key as Vector2i if typeof(key) == TYPE_VECTOR2I else Surface.tile_from_key(str(key))
		if not Surface.can_place(state, tile) or typeof(old[key]) != TYPE_DICTIONARY:
			continue
		var layer: Dictionary = old[key] as Dictionary
		var elemental: String = Surface.kind(str(layer.get("elemental", "")))
		if elemental not in ["fire", "ice", "electrified"]:
			elemental = ""
		if elemental.is_empty() and not bool(layer.get("rubble", false)):
			continue
		var entry: Dictionary = {"elemental": elemental, "rubble": bool(layer.get("rubble", false))}
		for source_key: String in ["elemental_source", "rubble_source"]:
			if typeof(layer.get(source_key)) == TYPE_DICTIONARY:
				entry[source_key] = (layer[source_key] as Dictionary).duplicate(true)
		result[Surface.tile_key(tile)] = entry
	return result

# The old guided opening promises an exact two-card kill. Before its first hit,
# its authored 17-HP target must match Pale Spark (4) + Quick Stab (11). If the
# old first hit already resolved, the remaining 11 HP and all paid state stay.
static func _migrate_guided_opening(state: Dictionary) -> void:
	var marker: Dictionary = state.get(GuidedCombatScenario.STATE_KEY, {}) as Dictionary
	if int(marker.get("version", 0)) != 1:
		return
	marker["version"] = GuidedCombatScenario.VERSION
	marker["preview_card_id"] = GuidedCombatScenario.PREVIEW_CARD_ID
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) != GuidedCombatScenario.TARGET_ENEMY_ID:
			continue
		if int(enemy.get("hp", 0)) == 17:
			enemy["hp"] = GuidedCombatScenario.TARGET_HP
		if int(enemy.get("max_hp", 0)) == 17:
			enemy["max_hp"] = GuidedCombatScenario.TARGET_HP
