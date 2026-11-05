extends RefCounted

const Facing = preload("res://scripts/hero_facing_state.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
var _input: Dictionary = {}
var _definitions: Array = []
var _engine_facing: Variant = null
var adoptions: int = 0

func cancel(scene: Node) -> void:
	if not _input.is_empty(): scene._cancel_committed_hand_queries()
	_input.clear()
	_definitions.clear()

# The dossier already owns the exact future fight. Prepare pure queries on its
# existing frames, including the deterministic analytics identity that entry
# attaches later. No event, checkpoint, authoritative RNG or UI is published.
func schedule(scene: Node) -> void:
	if str(scene._run_state.get("mode", "")) != "pre_battle": return
	var preview: Dictionary = scene._pre_battle_preview_run_state.get("combat_state", {})
	var run_analytics: Dictionary = scene._run_state.get("analytics", {})
	if preview.is_empty() or str(run_analytics.get("run_id", "")).is_empty(): return
	var state: Dictionary = scene._combat_engine.normalize_player_movement_pool(preview)
	if Settings.hero_facing_mode(scene._settings) == "persist": Facing.ensure(state)
	Wind.lock_legacy_intents(scene._combat_engine, state)
	var analytics: Dictionary = (state.get("analytics", {}) as Dictionary).duplicate(true)
	analytics["combat_id"] = "%s_c%03d" % [run_analytics.run_id, int(run_analytics.get("combat_counter", 0)) + 1]
	analytics[scene.COMBAT_SKILL_EVENT_STAGED_REVISION_KEY] = 0
	analytics[scene.COMBAT_DEFIANCE_EVENT_STAGED_REVISION_KEY] = 0
	state["analytics"] = analytics
	var definitions: Array = scene._run_engine._pre_battle_definitions()
	if state == _input and definitions == _definitions: return
	_input = state.duplicate(true)
	_definitions = definitions.duplicate(true)
	_engine_facing = scene._combat_engine.get("persist_hero_facing")
	scene._schedule_committed_hand_queries(state, true)

func adopt(scene: Node) -> void:
	# Existing adoption compares every state field and the card catalogs again;
	# this additional guard covers all factory catalogs and incomplete work.
	if not _input.is_empty() and _definitions == scene._run_engine._pre_battle_definitions() and _engine_facing == scene._combat_engine.get("persist_hero_facing"):
		if scene._committed_hand_query_state == scene._combat_state: adoptions += 1
		scene._adopt_committed_hand_queries()
	elif not _input.is_empty():
		scene._cancel_committed_hand_queries()
	_input.clear()
	_definitions.clear()
