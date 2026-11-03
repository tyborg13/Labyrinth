extends RefCounted
## Parent timing model from ec540eb59: show_blocked, expiry, and _draw pulse.
## Keep this independent of the production accumulator and its constants.
class ParentClock:
	extends RefCounted
	var now_msec: int = 0
	var blocked_until_msec: int = 0
	var feedback_visible: bool = false
	var reduced_motion: bool = false
	func show_blocked() -> void:
		blocked_until_msec = now_msec + 900
		feedback_visible = true
	func process_frame() -> void:
		if feedback_visible and now_msec >= blocked_until_msec:
			feedback_visible = false
	func pulse() -> float:
		return 1.0 if reduced_motion else 0.78 + 0.22 * sin(float(now_msec) * 0.005)

static func run_observed_script() -> GDScript:
	var source: String = preload("res://tests/helpers/presentation_test_clock.gd").source_for(preload("res://scripts/contextual_combat_prompt.gd"))
	source = source.replace("class_name ContextualCombatPrompt", "")
	source = source.replace("Time.get_ticks_usec()", 'preload("res://tests/helpers/presentation_test_clock.gd").now_usec')
	var start: int = source.find("\nfunc _draw()")
	var end: int = source.find("\nfunc ", start + 1)
	var pulse_line: String = ""
	for line: String in source.substr(start, end - start).split("\n"):
		if line.begins_with("\tvar pulse: float = "): pulse_line = line
	assert(not pulse_line.is_empty(), "Observe the actual production pulse expression")
	# Strip renderer calls only; execute the production expression, including
	# reduced motion, with its real process/draw signals and clock code intact.
	source = source.substr(0, start) + '\nfunc _draw() -> void:\n' + pulse_line + '\n\tset_meta("proof_pulse", pulse)\n' + source.substr(end)
	var script := GDScript.new()
	script.source_code = source
	assert(script.reload() == OK, "Observed prompt compiles")
	return script

static func pulse(prompt: Control) -> float:
	prompt.call("_draw")
	return float(prompt.get_meta("proof_pulse"))
