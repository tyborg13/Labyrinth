extends RefCounted
## Stage hover revisits the same forecasts with different focus/target owners.
## The underlying badge/compass caches retain only their latest state, so they
## rebuilt all enemies whenever the pointer returned to an earlier target.
## Keep bounded, owned results; exact inputs (not the index) validate every hit.

const Memo = preload("res://scripts/combat_preview_memo.gd")
var _badges := Memo.new()
var _compasses := Memo.new()

func clear() -> void:
	_badges = Memo.new()
	_compasses = Memo.new()

func rest_badges(host: Node, preview: Dictionary, focus: String, committed_override: Variant = null) -> Dictionary:
	var engine: RefCounted = host._combat_engine
	var committed: Dictionary = host._combat_state if committed_override == null else committed_override as Dictionary
	var definitions: Array = []
	for enemy: Dictionary in committed.get("enemies", []):
		definitions.append(host.GameData.enemies().get(str(enemy.get("type", "")), {}))
	var inputs: Array = [host._intent_badges, committed, preview, definitions,
		engine._relic_effects(preview), engine.get_script(), focus]
	# Preparation and the still-visible old board can share a tile. Retain
	# both exact states while the existing animation moves between them.
	var index: Array = [hash(committed), hash(preview), focus]
	var known_source: Callable = host._surface_preview_information_state.bind(preview) if committed_override == null else host._surface_preview_information_state.bind(preview, committed)
	return _badges.resolve(inputs, func() -> Dictionary:
		return host._intent_badges.presentation_for_state(engine, committed, preview,
			focus, known_source), index, true, true)

func compasses(host: Node, state: Dictionary, visible_ids: Array) -> Dictionary:
	var inputs: Array = _compass_inputs(state, visible_ids)
	return _compasses.resolve(inputs, func() -> Dictionary:
		return host.EnemyIntentCompass.descriptors_for_state(state, visible_ids), null, true, true)

# Ordinary compass summaries only read visible, living actors' ids/intents.
# Bramble fallback, Lob scaling and Warband projected attacks use the complete
# board/catalog instead. Do not invalidate an ordinary summary with journals,
# card payment, animation poses or an unrelated actor's position/durability.
func _compass_inputs(state: Dictionary, visible_ids: Array) -> Array:
	var intents: Array = []
	var filter_visibility: bool = not visible_ids.is_empty() or state.has("umbra")
	var full_board: bool = preload("res://scripts/warband_combat_rules.gd").active(state)
	for value: Variant in state.get("enemies", []):
		if not value is Dictionary: continue
		var enemy: Dictionary = value
		var id: int = int(enemy.get("id", -1))
		if id < 0 or int(enemy.get("hp", 0)) <= 0 or (filter_visibility and not visible_ids.has(id)): continue
		var intent: Dictionary = enemy.get("intent", {})
		if intent.is_empty(): continue
		if str(enemy.get("type", "")) == "briar_weaver" and str(intent.get("id", "")) == "root_mend": full_board = true
		var primary: Dictionary = preload("res://scripts/enemy_intent_compass.gd")._primary_action(intent)
		if preload("res://scripts/enemy_mechanics/marked_strike.gd").is_lob(primary): full_board = true
		intents.append([id, intent])
	if full_board: return [state, visible_ids, preload("res://scripts/game_data.gd").enemies()]
	return [intents]

# Optional data preparation shares the existing action animation. Publication
# still validates exact inputs, and callers never wait for this coroutine.
func prepare(host: Node, state: Dictionary, generation: int) -> void:
	await host.get_tree().process_frame
	if not is_instance_valid(host) or not host._committed_hand_query_active(generation): return
	# Warm exact plans individually while the old board is still animating.
	# Neither the known-state snapshot nor these results are published here.
	# An early refresh retains the normal synchronous path; it never waits.
	var known: Dictionary = host._surface_preview_information_state(state, state)
	for index: int in range((known.get("enemies", []) as Array).size()):
		host._combat_engine.enemy_threat_tiles(known, index)
		await host.get_tree().process_frame
		if not is_instance_valid(host) or not host._committed_hand_query_active(generation): return
	rest_badges(host, state, "", state)
	await host.get_tree().process_frame
	if not is_instance_valid(host) or not host._committed_hand_query_active(generation): return
	compasses(host, state, host._combat_engine.visible_enemy_ids(state))

# Forecasts previously waited for every hand card to finish before starting.
# Use those same animation frames concurrently, retaining the authoritative
# one-actor cursor and exact adoption check. There is no new wait or UI timing.
func prepare_forecast(host: Node, state: Dictionary, generation: int) -> void:
	await host.get_tree().process_frame
	if not is_instance_valid(host) or not host._committed_hand_query_active(generation): return
	if not host._combat_engine.is_player_turn(state):
		host._committed_hand_query_forecast = {"summary": {}}
		return
	var started: int = Time.get_ticks_usec() if host._runtime_performance_instrumentation_enabled else 0
	var scheduled: Dictionary = host._combat_engine.finish_player_activation(state)
	var cursor: Dictionary = host._combat_engine.begin_revealed_enemy_actions_preview(scheduled, true)
	host._record_runtime_performance_phase("committed_forecast_prepare", started)
	while not bool(cursor.get("complete", false)):
		await host.get_tree().process_frame
		if not is_instance_valid(host) or not host._committed_hand_query_active(generation): return
		started = Time.get_ticks_usec() if host._runtime_performance_instrumentation_enabled else 0
		host._combat_engine.advance_revealed_enemy_actions_preview(cursor)
		host._record_runtime_performance_phase("committed_forecast_slice", started)
	var phase_result: Dictionary = host._combat_engine.revealed_enemy_actions_preview_result(cursor)
	host._committed_hand_query_forecast = {"summary": host._pass_preview_summary_for_phase_result(state, phase_result)}
	if host._runtime_performance_instrumentation_enabled:
		host._committed_hand_query_diagnostics["prepared_forecasts"] = int(host._committed_hand_query_diagnostics.get("prepared_forecasts", 0)) + 1
