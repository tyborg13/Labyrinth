extends SceneTree

## The production resolver prefers case playback, then declared contact clips.
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Contact = preload("res://scripts/maquette_cutout_runtime/contact_actions.gd")
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	var mirror: Dictionary = {"type": "glacial_mirror", "intent": {"id": "crystal_guard"}}
	var guard: Dictionary = {"kind": "block", "action_type": "guard_ally", "source_actor_key": "enemy_1", "actor_key": "enemy_2"}
	var integration: Dictionary = Action.Presentation.integration_for("glacial_mirror")
	var original: Dictionary = integration.duplicate(true)
	integration["contact_playback_clips"] = ["guard"]
	check(Action.playback_adapter(guard, mirror) == preload("res://assets/units/glacial_mirror_cutout/actions.gd"), "case adapter wins when both handle")
	integration["action_adapter"] = "res://assets/units/briar_weaver_cutout/actions.gd"
	check(Action.playback_adapter(guard, mirror) == Contact, "contact adapter handles after case declines")
	check(Action.playback_adapter(dict_cancelled(guard), mirror) == null, "cancelled action falls through")
	integration.clear()
	integration.merge(original)
	check(Action.playback_adapter({"kind": "heal", "source_actor_key": "enemy_1", "actor_key": "enemy_2"}, {"type": "briar_weaver", "intent": {"id": "root_mend"}}) == preload("res://assets/units/briar_weaver_cutout/actions.gd"), "Weaver support case adapter")
	check(Action.playback_adapter({"action_type": "lob_mark", "intent_id": "lob_slag"}, {"type": "slag_mortar"}) == preload("res://assets/units/slag_mortar_cutout/actions.gd"), "Mortar case adapter")
	check(Action.playback_adapter({"en06_mirror": true}, {"type": "hollow_mimic"}) == Contact, "Mimic declared contact adapter")
	for type: String in ["hoarfrost_seer", "arc_thrall", "storm_capacitor", "crawler"]:
		check(Action.playback_adapter({}, {"type": type}) == null, "existing fallback " + type)
	for failure: String in failures: push_error(failure)
	print("RR26 ACTION DISPATCH: %s (%d checks; case priority, contact fallback and unchanged existing paths)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func dict_cancelled(step: Dictionary) -> Dictionary:
	var result: Dictionary = step.duplicate(true)
	result["cancelled"] = true
	return result
