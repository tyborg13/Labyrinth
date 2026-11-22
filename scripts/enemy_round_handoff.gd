extends RefCounted

const PassPreview = preload("res://scripts/retained_pass_preview.gd")
const CardPool = preload("res://scripts/run_card_pool_lifetime.gd")
const BattlefieldView = preload("res://scripts/battlefield_rule_view.gd")

var submitting_stage: bool = false
var _prepared: Dictionary = {}

# The committed turn is already authoritative. The old hand and the draw
# proxies keep their presentation until publish, even while these queries run.
func prepare(scene: Control) -> void:
	var revision: int = scene._combat_preview_revision
	var state: Dictionary = scene._combat_state
	var data: Dictionary = {"revision": revision, "state": state}
	_prepared = data
	await scene._next_enemy_round_preparation_frame()
	if not _active(scene, data): return
	var span: RefCounted = _trace(scene, "stage_visibility")
	var visibility: Dictionary = scene._stage_visibility_presentation(state)
	data["visibility"] = visibility
	data["compasses"] = scene._enemy_intent_compass_descriptors(state, visibility.get("visible_enemy_ids", []))
	data["objective_exits"] = scene._objective_exit_labels_for_board(state)
	data["objective_icons"] = scene._objective_exit_icon_ids_for_board(state)
	span = null

	await scene._next_enemy_round_preparation_frame()
	if not _active(scene, data): return
	span = _trace(scene, "stage_badges")
	_prepare_rest_badges(scene, state, data)
	span = null

	await scene._next_enemy_round_preparation_frame()
	if not _active(scene, data): return
	span = _trace(scene, "rail_projection")
	data["rail"] = scene._project_turn_order_entries(state)
	span = null

	await scene._next_enemy_round_preparation_frame()
	if not _active(scene, data): return
	span = _trace(scene, "movement_query")
	if scene._combat_engine.player_movement_remaining(state) > 0 and scene._combat_engine.is_player_turn(state):
		data["movement_enabled"] = scene._combat_engine.player_has_movement_target(state)
	span = null

	var hand: Array = state.get("deck", {}).get("hand", [])
	var remaining: Array[String] = scene._draw_hand_card_ids()
	var incoming: Array[String]
	for card_id: String in hand:
		var old_index: int = remaining.find(card_id)
		if old_index >= 0: remaining.remove_at(old_index)
		else: incoming.append(card_id)
	data["hand_definitions"] = {}
	data["hand_definition_signatures"] = {}
	if not incoming.is_empty():
		await scene._next_enemy_round_preparation_frame()
		if not _active(scene, data): return
		span = _trace(scene, "hand_pool")
		CardPool.prepare_hand(scene, incoming)
		span = null
	var copies: Dictionary = {}
	var owns_card_inputs: bool = state.has("card_upgrades") or state.has("card_mods") or state.has("skill_ids") or state.has("relics")
	for index: int in range(hand.size()):
		await scene._next_enemy_round_preparation_frame()
		if not _active(scene, data): return
		span = _trace(scene, "hand_card")
		var card_id: String = str(hand[index])
		# Legacy states without their own definition inputs resolve against the
		# progression available after header reconciliation.
		var display: Dictionary
		if owns_card_inputs:
			scene._card_playability_for_index(index)
			display = scene._card_widget_display_for_index(index)
			if not data["hand_definitions"].has(card_id):
				var definition: Dictionary = scene._card_def(card_id, state)
				data["hand_definitions"][card_id] = definition
				data["hand_definition_signatures"][card_id] = hash(definition)
		if incoming.has(card_id):
			var card_size: Vector2 = scene._hand_card_size(hand.size(), false)
			var copy_index: int = int(copies.get(card_id, 0))
			var entry: Dictionary = scene._prepare_opening_hand_pool_entry(card_id, card_size, state, copy_index)
			entry["prepared_enemy_round_revision"] = revision
			var widget: Control = entry["widget"]
			if not owns_card_inputs: display = scene._card_widget_display(card_id, state)
			widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []), int(display.get("time_surcharge", 0)))
			incoming.erase(card_id)
			copies[card_id] = copy_index + 1
		span = null

	# Build the rule forecast in the memo shared by board submission. Passing
	# only board visibility keeps the forecast free of current pointer/pose data.
	if BattlefieldView.eligible(state, visibility):
		await scene._next_enemy_round_preparation_frame()
		if not _active(scene, data): return
		span = _trace(scene, "battlefield_rule")
		scene.board_view._battlefield_rule_presentation_for(state, visibility)

