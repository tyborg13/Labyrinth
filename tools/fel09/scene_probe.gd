extends "res://scripts/run_scene.gd"
## Instrumentation lives in this probe subclass. Every production method is
## called once with its original inputs and scheduling policy.

const ATTACK_STEPS := ["melee", "ranged", "aoe", "push", "pull", "lightning_strikes"]
const CensusPacing = preload("res://tools/fel09/pacing_probe.gd")

var census
var round_finished: bool = false
var _rail_serial: int = 0
var _walk_serial: int = 0
var _contact_step: int = -2
var _impact_step: int = -2
var _windup_step: int = -2
var _sample_number: int = 0
var _sample_count: int = 0
var _span_serial: int = 0


func _ready() -> void:
	_combat_pacing.free()
	_combat_pacing = CensusPacing.new()
	_combat_pacing.census = census
	_combat_pacing.install(self)
	super._ready()
	_combat_pacing.hit_stop.stop_started.connect(_census_stop_started)
	_combat_pacing.hit_stop.stop_ended.connect(_census_stop_ended)


func can_pass() -> bool:
	return has_installed_run() and _pass_preview_action_available() and not _controller_modal_visible()


func accepts_hero_input() -> bool:
	return (
		has_installed_run() and not _animation_lock and not _dialogue_active
		and not _pending_umbra_commit_locked and not _controller_modal_visible()
		and _run_state.get("mode") == "combat" and _combat_engine.is_player_turn(_combat_state)
	)


func witness_hero_input() -> String:
	var hero_tile: Vector2i = _combat_state["player"]["pos"]
	_on_board_tile_clicked(hero_tile)
	if _player_movement_selected: return "hero tile opened movement selection"
	for index: int in (_combat_state["deck"]["hand"] as Array).size():
		if _guided_tutorial_card_allowed(index) and _combat_engine.hand_card_has_play_budget(_combat_state, index):
			_on_card_pressed(index)
			if _selected_card_index == index: return "card %d entered selection" % index
	return ""


func _on_pass_turn_pressed() -> void:
	await super._on_pass_turn_pressed()
	if census.active(): round_finished = true


func _finish_enemy_round_player_handoff() -> void:
	census.end_action(census.step)
	census.step = -1
	census.actor = ""
	census.begin("publish hero UI", "publish", "enemy_round_handoff.gd:114")
	super._finish_enemy_round_player_handoff()
	census.end("publish")


func _show_turn_banner(player_turn: bool) -> void:
	if census.active() and player_turn and _turn_banner_blocked():
		census.mark("hero turn banner suppressed", "run_scene.gd:4001", {"boss_hud_or_caption": true})
	super._show_turn_banner(player_turn)
	if census.active() and _turn_banner.visible:
		census.mark("hero turn banner requested" if player_turn else "enemy turn banner requested", "run_scene.gd:3996")


func _animate_turn_order_transition(before_order: Array[Dictionary], after_order: Array[Dictionary], defeated_actor_keys: Dictionary = {}) -> void:
	_rail_serial += 1
	var id: String = "rail:%d" % _rail_serial
	var supersede: int = _turn_order_supersede_serial
	var observe: bool = census.active() and not _reduced_motion_enabled() and not before_order.is_empty() and _turn_order_signature(before_order) != _turn_order_signature(after_order)
	if observe: census.begin("turn-order rail", id, "run_scene.gd:12596")
	await super._animate_turn_order_transition(before_order, after_order, defeated_actor_keys)
	if observe and supersede == _turn_order_supersede_serial: census.end(id)


func _finish_turn_order_transition_now() -> void:
	if census.active(): census.end("rail:%d" % _rail_serial)
	super._finish_turn_order_transition_now()


func _animate_actor_along_path(display_state: Dictionary, actor_key: String, path: Array[Vector2i], base_presentation: Dictionary) -> void:
	_walk_serial += 1
	var id: String = "walk:%d" % _walk_serial
	if census.active() and path.size() > 1:
		census.begin("unit move", id, "run_scene.gd:25541", {"actor": actor_key, "tiles": path.size() - 1})
	await super._animate_actor_along_path(display_state, actor_key, path, base_presentation)
	census.end(id)


func _animate_draw_cards_fx(draw_entries: Array, source_rect_override: Rect2 = Rect2(), draw_sfx_count: int = -1, hand_transition: Dictionary = {}) -> void:
	if census.active() and not draw_entries.is_empty():
		census.begin("hand draw", "draw", "run_scene.gd:22362", {"cards": draw_entries.size()})
	await super._animate_draw_cards_fx(draw_entries, source_rect_override, draw_sfx_count, hand_transition)
	census.end("draw")


func _begin_locked_hand_render_cache() -> void:
	if census.active(): census.begin("locked hand capture", "lock cache", "run_scene.gd:10119")
	await super._begin_locked_hand_render_cache()
	census.end("lock cache")


func _play_sampled_animation_frames(frame_count: int, frame_seconds: float, render_frame: Callable, sample_clock: Callable, strike: TileBurstFx.StrikeCue = null) -> void:
	if not census.active() or not render_frame.is_valid() or frame_count <= 0:
		await super._play_sampled_animation_frames(frame_count, frame_seconds, render_frame, sample_clock, strike)
		return
	_span_serial += 1
	var id: String = "playback:%d" % _span_serial
	var sample: Callable = func(frame: int) -> void:
		_sample_number = frame
		_sample_count = frame_count
		render_frame.call(frame)
		_sample_number = 0
		_sample_count = 0
	census.begin("sampled playback", id, "run_scene.gd:22980", {
		"authored_ms": frame_count * frame_seconds * 1000.0, "frames": frame_count,
	})
	await super._play_sampled_animation_frames(frame_count, frame_seconds, sample, sample_clock, strike)
	census.end(id)


