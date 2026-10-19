extends "res://tests/fixtures/gust_shrike_capture_scene.gd"
## Reuse only the fixed presentation clock, never the shrike sampler or art.
var proof_actor_type: String = "storm_capacitor"

func record_action(clip: String, action: Callable) -> void:
	if not _sfx_bank.cue_requested.is_connected(_proof_cue): _sfx_bank.cue_requested.connect(_proof_cue)
	proof_cue_start = proof_cues.size()
	await super.record_action(clip, action)
	var renderer: Node = board_view.unit_cutout_renderer({"type": proof_actor_type, "id": 1})
	if renderer != null:
		proof_completions[clip] = renderer.snapshot()
		proof_completions[clip]["charge"] = int(board_view.combat_state["enemies"][0].get("charge", 0))

var proof_cues: Array[Dictionary]
var proof_cue_start: int = 0

func _proof_cue(cue: String, result: String) -> void:
	proof_cues.append({"seconds": proof_elapsed_seconds, "cue": cue, "result": result})
