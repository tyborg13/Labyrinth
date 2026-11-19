extends "res://tools/qa110/whole_run.gd"
## Compare the already-published Pass totals with a full committed phase.
## Record before dispatch so the next live state can also be checked.

const Hud = preload("res://tools/qa101/qa99/hud.gd")
const Span = preload("res://tools/qa103/checkpoint_span.gd")
const PASS_LOSSES := {"hp_loss": "hp", "block_loss": "block", "stoneskin_loss": "stoneskin",
	"defiance_spent": "defiance_spent"}
const PASS_UNKNOWN := ["unrevealed_before_player", "umbra_unknown_before_player", "terminal_unknown",
	"unseen_ground_crossed", "new_arrival_before_player", "forecast_limit_reached"]

var pass_sample: Dictionary

func _initialize() -> void:
	super._initialize()
	if OS.get_environment("QA113_FIXED_STEP") == "1":
		Engine.max_fps = 0

func _record(action: Dictionary) -> void:
	super._record(action)
	if action.get("kind") != "pass": return
	var chip: Button = scene.find_child("PassPreviewChip", true, false)
	var shown: Dictionary = chip.get_meta("pass_forecast_summary", {}).duplicate(true) if chip != null else {}
	var before: Dictionary = scene._combat_state.duplicate(true)
	var receipt: Dictionary = {"actual": Hud._resolve(scene, before, before)}
	Span.complete(scene, receipt, Hud.INVALID)
	var actual: Dictionary = receipt["actual"]
	var unknowns: Array[String]
	for field: String in PASS_UNKNOWN:
		if bool(shown.get(field, false)): unknowns.append(field)
	if actual["audit_span_truncated"]: unknowns.append("audit_span_truncated")
	var fields: Dictionary = {}
	if unknowns.is_empty():
		for field: String in PASS_LOSSES:
			var resolved: int = int(actual["losses"][PASS_LOSSES[field]])
			if shown.get(field) != resolved: fields[field] = [shown.get(field), resolved]
		if int(shown.get("projected_hp", -1)) >= 0 and shown["projected_hp"] != actual["hp_after"]:
			fields["projected_hp"] = [shown["projected_hp"], actual["hp_after"]]
	var context: Dictionary = _context()
	context.erase("room_metadata")
	pass_sample = {"context": context, "turn": before["turn"], "unknown": unknowns, "fields": fields,
		"resolved_hp": actual["hp_after"], "first_phase_hp": actual["first_phase_hp_after"],
		"resolved_outcome": actual["outcome"], "skipped_turns": actual["skipped_turns"], "missing_forecast": shown.is_empty()}

func _tick() -> void:
	if not pass_sample.is_empty() and is_instance_valid(scene) and not scene._animation_lock and settle_frames == SETTLE_FRAMES:
		var state: Dictionary = scene._combat_state
		pass_sample["live_hp"] = state.get("player", {}).get("hp", scene._run_state.get("player_hp"))
		pass_sample["live_turn"] = state.get("turn")
		pass_sample["live_outcome"] = scene._combat_engine.combat_outcome(state) if not state.is_empty() else scene._run_state.get("mode", "")
		_emit("qa113_pass", pass_sample)
		pass_sample = {}
	super._tick()

func _emit(event: String, data: Dictionary) -> void:
	if event == "qa110_sample" and OS.get_environment("QA113_RED_WITNESS") == "1":
		var red: Array = data.get("checks", {}).get("red", [])
		if not red.is_empty():
			var hover: Dictionary = scene._pass_preview_cache.get(scene._hover_red_forecast_key, {})
			data["hover_correction"] = {"died_first": hover.get("died_first_keys", {}),
				"relative_areas": hover.get("relative_red_areas", {}), "selected_card": scene._selected_card_index}
	super._emit(event, data)
