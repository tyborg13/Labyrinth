extends RefCounted
class_name SurfaceSaveMigration

const Surface = preload("res://scripts/board_surface_rules.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const GuidedCombatScenario = preload("res://scripts/guided_combat_scenario.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const VERSION_KEY: String = "surface_rules_version"
const RETIRED_FIELDS: Array = [
	"elemental_intensity", "intensity", "intensity_cost", "intensity_bonus",
	"requires_intensity", "intensity_spent", "intensity_gained", "intensity_events",
	"poison", "poison_immune", "burn_immune", "thawing", "card_upgrades", "card_mods",
]
const HISTORY_FIELDS: Array = ["analytics", "analytics_context", "analytics_events", "progression_analytics_outbox", "completed_run_results", "last_run_result", "log", "surface_events", "elemental_source", "rubble_source"]

# Migration keeps the saved action boundary. It never replays a paid card,
# fabricates a pre-encounter snapshot, or changes HP, piles, clocks or ownership.
static func migrate_run(run_state: Dictionary, engine: RefCounted = null) -> Dictionary:
	if run_state.is_empty() or int(run_state.get(VERSION_KEY, 0)) >= Surface.RULES_VERSION:
		return run_state.duplicate(true)
	var result: Dictionary = _migrate_tree(run_state, engine, int(run_state.get(VERSION_KEY, 0))) as Dictionary
	var combat: Dictionary = result.get("combat_state", {}) as Dictionary
	var marker: Dictionary = combat.get(GuidedCombatScenario.STATE_KEY, {}) as Dictionary
	var old_marker: Dictionary = (run_state.get("combat_state", {}) as Dictionary).get(GuidedCombatScenario.STATE_KEY, {}) as Dictionary
	var old_guide: bool = int(old_marker.get("version", 0)) in [1, 2]
	var target_alive: bool = false
	for enemy: Dictionary in combat.get("enemies", []):
		if int(enemy.get("id", -1)) == GuidedCombatScenario.TARGET_ENEMY_ID and int(enemy.get("hp", 0)) > 0:
			target_alive = true
	# The save may sit after the kill but before the UI persisted its lesson.
	# Do not ask the player to select that dead target again either.
	if old_guide and not target_alive and not Tutorial.has_completed(result.get("progression", {}) as Dictionary, Tutorial.MILESTONE_KILL_CARD):
		marker["resume_without_scripted_kill"] = true
	if bool(marker.get("resume_without_scripted_kill", false)):
		# An already-paid opening is not a fresh fixture. Release its scripted
		# input rails rather than inventing a kill or asking to replay a card.
		result["progression"] = Tutorial.dismiss_tutorial(result.get("progression", {}) as Dictionary)
	result[VERSION_KEY] = Surface.RULES_VERSION
	result["surface_migration"] = {"from_version": int(run_state.get(VERSION_KEY, 0)), "to_version": Surface.RULES_VERSION, "preserved_action_boundary": true}
	return result

static func _migrate_tree(value: Variant, engine: RefCounted, from_version: int) -> Variant:
	if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]:
		return "pale_spark" if from_version < 4 and str(value) == "bone_dart" else value
	if typeof(value) == TYPE_ARRAY:
		var entries: Array = []
		for entry: Variant in value:
			if from_version < 4 and typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("type", "")) in ["intensity", "poison", "burn"]:
				continue
			entries.append(_migrate_tree(entry, engine, from_version))
		return entries
	if typeof(value) != TYPE_DICTIONARY:
		return value
	var source: Dictionary = value as Dictionary
	var is_board: bool = source.has("grid") and (source.has("player") or source.has("enemies"))
	if is_board:
		from_version = maxi(from_version, int(source.get("rules_version", source.get(VERSION_KEY, 0))))
	var result: Dictionary = {}
	for key: Variant in source:
		if str(key) == "progression" and typeof(source[key]) == TYPE_DICTIONARY:
			# Refund legacy permanent card growth before removing its old fields.
			result[key] = ProgressionStore.normalized_data(source[key] as Dictionary) if from_version < 4 else (source[key] as Dictionary).duplicate(true)
			result[key][VERSION_KEY] = Surface.RULES_VERSION
			continue
		if from_version < 4 and (RETIRED_FIELDS.has(str(key)) or str(key).begins_with("intensity_")):
			continue
		# `burn: true` on a card is the retained Exhaust cost. Numeric Burn was
		# the retired damage-over-time status, including old trap/action riders.
		if from_version < 4 and str(key) == "burn" and typeof(source[key]) != TYPE_BOOL:
			continue
		if HISTORY_FIELDS.has(str(key)):
			result[key] = source[key].duplicate(true) if typeof(source[key]) in [TYPE_ARRAY, TYPE_DICTIONARY] else source[key]
		else:
			var migrated_key: Variant = "pale_spark" if from_version < 4 and str(key) == "bone_dart" else key
			result[migrated_key] = _migrate_tree(source[key], engine, from_version)
	_migrate_copied_conduction_rules(result)
	if is_board:
		result = _migrate_board(result, engine, from_version)
	return result

