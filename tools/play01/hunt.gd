extends "res://tools/run_hunt.gd"
## Runs the existing controller against the production demo, with an in-memory SDK.

const FakeSteam = preload("res://tests/suites/steam_service_suite.gd").FakeSteam
const PROOF_SECONDS := 300
var fake: FakeSteam
var steam: Node
var deadline_usec: int
var finishing := false

func _start() -> void:
	var performance := root.get_node("PerformanceTelemetry")
	performance._sampling_enabled = false
	performance._local_storage_enabled = false
	performance._steam_stats_enabled = false
	performance._frame_samples_ms.clear()
	fake = FakeSteam.new()
	fake.app_id = 5575620
	steam = root.get_node("SteamService")
	steam._initialize_with_steam_for_test(fake, {"status": 0})
	steam._start_play_session()
	steam.set_process(true)
	deadline_usec = Time.get_ticks_usec() + PROOF_SECONDS * 1000000
	create_timer(PROOF_SECONDS, true, false, true).timeout.connect(_finish.bind("five_minute_cutoff"))
	await super._start()

func _demo_end(outcome: String) -> void:
	_finish(outcome)

func _finish(outcome: String) -> void:
	if finishing: return
	finishing = true
	finished = true
	# Let one completed run remain on its existing result screen until the
	# measurement ends. A still-active run is capped by the real-time timer.
	while Time.get_ticks_usec() < deadline_usec:
		await process_frame
	if is_instance_valid(scene):
		preload("res://scripts/run_persistence.gd").flush(scene)
	steam._flush_play_batches()
	var path := output.path_join("steam.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"stats": fake.stats, "store_calls": fake.store_calls, "run_clock_minute": steam._play.run_clock_minute}, "\t"))
	file.close()
	print("PLAY01 HUNT STEAM: " + ProjectSettings.globalize_path(path))
	steam.set_process(false)
	await super._finish(outcome)
	steam._steam = null
	steam._stats_dirty = false
	fake.free()
