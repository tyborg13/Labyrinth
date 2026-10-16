extends SceneTree

const Clock = preload("res://tools/demo_clips/clock.gd")
const Bank = preload("res://scripts/sfx_bank.gd")
var failures: Array[String]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fast: Array[Dictionary] = _simulate(0)
	var slow: Array[Dictionary] = _simulate(1)
	if fast != slow or fast.size() != 3: failures.append("presentation deadlines changed with host wall time")
	for event: Dictionary in fast:
		if event["frame"] >= 5 and event["frame"] < 10: failures.append("cue released during hit-stop")
		if event["cue"] == "surface.fire" and event["frame"] != 3: failures.append("scale-1 deadline must dispatch at frame 3")
		if event["cue"] == "spell.ice" and event["frame"] != 11: failures.append("paused then scale-2 deadline must dispatch at frame 11; got %d" % int(event["frame"]))
	Engine.time_scale = 1.0
	print("DEMO MOVIE CLOCK TEST: %s (%d cue events)" % ["PASS" if failures.is_empty() else "FAIL", fast.size()])
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _simulate(host_delay_ms: int) -> Array[Dictionary]:
	var clock := Clock.new()
	var bank := Bank.new()
	root.add_child(bank)
	bank.set_process(false)
	bank.warm_up(bank, {}, 410)
	clock.bank = bank
	bank.presentation_clock = func() -> int: return int(clock.visual_usec)
	var events: Array[Dictionary]
	bank.cue_requested.connect(func(cue: String, result: String) -> void:
		events.append({"cue": cue, "result": result, "frame": clock.frame})
	)
	Engine.time_scale = 1.0
	var expected_visual: float = Clock.EPOCH_USEC
	for index: int in range(60):
		if host_delay_ms > 0: OS.delay_msec(host_delay_ms)
		if index == 5: Engine.time_scale = 0.0
		if index == 10: Engine.time_scale = 2.0
		clock.tick()
		# Independent oracle: four advancing scale-1 ticks, five frozen ticks,
		# then scale-2 ticks. Raw movie time advances at every fixed frame.
		if index > 0:
			expected_visual += 1000000.0 / 60.0 * (1.0 if index < 5 else 0.0 if index < 10 else 2.0)
		if clock.frame != index or clock.usec != Clock.EPOCH_USEC + roundi(float(index) * 1000000.0 / 60.0):
			failures.append("raw movie clock differs at frame %d" % index)
		if absf(clock.visual_usec - expected_visual) > 0.001:
			failures.append("scaled presentation clock differs at frame %d: %.3f != %.3f" % [index, clock.visual_usec, expected_visual])
		if index == 0: bank.play("surface.fire", {"peak_deadline_ms": float(Clock.EPOCH_USEC) / 1000.0 + 40.0})
		if index == 1: bank.play("spell.fire", {"peak_climax_ms": 200.0})
		if index == 2: bank.play("spell.ice", {"peak_deadline_ms": float(clock.visual_usec) / 1000.0 + 90.0})
		bank.advance(Engine.time_scale / Clock.FPS)
	bank.free()
	return events
