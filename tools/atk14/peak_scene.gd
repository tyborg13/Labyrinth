extends "res://scripts/run_scene.gd"
## Proof-only scheduling: visit every authored frame on its presentation-clock
## deadline. Slow native draws catch up without discarding the selected pose.
const SkyBolts = preload("res://scripts/lightning_strike_presentation.gd")
var proof_owner: SceneTree

func _play_timed_animation_frames(count: int, seconds: float, render: Callable) -> void:
	if count <= 0 or not render.is_valid(): return
	var step_usec: int = maxi(0, roundi(seconds * 1000000.0))
	var schedule: Array[int]
	var required: Array[int]
	for index: int in range(count):
		schedule.append(index * step_usec)
		required.append(index)
	# Use Skybreak's frozen impact phase as the target. Round down onto the
	# actual authored frame grid (6 rule frames / cutout's existing frame count).
	var ideal: float = SkyBolts.Dragon.CONTACT + (1.0 - SkyBolts.Dragon.CONTACT) * SkyBolts.REDUCED_IMPACT_PROGRESS
	var peak_frame: int = clampi(floori(ideal * count), 1, count)
	var origin: int = _combat_pacing.presentation_usec()
	for index: int in required:
		while _combat_pacing.presentation_usec() - origin < schedule[index]: await get_tree().process_frame
		render.call(index + 1)
		var shown: Dictionary = board_view.get("presentation")
		if str(shown.get("effect", {}).get("kind", "")) == "lightning_strikes" and (index + 1 == peak_frame or _reduced_motion_enabled()):
			await proof_owner.call("_capture_peak", index + 1, count)
		await get_tree().process_frame
	while _combat_pacing.presentation_usec() - origin < count * step_usec: await get_tree().process_frame
