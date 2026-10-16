extends "res://tests/fixtures/gust_shrike_capture_scene.gd"
## Reuse only the fixed presentation clock, never the shrike sampler or art.
var proof_actor_type: String = "bile_bloomer"

func record_action(clip: String, action: Callable) -> void:
	await super.record_action(clip, action)
	var renderer: Node = board_view.unit_cutout_renderer({"type": proof_actor_type, "id": 1})
	if renderer != null: proof_completions[clip] = renderer.snapshot()
