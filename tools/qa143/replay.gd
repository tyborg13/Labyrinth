extends "res://tools/run_hunt.gd"
## Bounded controls adapted from qa-141 and qa-142's production RunScene replays.

const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const SAVE_STAGES = ["none", "before", "mid", "after", "written"]
const FIXTURE_TIME_SCALE: float = 4.0
const PRIMARY_SEED: int = 141010
const CRAWLER_INTENT: String = "skitter_strike"

var _target_decision: int
var _stage: String
var _guide_seeded: bool
var _saved: bool
var _turn: int
var _round_seen: bool
var _surface_start: int

func _initialize() -> void:
	_target_decision = int(OS.get_environment("QA143_DECISION"))
	_stage = OS.get_environment("QA143_STAGE")
	assert(_target_decision > 0 and _stage in SAVE_STAGES)
	super._initialize()
	Engine.max_fps = 0
	Engine.time_scale = FIXTURE_TIME_SCALE

func _enter_scene(resume: bool) -> void:
	if not _guide_seeded:
		_guide_seeded = true
		Store.save_data(Tutorial.complete_tutorial(Store.load_data()))
	super._enter_scene(resume)

func _side_action() -> bool:
	for kind: String in ["reduced_motion", "resume"]: sides[kind] = true
	return super._side_action()

func _record(action: Dictionary) -> void:
	super._record(action)
	if decision == _target_decision:
		_turn = int(scene._combat_state.get("turn", 0))
		_surface_start = int(scene._combat_state.get("surface_event_sequence", 0))

func _tick() -> void:
	if finished or busy or not is_instance_valid(scene) or not scene.has_installed_run(): return
	if decision != _target_decision:
		super._tick()
		return
	var held: Dictionary = scene._committed_run_state_override
	var pending := _pending_round(held)
	if pending: _round_seen = true
	if _save_boundary(pending):
		busy = true
		_save_and_continue()
		return
	if scene._animation_lock or not _round_seen: return
	if int(scene._combat_state.get("turn", 0)) != _turn + 1: return
	if not scene._combat_engine.is_player_turn(scene._combat_state): return
	if _saved != (_stage != "none"):
		push_error("QA143 missed the %s save point before player input" % _stage)
		finished = true
		quit(1)
		return
	var events := Analytics.load_all_events()
	_emit("qa143_result", {
		"stage": _stage,
		"combat_id": scene._combat_state["analytics"]["combat_id"],
		"surface_start": _surface_start,
		"state": _combat_receipt(scene._run_state),
		"event_count": events.size(),
	})
	_finish("qa143_player_input")

func _pending_round(state: Dictionary) -> bool:
	var checkpoints: Array = state.get("pending_combat_checkpoints", [])
	return checkpoints.any(func(checkpoint: Dictionary) -> bool: return bool(checkpoint.get("resume_enemy_phase", false)))

func _save_boundary(pending: bool) -> bool:
	if not _round_seen or _saved: return false
	if _stage == "written":
		return not pending and not scene._animation_lock and int(scene._combat_state.get("turn", 0)) == _turn + 1
	if not scene._animation_lock: return false
	match _stage:
		"before":
			return pending and scene._enemy_round_initiative.is_empty() and scene._combat_pacing._phase == "banner"
		"mid":
			if hunt_seed == PRIMARY_SEED: return pending and _mid_strike()
			return pending and scene._combat_pacing._phase == "post-action settle"
		"after":
			return pending and scene._combat_pacing._phase == "hero hand-off"
	return false

func _mid_strike() -> bool:
	var preview: Dictionary = scene.board_view.presentation
	var effect: Dictionary = preview.get("strike_trail_effect", preview.get("effect", {}))
	if effect.get("kind") != "melee" or effect.get("intent_id") != CRAWLER_INTENT: return false
	if hunt_seed == PRIMARY_SEED and (effect.get("from") != Vector2i(3, 5) or effect.get("to") != Vector2i(4, 5)): return false
	# The qa-141 point requires a submitted generic melee trail.
	var hosts: Array = scene.board_view._retained_render_layers().duplicate()
	hosts.append(scene.board_view)
	for host: Node in hosts:
		var trail: Node = host.get("_strike_trail_layer")
		if is_instance_valid(trail) and not (trail.get("_batches") as Array).is_empty(): return true
	return false

func _save_and_continue() -> void:
	var old_scene: WeakRef = weakref(scene)
	var playback: String = scene._combat_pacing._phase
	await scene._save_for_quit()
	var saved: Dictionary = Store.load_checkpoint_for_resume()
	_emit("qa143_save", {
		"stage": _stage, "playback": playback, "pending": _pending_round(saved),
		"state": _combat_receipt(saved), "event_count": Analytics.load_all_events().size(),
	})
	scene.queue_free()
	current_scene = null
	for frame: int in range(SETTLE_FRAMES): await process_frame
	assert(old_scene.get_ref() == null)
	_saved = true
	_enter_scene(true)
	busy = false

func _combat_receipt(run: Dictionary) -> Dictionary:
	var fight: Dictionary = run.get("combat_state", {})
	var enemies: Dictionary = {}
	for enemy: Dictionary in fight.get("enemies", []):
		enemies[str(enemy.get("id"))] = [enemy.get("pos"), enemy.get("hp"), enemy.get("intent")]
	var player: Dictionary = fight.get("player", {})
	return {
		"mode": run.get("mode"), "room": run.get("current_room"), "turn": fight.get("turn"),
		"player": [player.get("pos"), player.get("hp")], "enemies": enemies,
		"queue": fight.get("turn_queue"), "hand": fight.get("deck", {}).get("hand"),
	}