static func _migrate_board(state: Dictionary, engine: RefCounted, from_version: int) -> Dictionary:
	_migrate_guided_opening(state)
	state["rules_version"] = Surface.RULES_VERSION
	state[VERSION_KEY] = Surface.RULES_VERSION
	if from_version >= 4:
		# v4 already has contact-based Chill, durable terrain provenance and an
		# append-only event stream. Do not clear or regenerate any of these.
		if from_version < 5 and not state.has("surface_event_legacy_rules_version"):
			state["surface_event_legacy_rules_version"] = from_version
		return state
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

static func _migrate_copied_conduction_rules(value: Dictionary) -> void:
	var old_claim: String = "ion_spool:surface_consumption_reward"
	var new_claim: String = "ion_spool:surface_conduction_reward"
	if value.has(old_claim):
		value[new_claim] = maxi(int(value[old_claim]), int(value.get(new_claim, value[old_claim])))
		value.erase(old_claim)
	if str(value.get("subject", "")) == "consumed" and str(value.get("surface", "")) == "electrified":
		value["subject"] = "conducted"
	var fuel: Dictionary = value.get("surface_fuel", {}) as Dictionary
	if str(fuel.get("surface", "")) != "electrified":
		return
	# A revealed, unpaid old intent now requires an assisted hit. A payment
	# already resolved before the checkpoint keeps its earned bonus unchanged.
	if not value.has("_surface_fuel_paid") and not bool(value.get("_surface_fuel_denied", false)):
		var actions: Array = value.get("actions", []) as Array
		for index_key: Variant in fuel.get("action_bonuses", {}) as Dictionary:
			var index: int = int(index_key)
			if index < 0 or index >= actions.size() or typeof(actions[index]) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = actions[index] as Dictionary
			var bonus: Dictionary = (fuel["action_bonuses"][index_key] as Dictionary).duplicate(true)
			bonus["subject"] = "conducted"
			bonus["surface"] = "electrified"
			action["surface_bonus"] = bonus
	value.erase("surface_fuel")
	value.erase("_surface_fuel_tile")

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

# Only an untouched authored target is adjusted to the new two-card damage.
# Paid openings keep every combat value and resume without the scripted kill.
static func _migrate_guided_opening(state: Dictionary) -> void:
	var marker: Dictionary = state.get(GuidedCombatScenario.STATE_KEY, {}) as Dictionary
	var version: int = int(marker.get("version", 0))
	if version < 1 or version >= GuidedCombatScenario.VERSION:
		return
	marker["version"] = GuidedCombatScenario.VERSION
	marker["preview_card_id"] = GuidedCombatScenario.PREVIEW_CARD_ID
	var old_target_hp: int = 17 if version == 1 else 15
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -1)) != GuidedCombatScenario.TARGET_ENEMY_ID:
			continue
		if int(enemy.get("hp", 0)) <= 0:
			return
		var deck: Dictionary = state.get("deck", {}) as Dictionary
		var unspent: bool = int(state.get("turn", 1)) <= 1 and int(state.get("cards_played_this_turn", 0)) == 0 and (state.get("pending_card_payment", {}) as Dictionary).is_empty()
		for pile: String in ["discard", "burned", "consumed"]:
			unspent = unspent and (deck.get(pile, []) as Array).is_empty()
		if unspent and int(enemy.get("hp", 0)) == old_target_hp and int(enemy.get("max_hp", 0)) == old_target_hp:
			enemy["hp"] = GuidedCombatScenario.TARGET_HP
			enemy["max_hp"] = GuidedCombatScenario.TARGET_HP
		else:
			marker["resume_without_scripted_kill"] = true
