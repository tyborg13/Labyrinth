extends "res://scripts/run_scene.gd"

# Observe submissions at the real popup boundary, while retaining production
# movement, state application, pacing, floating text and renderer behavior.
var popup_submissions: Array[Dictionary]
var feedback_phase: String = "beam"
var defeat_submissions: Array[String]
var defeat_owners: Array[Dictionary]
var applied_steps: Array[Dictionary]
var illusion_fades: Array[Dictionary]
var move_starts: Array[Dictionary]
var burst_sources: Array[int]
var burst_cue_starts: Array[int]
var _last_burst_source: int = -1
var feedback_source_id: int = -1
var proof_state: Dictionary
var state_submissions: Array[Dictionary]

func _apply_animation_step(state: Dictionary, step: Dictionary) -> void:
	feedback_source_id = int(step.get("cascade", {}).get("id", -1))
	if str(step.get("action_type", "")) in ["retaliate", "illusion_retort", "death_burst", "surface_death", "spawn_arrival", "activation_fire"]: feedback_phase = str(step["action_type"])
	if bool(step.get("traced_bleed", false)): feedback_phase = "bleed_move" if step["action_type"] in ["move_toward", "move_away"] else "bleed_attack"
	if step.has("en03_after") or step.has("en06_after"): feedback_phase = "beam"
	var illusions_before: Array = (state.get("illusions", []) as Array).duplicate(true)
	var before_hp: int = int(state["enemies"][0]["hp"])
	super._apply_animation_step(state, step)
	if is_same(state, proof_state) and not preload("res://tests/helpers/fix_15_state_invariant.gd").payload(step).is_empty():
		state_submissions.append({"step": step.duplicate(true), "state": state.duplicate(true)})
	for illusion: Dictionary in illusions_before:
		if int(illusion.get("hp", 0)) > 0 and int(_combat_engine._surface_actor(state, "illusion", int(illusion["id"])).get("hp", 0)) <= 0:
			illusion_fades.append({"key": "illusion_%d" % int(illusion["id"]), "phase": feedback_phase})
	applied_steps.append({"phase": feedback_phase, "before_hp": before_hp, "after_hp": int(state["enemies"][0]["hp"])})

func _animate_turn_order_alongside_defeats(before: Dictionary, after: Dictionary, presentation: Dictionary = {}, skip_terrain: bool = false, order_before: Dictionary = {}) -> void:
	# Observe the shared boundary before pacing chooses blocking or overlapping
	# death playback; both are production paths for the same defeat.
	for _player: Dictionary in _defeated_player_units_between_states(before, after):
		defeat_submissions.append("player")
		defeat_owners.append({"key": "player", "phase": feedback_phase})
	for enemy: Dictionary in _defeated_enemy_units_between_states(before, after):
		defeat_submissions.append(_enemy_key(enemy))
		defeat_owners.append({"key": _enemy_key(enemy), "phase": feedback_phase})
	await super._animate_turn_order_alongside_defeats(before, after, presentation, skip_terrain, order_before)

func _animate_move_step(state: Dictionary, step: Dictionary) -> void:
	feedback_phase = "move"
	move_starts.append({"hp": state["enemies"][0]["hp"], "tile": state["enemies"][0]["pos"], "from": step["from"]})
	await super._animate_move_step(state, step)
	feedback_phase = "beam"

func _animate_floating_text_presentation(state: Dictionary, presentation: Dictionary, initial_elapsed_seconds: float = 0.0, overlap_with_next_action: bool = false, companion_completion: Dictionary = {}) -> void:
	for entry: Dictionary in presentation.get("floating_texts", []):
		popup_submissions.append({"phase": feedback_phase, "source_id": feedback_source_id, "entry": entry.duplicate(true), "actor_hp": state["enemies"][0]["hp"], "actor_tile": state["enemies"][0]["pos"], "hero_hp": state["player"]["hp"]})
	await super._animate_floating_text_presentation(state, presentation, initial_elapsed_seconds, overlap_with_next_action, companion_completion)

func _render_board_state(state: Dictionary, presentation: Dictionary, state_stable_since_last_submission: bool = false) -> void:
	if presentation.has("en01_burst"):
		var source: int = int(presentation["en01_burst"]["id"])
		if source != _last_burst_source: burst_sources.append(source)
		_last_burst_source = source
	else:
		_last_burst_source = -1
	super._render_board_state(state, presentation, state_stable_since_last_submission)

func _play_sfx(entry: Dictionary) -> float:
	if feedback_phase == "death_burst" and entry == preload("res://scripts/attack_sfx_library.gd").entry_for_enemy_action({"type": "aoe", "element": "fire"}): burst_cue_starts.append(feedback_source_id)
	return super._play_sfx(entry)
