extends SceneTree

const Baker = preload("res://scripts/protagonist_cutout/gear_rest_baker.gd")
const GearSuite = preload("res://tests/suites/protagonist_gear_suite.gd")
const VyrakethSuite = preload("res://tests/suites/vyraketh_cutout_suite.gd")
const FAILURE_SIGNATURE: String = "gfix55-proof-failure"
var _checks: int = 0
var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--existing-only"):
		_check_failed_attachment()
		print("GFIX55 ATTACHMENT CLEANUP: %s (%d checks)" % ["PASS" if _failures.is_empty() else "FAIL", _checks])
	var gear_failure_start: int = _failures.size()
	var gear_check_start: int = _checks
	await GearSuite.run(self, _expect)
	print("PROTAGONIST GEAR SUITES: %d checks, %d failures" % [_checks - gear_check_start, _failures.size() - gear_failure_start])
	var vyraketh_failure_start: int = _failures.size()
	var vyraketh_check_start: int = _checks
	await VyrakethSuite.run(self, _expect)
	print("VYRAKETH CUTOUT SUITE: %d checks, %d failures" % [_checks - vyraketh_check_start, _failures.size() - vyraketh_failure_start])
	for failure: String in _failures: push_error(failure)
	print("GFIX55 FOCUSED: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _check_failed_attachment() -> void:
	# Exercise the attachment failure path even under the dummy renderer.
	var job := Baker.new()
	Baker._jobs[FAILURE_SIGNATURE] = job
	job.baked.connect(func(signature: String, texture: Texture2D) -> void:
		_expect(signature == FAILURE_SIGNATURE and texture == null, "Attachment failure signals a null bake")
		_expect(not Baker._jobs.has(signature), "Failure clears the pending job before notifying callers")
	)
	job.call("_attach_and_bake", null, FAILURE_SIGNATURE, {})
	_expect(job.is_queued_for_deletion(), "An unattached failed job is freed")

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