# The Pass simulation already owns its budgeted post-draw slices. Prepare the
# retaining button's data once the exact forecast is available on those slices.
func prepare_pass(scene: Control, cache_key: String) -> void:
	var data: Dictionary = _prepared
	if not _active(scene, data) or not scene._pass_preview_cache.has(cache_key): return
	var span: RefCounted = _trace(scene, "pass_face")
	var summary: Dictionary = scene._pass_preview_cache[cache_key]
	data["pass_face"] = PassPreview.face(scene, summary, scene._pending_card_defiance_spent())
	# The forecast may have corrected the rest badges after their earlier slice.
	if data.has("rest_marks") and data["rest_marks"] != scene._rest_pass_disc_marks:
		_prepare_rest_badges(scene, scene._combat_state, data)

func _prepare_rest_badges(scene: Control, state: Dictionary, data: Dictionary) -> void:
	data["rest_marks"] = scene._rest_pass_disc_marks
	data["rest_badges"] = scene._stage_hover_refresh.rest_badges(scene, state, "")

func publish(scene: Control) -> void:
	var data: Dictionary = _prepared if _active(scene, _prepared) else {}
	_prepared = {}
	scene._finish_pass_preview_cache_warm(scene._pass_preview_warm_generation, scene._pass_preview_warm_key)
	var span: RefCounted
	if scene._hitch_trace_enabled: span = scene._hitch_sink().hitch_phase("post_draw:run_scene:enemy_round_handoff_ready")
	var started: int = _ticks(scene)
	var step: int = started
	scene._begin_ui_refresh(false)
	scene._refresh_ui_header()
	step = scene._record_runtime_performance_phase("enemy_round_ready_header_total", step)
	# Header reconciliation can replace the run/combat snapshot. A revision or
	# identity change returns to the synchronous path, just like a short draw.
	if not _current(scene, data): data = {}
	scene._refresh_ui_navigation(data.get("rail"))
	step = scene._record_runtime_performance_phase("enemy_round_ready_navigation_total", step)
	scene._unlock_after_ui_refresh(true)
	step = scene._record_runtime_performance_phase("enemy_round_ready_unlock_total", step)
	submitting_stage = true
	scene._refresh_ui_choices(null, data)
	step = scene._record_runtime_performance_phase("enemy_round_ready_choices_total", step)
	if data.get("rest_marks") != scene._rest_pass_disc_marks: data.erase("rest_badges")
	scene._refresh_ui_stage(data)
	submitting_stage = false
	step = scene._record_runtime_performance_phase("enemy_round_ready_board_total", step)
	data["adopt_faces"] = true
	scene._refresh_ui_hand(data)
	step = scene._record_runtime_performance_phase("enemy_round_ready_hand_total", step)
	scene._refresh_ui_finish()
	scene._end_ui_refresh(false)
	scene._record_runtime_performance_phase("enemy_round_ready_finish_total", step)
	scene._record_runtime_performance_phase("enemy_round_final_refresh_ui_wall_total", started)

func _current(scene: Control, data: Dictionary) -> bool:
	return int(data.get("revision", -1)) == scene._combat_preview_revision and is_same(data.get("state"), scene._combat_state)

func _active(scene: Control, data: Dictionary) -> bool:
	return is_instance_valid(scene) and is_same(data, _prepared) and _current(scene, data) and scene._enemy_round_preparation_active(data["revision"])

static func _ticks(scene: Control) -> int:
	return Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0

static func _trace(scene: Control, section: String) -> RefCounted:
	return scene._hitch_sink().hitch_phase("post_draw:run_scene:enemy_round_prepare_" + section) if scene._hitch_trace_enabled else null