func _animate_floating_text_presentation(display_state: Dictionary, base_presentation: Dictionary, initial_elapsed_seconds: float = 0.0, overlap_with_next_action: bool = false, companion_completion: Dictionary = {}, on_contact: Callable = Callable()) -> void:
	_span_serial += 1
	var id: String = "feedback:%d" % _span_serial
	if census.active():
		var texts: Array = base_presentation.get("floating_texts", [])
		census.begin("floating feedback", id, "run_scene.gd:22754", {"numbers": texts.size()})
	await super._animate_floating_text_presentation(display_state, base_presentation, initial_elapsed_seconds, overlap_with_next_action, companion_completion, on_contact)
	census.end(id)


func _animate_defeats_and_terrain_destruction(before_state: Dictionary, after_state: Dictionary, base_presentation: Dictionary = {}, skip_terrain_destruction: bool = false) -> void:
	_span_serial += 1
	var id: String = "defeats:%d" % _span_serial
	if census.active(): census.begin("defeat playback", id, "run_scene.gd:23022")
	await super._animate_defeats_and_terrain_destruction(before_state, after_state, base_presentation, skip_terrain_destruction)
	census.end(id)


func _animate_turn_start_fire(display_state: Dictionary, burn: Dictionary) -> void:
	if census.active(): census.begin("hero turn-start fire", "fire", "run_scene.gd:23276")
	await super._animate_turn_start_fire(display_state, burn)
	census.end("fire")


func _animate_fatigue_damage(display_state: Dictionary, fatigue_events: Array[Dictionary]) -> void:
	if census.active(): census.begin("hero fatigue", "fatigue", "run_scene.gd:23244")
	await super._animate_fatigue_damage(display_state, fatigue_events)
	census.end("fatigue")


func _apply_animation_step(animated_state: Dictionary, step: Dictionary) -> void:
	super._apply_animation_step(animated_state, step)
	if not census.active(): return
	var kind: String = str(step.get("kind", ""))
	if kind in ["status_damage", "status", "block", "heal", "stoneskin", "surface", "summon", "reinforcement_spawn", "burrow", "erupt", "worldspine_pulse"] or step.get("battlefield_rule_step", false):
		var detail: Dictionary = {
			"kind": kind, "label": str(step.get("label", "")), "rule": str(step.get("rule_id", "")),
			"actor": str(step.get("actor_key", "")), "target": str(step.get("to", step.get("tile", ""))),
		}
		census.mark("status tick" if kind == "status_damage" else "resolved " + kind, "run_scene.gd:26485", detail)


func _render_board_state(display_state: Dictionary, presentation: Dictionary, state_stable_since_last_submission: bool = false) -> void:
	super._render_board_state(display_state, presentation, state_stable_since_last_submission)
	if not census.active(): return
	var effect: Dictionary = presentation.get("effect", {})
	var step: int = census.step
	var dispatched: Dictionary = census.steps[step] if step >= 0 else {}
	var kind: String = str(dispatched.get("kind", effect.get("kind", "")))
	var explicit_clip: bool = bool(presentation.get("maquette_explicit_clip", false))
	var prepared_pose: bool = presentation.has("harrier_motion") or presentation.has("iskaldra_motion")
	var visual_attack: bool = kind in ATTACK_STEPS and (
		str(effect.get("kind", "")) in ATTACK_STEPS or explicit_clip or prepared_pose
	)
	var at: float = census.now_ms()
	if visual_attack and _windup_step != step:
		_windup_step = step
		census.mark("attack wind-up", "run_scene.gd:26102", {"kind": kind, "sample": _sample_number}, at)

	var impacts: Array = presentation.get("impact_actor_keys", [])
	var evidence: String = ""
	if visual_attack:
		var icefall: String = str(effect.get("icefall_phase", ""))
		if icefall == "puff":
			evidence = "Icefall entered its authored contact phase"
		elif icefall.is_empty() and str(effect.get("kind", "")) in ATTACK_STEPS and (
			explicit_clip or float(presentation.get("effect_progress", -1.0)) >= _attack_feedback_start_progress(effect)
		):
			evidence = "contact effect submitted" if explicit_clip else "effect progress reached feedback threshold"
		elif icefall.is_empty() and not impacts.is_empty():
			evidence = "attack impact targets submitted"
	if _contact_step != step and not evidence.is_empty():
		_contact_step = step
		census.mark("contact", "run_scene.gd:26102", {
			"evidence": evidence, "sample": _sample_number, "sample_count": _sample_count,
			"process_frame": Engine.get_process_frames(),
		}, at)
	var shown: Dictionary = board_view.presentation
	if _impact_step != step and (
		not evidence.is_empty() or not impacts.is_empty()
		or not (shown.get("combat_feel_hits", []) as Array).is_empty()
		or not (shown.get("impact_decals", []) as Array).is_empty()
	):
		_impact_step = step
		census.mark("impact effect start", "run_scene.gd:26102", {"targets": impacts}, at)


func _census_stop_started(duration_ms: float) -> void:
	if census.active(): census.begin("hit stop", "hit stop", "combat_hit_stop.gd:45", {"requested_ms": duration_ms})


func _census_stop_ended() -> void:
	if census.active(): census.end("hit stop")
