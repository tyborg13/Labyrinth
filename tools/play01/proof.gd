extends SceneTree

const Play = preload("res://scripts/play_stats.gd")
const FakeSteam = preload("res://tests/suites/steam_service_suite.gd").FakeSteam
const Manifest := "res://steam/play_stats_manifest.json"
const QUEUE := "user://play01-proof-queue.json"
const MARKER := "user://play01-proof-marker.json"
const FIRST_DAY_LOOKBACK := 10
var first_day: int
var steam: Node
var fake: FakeSteam
var checks := 0
var failures: Array[String]
var seen: Dictionary = {}

class DeckSteam extends FakeSteam:
	func isSteamRunningOnSteamDeck() -> bool:
		return true

func _initialize() -> void:
	call_deferred("_prove")

func _prove() -> void:
	OS.set_environment("LABYRINTH_DEMO", "1")
	var performance := root.get_node("PerformanceTelemetry")
	performance._sampling_enabled = false
	performance._steam_stats_enabled = false
	performance._frame_samples_ms.clear()
	first_day = int(Time.get_unix_time_from_system()) / Play.DAY_SECONDS - FIRST_DAY_LOOKBACK
	steam = root.get_node("SteamService")
	fake = FakeSteam.new()
	fake.app_id = 5575620
	fake.auto_complete_stats_request = false
	steam._set_stats_queue_path_for_test(QUEUE)
	steam._play_session_path_override = MARKER
	steam._initialize_with_steam_for_test(fake, {"status": 0})
	steam._play = Play.new()

	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Manifest))
	var kinds := Play.kinds()
	var manifest_kinds: Dictionary = {}
	for stat: Dictionary in manifest["stats"]: manifest_kinds[stat["name"]] = stat["kind"]
	_expect(kinds == manifest_kinds and kinds.size() == 77, "runtime allowlist matches all 77 protected manifest entries")

	steam._play.launch(first_day, "Windows", false)
	steam.record_play_signal("menu_loaded")
	steam.record_play_signal("menu_loaded")
	_observe("run_started", "one")
	_observe("run_ended", "one", {"outcome": "victory"})
	_observe("run_started", "two")
	_observe("run_ended", "two", {"outcome": "embrace"})
	steam._play.launch(first_day + 1, "macOS", false)
	steam._flush_play_batches()
	_expect(fake.stats.is_empty() and FileAccess.file_exists(QUEUE), "pre-readiness operations persist without writing Steam")
	var disk: Dictionary = steam._read_play_json(QUEUE)
	_expect(disk.get("play_batches", []).size() == 8, "condition-bearing batches preserve event order")
	steam._queued_play_batches.clear()
	steam._restore_queued_stat_deltas()
	fake.user_stats_received.emit(fake.app_id, 1, fake.steam_id.to_int())
	_delta({}, {
		"first_day": first_day, "p_os_windows": 1, "p_os_macos": 1,
		"p_launched": 1, "sessions": 1, "p_run_started": 1, "runs_started": 2,
		"p_boss_won": 1, "runs_won": 1, "p_run2": 1, "p_run_after_win": 1,
		"runs_withdrew": 1, "p_day2": 1,
	}, "ready applies persisted launch/new run/win in order")
	var before := fake.stats.duplicate()
	steam._play.launch(first_day + 7, "Linux", false)
	steam._flush_play_batches()
	_delta(before, {"p_day7": 1, "p_os_linux": 1}, "week return and Linux, first day/window flags stay capped")

	_prove_combat()
	_prove_lifecycle()
	_prove_store()
	await _prove_idle_flush()
	_prove_marker()
	_prove_deck()
	_prove_undefined_full_schema()

	for name: String in kinds:
		_expect(seen.has(name), "emission exercised: " + name)
	print("PLAY01 RESULT: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	for message: String in failures: push_error(message)
	steam._steam = null
	steam._stats_dirty = false
	fake.free()
	quit(0 if failures.is_empty() else 1)

func _prove_combat() -> void:
	_event("run_resumed", "two", {}, {"runs_resumed": 1})
	_event("combat_ended", "two", {"outcome": "victory"}, {"fights_won": 1, "p_fight_won": 1})
	_event("combat_ended", "two", {"outcome": "defeat"}, {})
	_event("combat_ended", "two", {"outcome": "victory"}, {"fights_won": 1})
	_event("run_ended", "two", {"outcome": "defeat"}, {"runs_died": 1, "died_other": 1})
	_event("run_ended", "two", {"outcome": "abandoned"}, {"runs_abandoned": 1})
	var room_types := ["combat", "special", "guardian", "boss", "combat", "combat", "combat"]
	for number: int in range(1, 8):
		var fight := number if number < 7 else 9
		var room: String = room_types[number - 1]
		var run := "fight-%d" % number
		var expected := {"fights_started_%d" % number: 1}
		match number:
			3: expected.merge({"p_fight3": 1, "p_guardian": 1})
			4: expected.merge({"p_boss": 1, "runs_reached_boss": 1})
			5: expected["p_fight5"] = 1
		_event("combat_started", run, {"fight_number": fight, "room_type": room}, expected)
		if room == "boss":
			_event("combat_started", run, {"fight_number": fight, "room_type": room}, {"fights_started_4": 1})
		_event("run_ended", run, {"outcome": "defeat", "defeat_fight_number": fight, "defeat_room_type": room},
			{"runs_died": 1, "died_fight_%d" % number: 1, "died_" + room: 1})
	_event("guided_tutorial_started", "tutorial", {}, {"tutorial_started": 1})
	_event("guided_tutorial_dismissed", "tutorial", {"phase_id": "first", "completed_step_count": 1}, {"tutorial_left_early": 1})
	_event("guided_tutorial_dismissed", "tutorial", {"phase_id": "complete", "completed_step_count": 15}, {})
	_event("guided_tutorial_started", "tutorial", {}, {"tutorial_started": 1})
	_event("run_ended", "tutorial", {"outcome": "abandoned"}, {"runs_abandoned": 1, "tutorial_left_early": 1})
	_event("run_ended", "untouched", {"outcome": "abandoned"}, {"runs_abandoned": 1})
	_event("card_played", "two", {"outcome": "victory"}, {})
	var before := fake.stats.duplicate()
	steam.observe_play_records([{"event_type": "run_started", "run_id": "debug", "debug_boss_run": true}])
	steam._flush_play_batches()
	_delta(before, {}, "debug runs stay out of Steam stats")

func _prove_lifecycle() -> void:
	var before := fake.stats.duplicate()
	steam._play.set_focused(true, 0)
	steam._play.set_focused(false, 45000000)
	steam._play.set_focused(true, 100000000)
	steam._play.sample_focus(176000000)
	steam._play.set_focused(false, 176000000)
	steam._play.sample_run_clock("resume", 90.0, 90.0)
	steam._play.sample_run_clock("resume", 185.0, 90.0)
	steam._play.sample_run_clock("resume", 130.0, 130.0)
	steam._flush_play_batches()
	_delta(before, {"play_minutes": 2, "run_minutes": 2}, "focused time and Chronicle clock count only new full minutes")

	var axis := InputEventJoypadMotion.new()
	axis.axis_value = 0.1
	before = fake.stats.duplicate()
	steam._input(axis)
	steam._flush_play_batches()
	_delta(before, {}, "stick within the deadzone is ignored")
	axis.axis_value = 0.8
	steam._input(axis)
	var button := InputEventJoypadButton.new()
	button.pressed = true
	steam._input(button)
	steam._flush_play_batches()
	_delta(before, {"p_gamepad": 1}, "controller use is flagged once")

	before = fake.stats.duplicate()
	for source: String in ["menu", "end"]:
		steam.record_play_signal("button", ["wishlist", source])
		steam.record_play_signal("button", ["feedback" if source == "end" else "discord", source])
	steam.record_play_signal("rise_again")
	steam.record_play_signal("load_errors")
	steam.record_play_signal("save_errors")
	steam._flush_play_batches()
	_delta(before, {
		"p_wishlist": 1, "wishlist_menu": 1, "wishlist_end": 1, "p_discord": 1,
		"discord_menu": 1, "discord_end": 1, "rise_again": 1, "load_errors": 1, "save_errors": 1,
	}, "button sources and persistence signal mapping")

	var cases := [
		["menu", -1, 0, "lt5", ""], [Play.run_screen("room", false, false, false, false, false), 1, 5, "5_15", "f0_1"],
		[Play.run_screen("pre_battle", false, false, false, false, false), 2, 15, "15_30", "f2_3"],
		[Play.run_screen("treasure", false, false, false, false, true), 5, 30, "30_60", "f4_5"],
		[Play.run_screen("room", false, true, false, false, false), 6, 60, "60p", "f6p"],
		[Play.run_screen("room", false, false, true, false, false), -1, 1, "lt5", ""],
		[Play.run_screen("victory", false, false, false, true, false), -1, 2, "lt5", ""],
		[Play.run_screen("", false, false, false, false, false), -1, 3, "lt5", ""],
	]
	var screens := ["menu", "map", "fight", "reward", "event", "shop", "run_end", "other"]
	for index: int in cases.size():
		var row: Array = cases[index]
		before = fake.stats.duplicate()
		steam._play.finish_session(row[0], row[1], row[2])
		steam._flush_play_batches()
		var expected := {"quit_" + str(screens[index]): 1, "sess_" + str(row[3]): 1}
		if not str(row[4]).is_empty(): expected["quit_midrun_" + str(row[4])] = 1
		_delta(before, expected, "quit mapping: " + str(screens[index]))

func _prove_store() -> void:
	var before := fake.stats.duplicate()
	steam.accumulate_int_stats({"perf_v1_linux_steamdeck_sessions": 1, "play_v1_p_run2": 12})
	_delta(before, {}, "demo drops perf and caps a set flag")
	_expect(steam.store_pending_stats().get("reason") == "submitted", "demo play targets submit")
	fake.user_stats_stored.emit(fake.app_id, 1)
	steam.accumulate_int_stats({"play_v1_runs_started": 1})
	_expect(steam.store_pending_stats().get("reason") == "store_throttled" and fake.store_calls == 1, "second store inside 60 seconds is suppressed")
	steam._last_store_usec -= steam.MIN_STORE_INTERVAL_USEC
	_expect(steam.store_pending_stats().get("reason") == "submitted" and fake.store_calls == 2, "store permitted after 60 seconds")
	fake.user_stats_stored.emit(fake.app_id, 1)

func _prove_idle_flush() -> void:
	const Persistence = preload("res://scripts/run_persistence.gd")
	steam._play.started_usec = Time.get_ticks_usec() - Play.MINUTE_USEC
	steam._play.marker_minute = 0
	steam._play_session_id = "proof-idle"
	steam._play.emit_stats({"rise_again": 1})
	var before := fake.stats.duplicate()
	var original_queue := FileAccess.get_file_as_string(QUEUE)
	var frame := Engine.get_process_frames()
	Persistence.mark_resolution_frame()
	steam._flush_play_on_idle()
	_expect(FileAccess.get_file_as_string(QUEUE) == original_queue and not FileAccess.file_exists(MARKER), "rule-resolution frames write neither the play queue nor the marker")
	while Engine.get_process_frames() == frame: await process_frame
	steam._flush_play_on_idle()
	_expect(int(steam._read_play_json(MARKER).get("last_minute", -1)) == 1, "idle frame records the next marker minute")
	_delta(before, {"rise_again": 1}, "queued signal drains on the idle frame")

func _prove_marker() -> void:
	var store_calls := fake.store_calls
	steam._write_play_json(MARKER, {"id": "proof-unclean", "started_unix": 1, "last_minute": 17})
	var before := fake.stats.duplicate()
	steam._start_play_session("Windows")
	var day: int = int(Time.get_unix_time_from_system()) / Play.DAY_SECONDS
	_expect(day >= first_day + 7, "proof clock follows fixture dates")
	_delta(before, {"unclean_exits": 1, "sess_15_30": 1}, "unclean marker is consumed exactly once")
	var new_marker: Dictionary = steam._read_play_json(MARKER)
	_expect(new_marker.get("id") != "proof-unclean" and new_marker.get("last_minute") == 0, "launch installs its marker")
	steam._write_play_json(MARKER, {"id": "proof-unclean", "started_unix": 1, "last_minute": 17})
	before = fake.stats.duplicate()
	steam._start_play_session("Windows")
	_delta(before, {}, "persisted recovery token prevents replay")
	steam._play.started_usec = Time.get_ticks_usec()
	steam._play.focused_since_usec = -1
	steam.capture_clean_quit(null)
	steam.capture_clean_quit(null)
	before = fake.stats.duplicate()
	steam._finish_clean_quit()
	_delta(before, {"quit_other": 1, "sess_lt5": 1}, "clean quit records exactly one screen and session length")
	_expect(not FileAccess.file_exists(MARKER) and fake.store_calls == store_calls + 1, "clean quit deletes its marker and bypasses the throttle")
	steam._clean_quit_captured = false

func _prove_deck() -> void:
	var deck := DeckSteam.new()
	var service := load("res://scripts/steam_service.gd").new() as Node
	service._set_stats_queue_path_for_test("user://play01-proof-deck-queue.json")
	service._play_session_path_override = "user://play01-proof-deck-marker.json"
	service._initialize_with_steam_for_test(deck, {"status": 0})
	service._start_play_session("Linux")
	var day: int = int(Time.get_unix_time_from_system()) / Play.DAY_SECONDS
	_expect(deck.stats == {"play_v1_p_os_steamdeck": 1, "play_v1_first_day": day}, "Deck never flags Linux")
	if deck.stats.has("play_v1_p_os_steamdeck"): seen["play_v1_p_os_steamdeck"] = true
	service.free()
	deck.free()

func _prove_undefined_full_schema() -> void:
	OS.unset_environment("LABYRINTH_DEMO")
	var undefined := FakeSteam.new()
	undefined.rejected_stats.assign(["play_v1_p_launched", "play_v1_sessions"])
	var service := load("res://scripts/steam_service.gd").new() as Node
	service._set_stats_queue_path_for_test("user://play01-proof-full-queue.json")
	service._initialize_with_steam_for_test(undefined, {"status": 0})
	for attempt: int in range(2):
		service.accumulate_int_stats({"play_v1_p_launched": 1, "play_v1_sessions": 1})
	_expect(undefined.stats.is_empty() and service._warned_play_stat_rejection, "unpublished play keys are isolated in the full build")
	_expect(service._unavailable_play_stats.size() == 2 and not service._stats_dirty, "rejected play keys are skipped for the remainder of the session")
	service.free()
	undefined.free()

func _observe(event: String, run: String, payload: Dictionary = {}) -> void:
	steam.observe_play_records([{"event_type": event, "run_id": run, "payload": payload}])

func _event(event: String, run: String, payload: Dictionary, expected: Dictionary) -> void:
	var before := fake.stats.duplicate()
	_observe(event, run, payload)
	steam._flush_play_batches()
	_delta(before, expected, event + " " + str(payload))

func _delta(before: Dictionary, expected: Dictionary, message: String) -> void:
	var actual: Dictionary = {}
	for key: String in fake.stats:
		var difference := int(fake.stats[key]) - int(before.get(key, 0))
		if difference == 0: continue
		actual[key.trim_prefix(Play.PREFIX)] = difference
		seen[key] = true
	_expect(actual == expected, "%s has %s, expected %s" % [message, str(actual), str(expected)])

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
