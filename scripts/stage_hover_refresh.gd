extends RefCounted
## Stage hover revisits the same forecasts with different focus/target owners.
## The underlying badge/compass caches retain only their latest state, so they
## rebuilt all enemies whenever the pointer returned to an earlier target.
## Keep bounded, owned results; exact inputs (not the index) validate every hit.

const Memo = preload("res://scripts/combat_preview_memo.gd")
const Threats = preload("res://scripts/threat_tiles.gd")
var _badges := Memo.new()
var _compasses := Memo.new()

func clear() -> void:
	_badges = Memo.new()
	_compasses = Memo.new()

func rest_badges(host: Node, preview: Dictionary, focus: String, committed_override: Variant = null, skill_surface_events: Array = []) -> Dictionary:
	var engine: RefCounted = host._combat_engine
	var committed: Dictionary = host._combat_state if committed_override == null else committed_override as Dictionary
	var catalog: Dictionary = host.GameData.enemies()
	var definitions: Array = []
	_append_badge_definitions(definitions, catalog, committed)
	var committed_relics: Array = committed.get("relics", [])
	var preview_relics: Array = preview.get("relics", [])
	# Rites are already in the exact board inputs. Read relic effect sources
	# directly, since the engine expansion can lag catalog edits at the same IDs.
	var effects: Array = [_badge_relic_inputs(host.GameData, committed_relics)]
	if not is_same(committed, preview):
		_append_badge_definitions(definitions, catalog, preview)
		if preview_relics != committed_relics:
			effects.append(_badge_relic_inputs(host.GameData, preview_relics))
	var inputs: Array = [host._intent_badges, committed, preview, definitions,
		effects, engine.get_script(), engine._preview_facing_mode(), focus]
	# Preparation and the still-visible old board can share a tile. Retain
	# both exact states while the existing animation moves between them.
	# The memo checks its latest exact snapshot before hashing the index. Avoid
	# eagerly hashing unrelated decks/journals on each identical stage submit.
	var index: Array
	if is_instance_valid(host.board_view) and host.board_view._board_redraw_baseline():
		index = [hash(committed), hash(preview), focus]
	else:
		index = [committed.get("room_coord"), committed.get("turn"), committed.get("player"),
			preview.get("player"), preview.get("enemies"), focus]
	var known_source: Callable = host._surface_preview_information_state.bind(preview) if committed_override == null else host._surface_preview_information_state.bind(preview, committed)
	var badges: Dictionary = _badges.resolve(inputs, func() -> Dictionary:
		engine._relic_effect_cache_valid = false
		return host._intent_badges.presentation_for_state(engine, committed, preview,
			focus, known_source), index, true, true)
	# Keep Pass corrections on plates and reverse hover. A lifted preview
	# marker uses the present stamps, and the floor adds atk-11 contacts.
	if committed_override != null: return badges
	var Discs: GDScript = preload("res://scripts/pass_forecast_discs.gd")
	var Red: GDScript = preload("res://scripts/pass_forecast_red_tiles.gd")
	var revision: int = host._combat_preview_revision
	var at_rest: bool = is_same(preview, host._combat_state)
	var hovering_skill: bool = host._hovering_surface_skill()
	var marks: Dictionary
	var hovered_marks: Dictionary
	if hovering_skill or not at_rest:
		var hovered: Dictionary = host._hover_red_forecast()
		if not hovered.is_empty(): hovered_marks = Discs.record(hovered, revision)
	marks = host._rest_pass_disc_marks if at_rest or hovering_skill else hovered_marks
	if int(marks.get("revision", -1)) != revision: marks = {}
	var result: Dictionary = Discs.apply(badges, marks, revision, true)
	var floor_marks: Dictionary = marks
	if hovering_skill:
		floor_marks = Red.skill_contact_marks(marks, skill_surface_events, hovered_marks.get("hero_red_contacts", {}))
	var floor: Variant = Red.floor_override(badges, result, floor_marks)
	var present_rows: Array = badges.get("threats", [])
	var marker_override: bool = (not at_rest or hovering_skill) and present_rows != result.get("threats", [])
	if not result.has(Red.FLOOR_KEY) and floor == null and not marker_override: return result
	if is_same(result, badges): result = result.duplicate(false)
	if floor == null: result.erase(Red.FLOOR_KEY)
	else: result[Red.FLOOR_KEY] = floor
	if marker_override: result[Threats.MARKER_KEY] = present_rows
	return result

func _append_badge_definitions(definitions: Array, catalog: Dictionary, state: Dictionary) -> void:
	for enemy: Dictionary in state.get("enemies", []):
		definitions.append(catalog.get(str(enemy.get("type", "")), {}))

