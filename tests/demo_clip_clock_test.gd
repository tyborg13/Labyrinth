extends SceneTree

const Clock = preload("res://tools/demo_clips/clock.gd")
const Bank = preload("res://scripts/sfx_bank.gd")
var failures: Array[String]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fast: Array[Dictionary] = _simulate(0)
	var slow: Array[Dictionary] = _simulate(1)
	if fast != slow or fast.size() != 2: failures.append("presentation deadlines changed with host wall time")
	for event: Dictionary in fast:
		if event["frame"] >= 5 and event["frame"] < 10: failures.append("cue released during hit-stop")
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
	for index: int in range(60):
		if host_delay_ms > 0: OS.delay_msec(host_delay_ms)
		if index == 5: Engine.time_scale = 0.0
		if index == 10: Engine.time_scale = 2.0
		clock.tick()
		if index == 1: bank.play("spell.fire", {"peak_climax_ms": 200.0})
		if index == 2: bank.play("spell.ice", {"peak_deadline_ms": float(clock.visual_usec) / 1000.0 + 200.0})
		bank.advance(Engine.time_scale / Clock.FPS)
	bank.free()
	return events
