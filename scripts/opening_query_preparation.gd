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
	scene._cancel_committed_hand_queries()
	scene._committed_hand_query_prepare_previews = true
	scene._committed_hand_query_definitions = scene._committed_query_definitions().duplicate(true)
	scene._committed_hand_query_state = state.duplicate(true)
	var generation: int = scene._committed_hand_query_generation
	# The opening has two independent consumers on Start. Do not put the first
	# forecast behind the entire hand (or speculative card-target previews).
	_prepare_hand(scene, state, generation)
	_prepare_forecast(scene, state, generation)
	_prepare_board(scene, state, generation)

func _prepare_hand(scene: Node, state: Dictionary, generation: int) -> void:
	var hand: Array = (state.get("deck", {}) as Dictionary).get("hand", [])
	for index: int in range(hand.size()):
		await scene.get_tree().process_frame
		if not _active(scene, generation): return
		var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		scene._committed_hand_query_flags[index] = scene._card_playability_for_state(state, index)
		scene._committed_hand_query_display[index] = scene._card_widget_display(str(hand[index]), state)
		scene._record_runtime_performance_phase("opening_hand_query_warm", started)
		if scene._runtime_performance_instrumentation_enabled:
			scene._committed_hand_query_diagnostics["prepared_cards"] = int(scene._committed_hand_query_diagnostics.get("prepared_cards", 0)) + 1
	# Keep speculative selection work behind the opening's mandatory queries.
	while not scene._committed_hand_query_forecast.has("summary"):
		await scene.get_tree().process_frame
		if not _active(scene, generation): return
	scene._warm_committed_card_previews(state, generation)

func _prepare_forecast(scene: Node, state: Dictionary, generation: int) -> void:
	await scene.get_tree().process_frame
	if not _active(scene, generation): return
	if not scene._combat_engine.is_player_turn(state):
		scene._committed_hand_query_forecast = {"summary": {}}
		return
	var scheduled: Dictionary = scene._combat_engine.finish_player_activation(state)
	var cursor: Dictionary = scene._combat_engine.begin_revealed_enemy_actions_preview(scheduled, true)
	while not bool(cursor.get("complete", false)):
		await scene.get_tree().process_frame
		if not _active(scene, generation): return
		var started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
		scene._combat_engine.advance_revealed_enemy_actions_preview(cursor)
		scene._record_runtime_performance_phase("opening_forecast_slice", started)
	var result: Dictionary = scene._combat_engine.revealed_enemy_actions_preview_result(cursor)
	scene._committed_hand_query_forecast = {"summary": scene._pass_preview_summary_for_phase_result(state, result)}
	if scene._runtime_performance_instrumentation_enabled:
		scene._committed_hand_query_diagnostics["prepared_forecasts"] = int(scene._committed_hand_query_diagnostics.get("prepared_forecasts", 0)) + 1

func _prepare_board(scene: Node, state: Dictionary, generation: int) -> void:
	# These caches validate complete inputs on use. Preparing them publishes no
	# board, health ghost, focus, control, RNG or analytics state.
	scene._stage_hover_refresh.prepare(scene, state, generation)
	await scene.get_tree().process_frame
	if not _active(scene, generation): return
	scene.board_view._battlefield_rule_presentation_for(state, {})

func _active(scene: Node, generation: int) -> bool:
	if not is_instance_valid(scene) or not scene._committed_hand_query_active(generation): return false
	# Reject a catalog change at any suspension, even if it is restored before
	# Start. Otherwise an actor cursor could combine two different definitions.
	if _definitions != scene._run_engine._pre_battle_definitions() or _engine_facing != scene._combat_engine.get("persist_hero_facing"):
		cancel(scene)
		return false
	return true

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