func _badge_relic_inputs(data: GDScript, ids: Array) -> Array:
	var inputs: Array = []
	if ids.is_empty(): return inputs
	var catalog: Dictionary = data.relics()
	for id: Variant in ids:
		var key: String = str(id)
		var definition: Dictionary = catalog.get(key, {})
		if bool(definition.get("retired", false)):
			key = data.resolve_relic_id(key)
			definition = catalog.get(key, {})
		inputs.append([key, definition.get("effects", []), definition.get("effect", ""), definition.get("value", 0)])
	return inputs

func compasses(host: Node, state: Dictionary, visible_ids: Array) -> Dictionary:
	var inputs: Array = _compass_inputs(state, visible_ids)
	return _compasses.resolve(inputs, func() -> Dictionary:
		return host.EnemyIntentCompass.descriptors_for_state(state, visible_ids), null, true, true)

func prepare_paths(host: Node, shown: Dictionary, slice_hidden: bool = false) -> void:
	var visible_paths: Array = [host._vector2i_array(shown.get("path_tiles", []))]
	for path: Array in shown.get("displacement_paths", []):
		visible_paths.append(host._vector2i_array(path))
	for threat: Dictionary in shown.get("enemy_threat_previews", []):
		visible_paths.append(host._vector2i_array(threat.get("projected_path", [])))
	var hidden_paths: Array = []
	for threat: Dictionary in shown.get("threats_at_rest", {}).get("threats", []):
		if bool(threat.get("later", false)): continue
		var path: Array[Vector2i] = host._vector2i_array(threat.get("plan", {}).get("projected_path", []))
		if path.size() < 2: continue
		if visible_paths.has(path):
			host.board_view.prepare_intent_path_geometry(path)
		elif not hidden_paths.has(path):
			hidden_paths.append(path)
	if hidden_paths.is_empty() or not host.is_inside_tree(): return
	var revision: int = host._combat_preview_revision
	if slice_hidden:
		# The first ready draw needs only its visible paths. Warm one other
		# route per boundary so a full set cannot land on the new turn frame.
		for path: Array[Vector2i] in hidden_paths:
			await host._next_enemy_round_preparation_frame()
			if not _path_warmup_current(host, revision): return
			_warm_hidden_paths(host, [path])
		return
	await host.get_tree().process_frame
	if not _path_warmup_current(host, revision): return
	_warm_hidden_paths(host, hidden_paths)

func _path_warmup_current(host: Node, revision: int) -> bool:
	return is_instance_valid(host) and host.is_inside_tree() and not host._leaving_tree and host._combat_preview_revision == revision and host._selected_card_index < 0 and not host._player_movement_selected

func _warm_hidden_paths(host: Node, paths: Array) -> void:
	var started: int = Time.get_ticks_usec() if host._runtime_performance_instrumentation_enabled else 0
	for path: Array[Vector2i] in paths:
		host.board_view.prepare_intent_path_geometry(path)
	host._record_runtime_performance_phase("stage_hidden_path_warmup", started)

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
	var started: int = Time.get_ticks_usec() if host._runtime_performance_instrumentation_enabled else 0
	# Match the foreground Pass information boundary, including opaque foes
	# and unseen ground in Umbra. The live scene still displays the old state.
	var source: Dictionary = preload("res://scripts/pass_forecast_action_source.gd").rest_source(host, state)
	if not host._combat_engine.is_player_turn(source): return
	var scheduled: Dictionary = preload("res://scripts/pass_forecast_red_tiles.gd").schedule(host._combat_engine, source)
	var cursor: Dictionary = host._combat_engine.begin_revealed_enemy_actions_preview(scheduled, true)
	host._record_runtime_performance_phase("committed_forecast_prepare", started)
	while not bool(cursor.get("complete", false)):
		await host.get_tree().process_frame
		if not is_instance_valid(host) or not host._committed_hand_query_active(generation): return
		started = Time.get_ticks_usec() if host._runtime_performance_instrumentation_enabled else 0
		host._combat_engine.advance_revealed_enemy_actions_preview(cursor)
		host._record_runtime_performance_phase("committed_forecast_slice", started)
	var phase_result: Dictionary = host._combat_engine.revealed_enemy_actions_preview_result(cursor)
	host._committed_hand_query_forecast = {"source": source, "result": phase_result}
	if host._runtime_performance_instrumentation_enabled:
		host._committed_hand_query_diagnostics["prepared_forecasts"] = int(host._committed_hand_query_diagnostics.get("prepared_forecasts", 0)) + 1
